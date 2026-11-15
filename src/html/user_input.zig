//! The events a user's pointer and keyboard produce (UI Events, Pointer
//! Events, Input Events), and the user agent's default actions for them:
//! HTML's activation notification, focusing, keyboard activation, text
//! editing of a focused text control, sequential focus navigation. Blink's
//! EventHandler, MouseEventManager and KeyboardEventManager are the shape.
//!
//! Crane has no layout. An input source is therefore over an ELEMENT, not at
//! coordinates: the embedder (the WPT runner's WebDriver remote end, today)
//! moves a pointer onto an element, and a key goes to the currently focused
//! area. Events carry clientX/clientY 0.
//!
//! Stateless: the state of an input device (the element under a pointer, its
//! buttons, a keyboard's armed Space activation) is a `Pointer` or a
//! `Keyboard` the embedder owns and passes in. Every element it records is
//! held weakly (`Weak`): a listener can remove, move or collect it, and the
//! device must neither keep it alive nor dereference it once freed.
//!
//! Every event is made with its interface's constructor in the target's
//! realm, dispatched with dom.fire_event.dispatchTrusted (isTrusted true, so
//! a click runs activation behaviour through the normal dispatch), and freed
//! with releaseIfUnwrapped unless a listener kept it.
//!
//! Stated deviations:
//!   * The click count (`detail`) is always 1: no dblclick.
//!   * An email or number control is edited through its value, which its
//!     value sanitization algorithm then applies to: the text a user sees in
//!     a browser keeps what sanitization strips (visible value vs value).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const form_associated = @import("form_associated.zig");
const focus = @import("focus.zig");
const user_activation = @import("user_activation.zig");
const close_watchers = @import("close_watchers.zig");
const pointer_capture = dom.pointer_capture;

const Instance = runtime.Instance;
const log = std.log.scoped(.user_input);

// ============================================================================
// Weak element references and the documents they are in
// ============================================================================

/// A node held weakly: the address, and the slab generation it had.
pub const Weak = struct {
    node: *Instance,
    generation: u64,

    pub fn of(node: *Instance) Weak {
        return .{ .node = node, .generation = runtime.SlabAllocator.generationOf(node) };
    }

    /// The node, while the address still means it.
    pub fn get(self: Weak) ?*Instance {
        if (runtime.SlabAllocator.generationOf(self.node) != self.generation) return null;
        return self.node;
    }
};

fn isElement(node: *Instance) bool {
    return form_associated.isElement(node);
}

fn nodeDocument(node: *Instance) ?*Instance {
    const node_type = interfaces.Node.get_nodeType(node) catch return null;
    if (node_type == interfaces.Node.get_DOCUMENT_NODE()) return node;
    return interfaces.Node.get_ownerDocument(node) catch null;
}

fn windowOf(document: *Instance) ?*Instance {
    return interfaces.Document.get_defaultView(document) catch null;
}

fn isConnected(node: *Instance) bool {
    return interfaces.Node.get_isConnected(node) catch false;
}

/// The node's parent in the flat tree, near enough: its parent, or a shadow
/// root's host.
fn parentOf(node: *Instance) ?*Instance {
    if (form_associated.parentOf(node)) |parent| {
        if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
        return parent;
    }
    return null;
}

/// The body element of `document`, else its document element.
fn bodyOrDocumentElement(document: *Instance) ?*Instance {
    if (interfaces.Document.get_body(document) catch null) |body| return body;
    return interfaces.Document.get_documentElement(document) catch null;
}

// ============================================================================
// Event construction and dispatch
// ============================================================================

/// Modifier keys held while an event is dispatched.
pub const Modifiers = struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    meta: bool = false,
};

/// Dispatch a trusted `event` at `target`; whether it was not cancelled. The
/// event is freed unless a listener kept it.
fn dispatch(target: *Instance, event: *Instance) bool {
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    return dom.fire_event.dispatchTrusted(target, event) catch true;
}

const Flags = struct { bubbles: bool, cancelable: bool, composed: bool };

fn flagsOf(comptime event_type: []const u8) Flags {
    // UI Events and Pointer Events tables: enter and leave neither bubble,
    // nor cancel, nor cross a shadow boundary; pointercancel and the capture
    // events bubble and cross it but cannot be canceled (Pointer Events
    // 3.1.3.1); the rest do all three.
    const is_boundary = comptime std.mem.endsWith(u8, event_type, "enter") or std.mem.endsWith(u8, event_type, "leave");
    const uncancelable = comptime std.mem.eql(u8, event_type, "pointercancel") or std.mem.eql(u8, event_type, "gotpointercapture") or std.mem.eql(u8, event_type, "lostpointercapture");
    return if (is_boundary)
        .{ .bubbles = false, .cancelable = false, .composed = false }
    else if (uncancelable)
        .{ .bubbles = true, .cancelable = false, .composed = true }
    else
        .{ .bubbles = true, .cancelable = true, .composed = true };
}

fn viewOf(target: *Instance) ?*Instance {
    const document = nodeDocument(target) orelse return null;
    return windowOf(document);
}

/// A MouseEvent's init for `target`.
fn mouseInit(target: *Instance, flags: Flags, modifiers: Modifiers, button: i16, buttons: u16, detail: i32, related: ?*Instance) dictionaries.MouseEventInit {
    return .{
        .base = .{
            .base = .{
                .base = .{ .bubbles = flags.bubbles, .cancelable = flags.cancelable, .composed = flags.composed },
                .view = viewOf(target),
                .detail = detail,
            },
            .ctrlKey = modifiers.ctrl,
            .shiftKey = modifiers.shift,
            .altKey = modifiers.alt,
            .metaKey = modifiers.meta,
        },
        .button = button,
        .buttons = buttons,
        .relatedTarget = related,
        .clientX = 0,
        .clientY = 0,
    };
}

/// Fire a MouseEvent named `event_type` at `target`; whether it was not
/// cancelled.
pub fn fireMouseEvent(target: *Instance, comptime event_type: []const u8, modifiers: Modifiers, button: i16, buttons: u16, detail: i32, related: ?*Instance) bool {
    const init = mouseInit(target, flagsOf(event_type), modifiers, button, buttons, detail, related);
    const event = interfaces.MouseEvent.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.MouseEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return true;
    };
    return dispatch(target, event);
}

/// Fire a PointerEvent named `event_type` at `target` for `pointer`; whether
/// it was not cancelled. Every pointer event but the capture events, click,
/// auxclick and contextmenu first runs "process pending pointer capture"
/// (Pointer Events 3.1.3).
fn firePointerEvent(target: *Instance, comptime event_type: []const u8, pointer: *Pointer, modifiers: Modifiers, button: i16, detail: i32, related: ?*Instance) bool {
    const processes_capture = comptime !(std.mem.eql(u8, event_type, "gotpointercapture") or std.mem.eql(u8, event_type, "lostpointercapture") or
        std.mem.eql(u8, event_type, "click") or std.mem.eql(u8, event_type, "auxclick") or std.mem.eql(u8, event_type, "contextmenu"));
    if (processes_capture) processPendingPointerCapture(pointer, target, modifiers);
    return firePointerEventOnly(target, event_type, pointer, modifiers, button, detail, related);
}

/// firePointerEvent without the capture processing.
fn firePointerEventOnly(target: *Instance, comptime event_type: []const u8, pointer: *const Pointer, modifiers: Modifiers, button: i16, detail: i32, related: ?*Instance) bool {
    const tilt = pointer.tilt();
    const init: dictionaries.PointerEventInit = .{
        .base = mouseInit(target, flagsOf(event_type), modifiers, button, pointer.buttons, detail, related),
        .pointerId = pointer.pointer_id,
        .width = pointer.width,
        .height = pointer.height,
        // Pointer Events 3.1: "For hardware and platforms that do not
        // support pressure, the value MUST be 0.5 when in the active buttons
        // state and 0 otherwise."
        .pressure = pointer.pressure orelse if (pointer.buttons != 0) 0.5 else 0,
        .tangentialPressure = pointer.tangential_pressure,
        .tiltX = tilt.x,
        .tiltY = tilt.y,
        .twist = pointer.twist,
        .altitudeAngle = tilt.altitude,
        .azimuthAngle = tilt.azimuth,
        .pointerType = runtime.DOMString.initInterned(pointer.pointer_type.name()),
        .isPrimary = pointer.is_primary,
    };
    const event = interfaces.PointerEvent.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.PointerEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return true;
    };
    // Popover light dismiss is independent of preventDefault. Keep the
    // event alive through the activity: its target edge keeps target alive
    // when a dispatch listener removes it and collects wrappers.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    const result = dom.fire_event.dispatchTrusted(target, event) catch true;
    if (comptime std.mem.eql(u8, event_type, "pointerdown") or std.mem.eql(u8, event_type, "pointerup")) {
        @import("popover.zig").lightDismiss(target, comptime std.mem.eql(u8, event_type, "pointerdown"));
        @import("dialog.zig").lightDismiss(target, comptime std.mem.eql(u8, event_type, "pointerdown"));
    }
    return result;
}

/// HTML "fire a synthetic pointer event named click" at `target`, with the
/// not trusted flag unset: what activating an element other than by
/// clicking it does (HTML 6.5, "the default action of the interaction event
/// must be to fire a synthetic pointer event named click"). A keyboard
/// click has pointerId -1 and an empty pointerType (Pointer Events).
pub fn fireSyntheticClick(target: *Instance, modifiers: Modifiers) void {
    const init: dictionaries.PointerEventInit = .{
        .base = mouseInit(target, .{ .bubbles = true, .cancelable = true, .composed = true }, modifiers, 0, 0, 0, null),
        .pointerId = -1,
        .pointerType = runtime.DOMString.initInterned(""),
    };
    const event = interfaces.PointerEvent.call_constructor(target.ctx, runtime.DOMString.initInterned("click"), webidl.Opt(dictionaries.PointerEventInit).passed(init)) catch return;
    _ = dispatch(target, event);
}

// ============================================================================
// Pointers
// ============================================================================

/// A touch point's change in one touch frame - one platform touch event,
/// all of a touch screen's contacts at once (Blink's WebTouchPoint states).
pub const TouchChange = enum { stationary, pressed, moved, released, cancelled };

/// A pointer's orientation, as its events report it.
pub const Tilt = struct { x: i32, y: i32, altitude: f64, azimuth: f64 };

/// Pointer Events 3.1.5 tilt2spherical: (altitudeAngle, azimuthAngle).
fn tiltToSpherical(tilt_x: f64, tilt_y: f64) [2]f64 {
    const deg = std.math.pi / 180.0;
    const x = tilt_x * deg;
    const y = tilt_y * deg;
    var azimuth: f64 = 0;
    if (tilt_x == 0) {
        if (tilt_y > 0) azimuth = std.math.pi / 2.0 else if (tilt_y < 0) azimuth = 3.0 * std.math.pi / 2.0;
    } else if (tilt_y == 0) {
        if (tilt_x < 0) azimuth = std.math.pi;
    } else if (@abs(tilt_x) == 90 or @abs(tilt_y) == 90) {
        azimuth = 0;
    } else {
        azimuth = std.math.atan2(@tan(y), @tan(x));
        if (azimuth < 0) azimuth += 2.0 * std.math.pi;
    }
    var altitude: f64 = 0;
    if (@abs(tilt_x) == 90 or @abs(tilt_y) == 90) {
        altitude = 0;
    } else if (tilt_x == 0) {
        altitude = std.math.pi / 2.0 - @abs(y);
    } else if (tilt_y == 0) {
        altitude = std.math.pi / 2.0 - @abs(x);
    } else {
        altitude = std.math.atan(1.0 / @sqrt(std.math.pow(f64, @tan(x), 2) + std.math.pow(f64, @tan(y), 2)));
    }
    return .{ altitude, azimuth };
}

/// Pointer Events 3.1.5 spherical2tilt, rounded with Math.round: (tiltX,
/// tiltY).
fn sphericalToTilt(altitude: f64, azimuth: f64) [2]i32 {
    const pi = std.math.pi;
    var x: f64 = 0;
    var y: f64 = 0;
    if (altitude == 0) {
        if (azimuth == 0 or azimuth == 2 * pi) x = pi / 2.0;
        if (azimuth == pi / 2.0) y = pi / 2.0;
        if (azimuth == pi) x = -pi / 2.0;
        if (azimuth == 3 * pi / 2.0) y = -pi / 2.0;
        if (azimuth > 0 and azimuth < pi / 2.0) {
            x = pi / 2.0;
            y = pi / 2.0;
        }
        if (azimuth > pi / 2.0 and azimuth < pi) {
            x = -pi / 2.0;
            y = pi / 2.0;
        }
        if (azimuth > pi and azimuth < 3 * pi / 2.0) {
            x = -pi / 2.0;
            y = -pi / 2.0;
        }
        if (azimuth > 3 * pi / 2.0 and azimuth < 2 * pi) {
            x = pi / 2.0;
            y = -pi / 2.0;
        }
    } else {
        const tan_alt = @tan(altitude);
        x = std.math.atan(@cos(azimuth) / tan_alt);
        y = std.math.atan(@sin(azimuth) / tan_alt);
    }
    const to_deg = 180.0 / pi;
    // Math.round: halves round towards +Infinity.
    return .{ @intFromFloat(@floor(x * to_deg + 0.5)), @intFromFloat(@floor(y * to_deg + 0.5)) };
}

pub const PointerType = enum {
    mouse,
    pen,
    touch,

    fn name(self: PointerType) []const u8 {
        return @tagName(self);
    }
};

/// A pointer's state, owned by the embedder: what is under it and which
/// buttons are down.
pub const Pointer = struct {
    pointer_id: i32 = 1,
    pointer_type: PointerType = .mouse,
    /// The element under the pointer, and the document it is over.
    hit: ?Weak = null,
    hit_document: ?Weak = null,
    /// The pressed buttons, as the `buttons` bitmask.
    buttons: u16 = 0,
    /// Where each button went down: a click goes to the nearest common
    /// inclusive ancestor of that and where it came up.
    down_targets: [5]?Weak = @splat(null),
    /// A cancelled pointerdown suppresses the compatibility mouse events
    /// until the last button is released (Pointer Events 11).
    compatibility_suppressed: bool = false,
    /// Pointer Events 3.1.2: whether this is the primary pointer of its
    /// type - a mouse always is; a touch contact or a pen is when no other
    /// of its type was in contact as it became active (`touchFrame`, the
    /// input layer for a pen).
    is_primary: bool = true,
    /// The contact's properties, as the input device reports them
    /// (WebDriver's pointer action properties, 15.5): Pointer Events 3.1's
    /// defaults for hardware that does not report one. A null pressure is
    /// "0.5 when in the active buttons state and 0 otherwise"; tilt and
    /// the spherical angles convert into each other (3.1.5) when only one
    /// pair is reported.
    width: f64 = 1,
    height: f64 = 1,
    pressure: ?f32 = null,
    tangential_pressure: f32 = 0,
    tilt_x: ?i32 = null,
    tilt_y: ?i32 = null,
    twist: i32 = 0,
    altitude_angle: ?f64 = null,
    azimuth_angle: ?f64 = null,
    /// A touch point (`touchFrame`): the element under it - a touch does not
    /// hover, so nothing fires until it is in contact - the element its
    /// contact started on, and its change in the touch frame being
    /// delivered.
    touch_hit: ?Weak = null,
    touch_start: ?Weak = null,
    touch_change: TouchChange = .stationary,
    in_contact: bool = false,
    /// The contact is no tap (Touch Events, "Interaction with Mouse Events
    /// and click"): it moved off the element it started on, a touch event of
    /// it was canceled, or another contact was down during it.
    not_a_tap: bool = false,
    /// Where this touch's last tap left the legacy mouse (Pointer Events
    /// 10.1): its next tap's mouse boundary events start there.
    legacy_mouse: ?Weak = null,

    /// The orientation the events report: the reported pair, and the other
    /// pair converted from it (Pointer Events 3.1.5); with neither, the
    /// defaults (tilt 0, altitude pi/2, azimuth 0).
    pub fn tilt(self: *const Pointer) Tilt {
        if (self.tilt_x != null or self.tilt_y != null) {
            const x = self.tilt_x orelse 0;
            const y = self.tilt_y orelse 0;
            const spherical = tiltToSpherical(@floatFromInt(x), @floatFromInt(y));
            return .{ .x = x, .y = y, .altitude = self.altitude_angle orelse spherical[0], .azimuth = self.azimuth_angle orelse spherical[1] };
        }
        if (self.altitude_angle != null or self.azimuth_angle != null) {
            const altitude = self.altitude_angle orelse std.math.pi / 2.0;
            const azimuth = self.azimuth_angle orelse 0;
            const t = sphericalToTilt(altitude, azimuth);
            return .{ .x = t[0], .y = t[1], .altitude = altitude, .azimuth = azimuth };
        }
        return .{ .x = 0, .y = 0, .altitude = std.math.pi / 2.0, .azimuth = 0 };
    }

    /// The element under the pointer now. A listener may have moved or
    /// removed it: then the pointer is over whatever is left of the document
    /// it was over - its body, as a hit test at the same point would find
    /// with the element gone.
    pub fn currentTarget(self: *Pointer) ?*Instance {
        const document = if (self.hit_document) |d| d.get() else null;
        if (self.hit) |weak| {
            if (weak.get()) |element| {
                if (isConnected(element) and document != null and nodeDocument(element) == document.?) return element;
            }
        }
        const d = document orelse return null;
        const fallback = bodyOrDocumentElement(d) orelse return null;
        self.hit = Weak.of(fallback);
        return fallback;
    }
};

// ============================================================================
// Hit testing without layout
// ============================================================================

/// The element at the in-view centre point of `element` offset by
/// (`x`, `y`) CSS pixels - which, with no layout, is `element` itself,
/// except over an image with an image map: there the point is inside the
/// image's box, and the first area of the map whose shape contains it is
/// what the pointer is over (HTML 4.8.14 "image maps" processing model).
///
/// Stated deviation, for the box's size without layout: the image's
/// declared size (getBoundingClientRect, which reads the inline style), else
/// its width and height attributes, else the extent of its map's areas.
pub fn hitTest(element: *Instance, x: f64, y: f64) *Instance {
    if (!form_associated.isElementNamed(element, "img")) return element;
    const map = imageMapOf(element) orelse return element;
    const size = imageSize(element, map);
    const point = [2]f64{ size[0] / 2 + x, size[1] / 2 + y };
    var node = form_associated.nextInTree(map, map, false);
    while (node) |n| : (node = form_associated.nextInTree(n, map, false)) {
        if (!form_associated.isElementNamed(n, "area")) continue;
        if (areaContains(n, point, size[0], size[1])) return n;
    }
    return element;
}

/// The size of `img`'s box, without layout (see `hitTest`).
fn imageSize(img: *Instance, map: *Instance) [2]f64 {
    if (interfaces.Element.call_getBoundingClientRect(img)) |rect| {
        const generation = runtime.SlabAllocator.generationOf(rect);
        defer rect.releaseIfUnwrapped(generation);
        const width = interfaces.DOMRect.get_width(rect) catch 0;
        const height = interfaces.DOMRect.get_height(rect) catch 0;
        if (width > 0 and height > 0) return .{ width, height };
    } else |_| {}
    const allocator = img.ctx.allocator;
    const width_attribute = form_associated.attributeValue(allocator, img, "width") catch null;
    defer if (width_attribute) |v| allocator.free(v);
    const height_attribute = form_associated.attributeValue(allocator, img, "height") catch null;
    defer if (height_attribute) |v| allocator.free(v);
    if (width_attribute != null and height_attribute != null) {
        const width = std.fmt.parseFloat(f64, std.mem.trim(u8, width_attribute.?, " ")) catch 0;
        const height = std.fmt.parseFloat(f64, std.mem.trim(u8, height_attribute.?, " ")) catch 0;
        if (width > 0 and height > 0) return .{ width, height };
    }
    // The extent of the map's areas.
    var extent = [2]f64{ 0, 0 };
    var node = form_associated.nextInTree(map, map, false);
    while (node) |n| : (node = form_associated.nextInTree(n, map, false)) {
        if (!form_associated.isElementNamed(n, "area")) continue;
        const text = (form_associated.attributeValue(allocator, n, "coords") catch null) orelse continue;
        defer allocator.free(text);
        var coords: [256]f64 = undefined;
        const count = parseCoords(text, &coords);
        const shape = form_associated.attributeValue(allocator, n, "shape") catch null;
        defer if (shape) |v| allocator.free(v);
        const is_circle = if (shape) |v| std.ascii.eqlIgnoreCase(v, "circle") or std.ascii.eqlIgnoreCase(v, "circ") else false;
        if (is_circle) {
            if (count >= 3) {
                extent[0] = @max(extent[0], coords[0] + coords[2]);
                extent[1] = @max(extent[1], coords[1] + coords[2]);
            }
            continue;
        }
        var i: usize = 0;
        while (i + 1 < count) : (i += 2) {
            extent[0] = @max(extent[0], coords[i]);
            extent[1] = @max(extent[1], coords[i + 1]);
        }
    }
    return extent;
}

/// The image map `img`'s usemap attribute names: HTML "rules for parsing a
/// hash-name reference" - the first map element in tree order whose id or
/// name is the part after the "#".
fn imageMapOf(img: *Instance) ?*Instance {
    const allocator = img.ctx.allocator;
    const usemap = (form_associated.attributeValue(allocator, img, "usemap") catch null) orelse return null;
    defer allocator.free(usemap);
    const hash = std.mem.indexOfScalar(u8, usemap, '#') orelse return null;
    const name = usemap[hash + 1 ..];
    if (name.len == 0) return null;
    const root = form_associated.rootOf(img);
    var node: ?*Instance = root;
    while (node) |n| : (node = form_associated.nextInTree(n, root, false)) {
        if (!form_associated.isElementNamed(n, "map")) continue;
        if (form_associated.attributeValue(allocator, n, "id") catch null) |id| {
            defer allocator.free(id);
            if (std.mem.eql(u8, id, name)) return n;
        }
        if (form_associated.attributeValue(allocator, n, "name") catch null) |map_name| {
            defer allocator.free(map_name);
            if (std.mem.eql(u8, map_name, name)) return n;
        }
    }
    return null;
}

/// HTML "rules for parsing a list of floating-point numbers", as far as an
/// area's coords need: numbers separated by commas, spaces or semicolons.
fn parseCoords(text: []const u8, out: []f64) usize {
    var count: usize = 0;
    var it = std.mem.tokenizeAny(u8, text, ", ;\t\n\r");
    while (it.next()) |token| {
        if (count == out.len) break;
        out[count] = std.fmt.parseFloat(f64, token) catch 0;
        count += 1;
    }
    return count;
}

/// Whether `area`'s shape, in an image `width` by `height`, contains `point`.
fn areaContains(area: *Instance, point: [2]f64, width: f64, height: f64) bool {
    const allocator = area.ctx.allocator;
    const shape = (form_associated.attributeValue(allocator, area, "shape") catch null);
    defer if (shape) |v| allocator.free(v);
    const kind = shape orelse "rect";
    var coords: [256]f64 = undefined;
    const coords_text = (form_associated.attributeValue(allocator, area, "coords") catch null);
    defer if (coords_text) |v| allocator.free(v);
    const n = if (coords_text) |t| parseCoords(t, &coords) else 0;
    const px = point[0];
    const py = point[1];
    if (std.ascii.eqlIgnoreCase(kind, "default")) return px >= 0 and py >= 0 and px < width and py < height;
    if (std.ascii.eqlIgnoreCase(kind, "circle") or std.ascii.eqlIgnoreCase(kind, "circ")) {
        if (n < 3 or coords[2] <= 0) return false;
        const dx = px - coords[0];
        const dy = py - coords[1];
        return dx * dx + dy * dy <= coords[2] * coords[2];
    }
    if (std.ascii.eqlIgnoreCase(kind, "poly") or std.ascii.eqlIgnoreCase(kind, "polygon")) {
        const points = n / 2;
        if (points < 3) return false;
        // Even-odd rule.
        var inside = false;
        var j = points - 1;
        for (0..points) |i| {
            const xi = coords[2 * i];
            const yi = coords[2 * i + 1];
            const xj = coords[2 * j];
            const yj = coords[2 * j + 1];
            if ((yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi) inside = !inside;
            j = i;
        }
        return inside;
    }
    // The rectangle state (the attribute's missing and invalid value default).
    if (n < 4) return false;
    const left = @min(coords[0], coords[2]);
    const right = @max(coords[0], coords[2]);
    const top = @min(coords[1], coords[3]);
    const bottom = @max(coords[1], coords[3]);
    return px >= left and px < right and py >= top and py < bottom;
}

/// The button number's bit in `buttons` (UI Events: primary 1, auxiliary
/// 4, secondary 2, back 8, forward 16).
fn buttonBit(button: u3) u16 {
    return switch (button) {
        0 => 1,
        1 => 4,
        2 => 2,
        3 => 8,
        else => 16,
    };
}

/// The inclusive ancestors of `node`, innermost first.
fn ancestors(node: *Instance, out: []*Instance) usize {
    var count: usize = 0;
    var current: ?*Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (!isElement(n) or count == out.len) break;
        out[count] = n;
        count += 1;
    }
    return count;
}

/// Move `pointer` onto `hit` (an element): UI Events and Pointer Events
/// boundary events when the element under it changes - out and leave at the
/// old one, over and enter at the new - then pointermove and mousemove; all
/// at the pointer's capture target instead while it is captured.
pub fn pointerMove(pointer: *Pointer, hit: *Instance, modifiers: Modifiers) void {
    // Pointer Events 3.1.3: process pending pointer capture; the event's
    // target is the pointer capture target override, if set.
    const target = pointerEventTarget(pointer, hit, modifiers, true);
    const previous = pointer.currentTarget();
    if (previous != target) {
        var old_chain: [64]*Instance = undefined;
        var new_chain: [64]*Instance = undefined;
        const old_len = if (previous) |p| ancestors(p, &old_chain) else 0;
        const new_len = ancestors(target, &new_chain);
        // The deepest common inclusive ancestor: enter and leave stop there.
        var common: usize = 0;
        while (common < old_len and common < new_len and
            old_chain[old_len - 1 - common] == new_chain[new_len - 1 - common]) : (common += 1)
        {}
        const left = if (pointer.hit_document) |weak| weak.get() else null;
        if (nodeDocument(target)) |document| {
            pointer.hit_document = Weak.of(document);
            // HTML 4.16.3 :hover: the element the pointing device designates
            // - set as the element under it changes, before the boundary
            // events, so their listeners see it. A document the pointer left
            // designates nothing.
            if (left) |old_document| if (old_document != document) dom.pointer_states.set(old_document, .hovered, null);
            dom.pointer_states.set(document, .hovered, target);
        }
        if (previous) |old| {
            _ = firePointerEvent(old, "pointerout", pointer, modifiers, -1, 0, target);
            for (old_chain[0 .. old_len - common]) |element| _ = firePointerEvent(element, "pointerleave", pointer, modifiers, -1, 0, target);
            if (!pointer.compatibility_suppressed) {
                _ = fireMouseEvent(old, "mouseout", modifiers, 0, pointer.buttons, 0, target);
                for (old_chain[0 .. old_len - common]) |element| _ = fireMouseEvent(element, "mouseleave", modifiers, 0, pointer.buttons, 0, target);
            }
        }
        pointer.hit = Weak.of(target);
        _ = firePointerEvent(target, "pointerover", pointer, modifiers, -1, 0, previous);
        // Enter events go outermost first.
        var i = new_len - common;
        while (i > 0) {
            i -= 1;
            _ = firePointerEvent(new_chain[i], "pointerenter", pointer, modifiers, -1, 0, previous);
        }
        if (!pointer.compatibility_suppressed) {
            _ = fireMouseEvent(target, "mouseover", modifiers, 0, pointer.buttons, 0, previous);
            i = new_len - common;
            while (i > 0) {
                i -= 1;
                _ = fireMouseEvent(new_chain[i], "mouseenter", modifiers, 0, pointer.buttons, 0, previous);
            }
        }
    }
    const current = pointer.currentTarget() orelse return;
    _ = firePointerEvent(current, "pointermove", pointer, modifiers, -1, 0, null);
    if (!pointer.compatibility_suppressed) _ = fireMouseEvent(current, "mousemove", modifiers, 0, pointer.buttons, 0, null);
}

/// The first click-focusable inclusive ancestor of `target`, or null.
fn clickFocusableAncestor(target: *Instance) ?*Instance {
    var current: ?*Instance = target;
    while (current) |n| {
        if (isElement(n)) {
            if (focus.isClickFocusable(n)) return n;
            // HTML 6.6.4, get the focusable area: a delegating host can
            // supply a click target even though it is not focusable itself.
            if (focus.getFocusableArea(n, .click)) |area| return area;
        }
        // Hit-test ancestry follows the flat tree, including assigned slots
        // and closed shadow roots (Blink MouseEventManager focus handling).
        current = dom.shadow_dom_algorithms.assignedSlotOf(n) orelse parentOf(n);
        if (current) |p| {
            if (p.stateAs(interfaces.ShadowRoot.State) != null)
                current = interfaces.ShadowRoot.get_host(p) catch null;
        }
    }
    return null;
}

/// Press `button` on `pointer` (a mouse or a pen) over the element under
/// it - or, while the pointer is captured, at its capture target (Pointer
/// Events 3.1.3).
pub fn pointerDown(pointer: *Pointer, button: u3, modifiers: Modifiers) void {
    const hit = pointer.currentTarget() orelse return;
    const bit = buttonBit(button);
    if (pointer.buttons & bit != 0) return;
    const first = pointer.buttons == 0;
    pointer.buttons |= bit;
    // Pointer Events: the pointer is in the active buttons state, and its
    // active document is the target's (3.1.3, set before the event fires,
    // so a pointerdown listener can capture it).
    const target = pointerEventTarget(pointer, hit, modifiers, true);
    pointer.down_targets[button] = Weak.of(target);
    // HTML 4.16.3 :active: the element is "being actively pointed at" while
    // the pointing device is down - any button, disabled or not - and its
    // flat-tree ancestors with it. Set before pointerdown is dispatched and
    // whether or not it is cancelled: all three engines match :active
    // inside pointerdown and mousedown listeners, even after
    // preventDefault() (css/selectors/active-observable.html and
    // html/semantics/selectors/pseudo-classes/active-disabled.html, PASS in
    // all three at wpt.fyi cc74d2669f).
    if (first) if (nodeDocument(target)) |document| dom.pointer_states.set(document, .pointed, target);
    // HTML 6.4.2: pointerdown from a mouse, and mousedown, are
    // activation-triggering input events; the notification runs before they
    // are dispatched.
    if (pointer.pointer_type == .mouse) {
        if (nodeDocument(target)) |document| user_activation.notifyActivation(document);
    }
    if (nodeDocument(target)) |document| focus.noteInputModality(document, true);
    if (!first) {
        // A chorded button press is a pointermove (Pointer Events 4.1.3).
        _ = firePointerEventOnly(target, "pointermove", pointer, modifiers, @intCast(button), 0, null);
        if (!pointer.compatibility_suppressed) _ = fireMouseEvent(capturedOr(pointer, target), "mousedown", modifiers, @intCast(button), pointer.buttons, 1, null);
        return;
    }
    if (!firePointerEventOnly(target, "pointerdown", pointer, modifiers, @intCast(button), 0, null)) {
        // A cancelled pointerdown: no compatibility mouse events until the
        // buttons are up; the click still comes.
        pointer.compatibility_suppressed = true;
        return;
    }
    // Compatibility mouse events go where the pointer's events go: its
    // capture target, or the element under it (8.1: capture retargets "the
    // events for a particular pointer (including any compatibility mouse
    // events)").
    const down_target = capturedOr(pointer, pointer.currentTarget() orelse return);
    if (!fireMouseEvent(down_target, "mousedown", modifiers, @intCast(button), pointer.buttons, 1, null)) return;
    mousedownDefaults(pointer, down_target, button);
}

/// The element a mouse event of `pointer` goes to now: its capture target,
/// else the element under it (a listener may have moved or removed the one
/// it was over); with no pointer (a touch's fallback mouse events), `target`
/// while it is connected.
fn mouseTargetNow(pointer: ?*Pointer, target: *Instance) ?*Instance {
    if (pointer) |p| return capturedOr(p, p.currentTarget() orelse return null);
    return if (isConnected(target)) target else null;
}

/// mousedown's default actions, once a trusted mousedown at `target` (from
/// `pointer`, or a touch's fallback mousedown with none) was not canceled.
fn mousedownDefaults(pointer: ?*Pointer, target: *Instance, button: u3) void {
    // HTML 6.6.2: "When a user activates a click focusable focusable area,
    // the user agent must run the focusing steps on the focusable area with
    // focus trigger set to click"; pressing anything else moves the focus to
    // the viewport, as in every browser.
    const focus_target = mouseTargetNow(pointer, target) orelse return;
    if (clickFocusableAncestor(focus_target)) |area| {
        focus.focusingSteps(area, null, .click);
    } else if (nodeDocument(focus_target)) |document| {
        focus.focusingSteps(document, null, .click);
    }
    // Then the press's selection (Blink EventHandler::HandleMousePressEvent:
    // HandleMouseFocus, then the SelectionController): a primary press on
    // an editable element outside a text control puts the caret at the hit
    // position (selection_focus.caretAtHit: only where it is no geometry).
    if (button == 0) if (mouseTargetNow(pointer, target)) |hit| {
        if (textControlAncestor(hit) == null) @import("selection_focus.zig").caretAtHit(hit);
    };
    // Keep ordinary focus before the picker focusing steps: the shipping
    // browsers split (select-events.optional.html, df642c4142: Chrome155
    // skips select focus; Safari27 focuses it). HTML decides the tie,
    // row61 Q19; the helper must not swallow this click-focus default.
    if (mouseTargetNow(pointer, target)) |current| @import("forms/select_picker.zig").mouseDown(current, button);
}

/// An arrow key's selection change in an editing host (see
/// defaultKeyDownAction): Selection.modify("move" | "extend", "left" |
/// "right", granularity) - Blink's MoveLeft / MoveRight commands run the
/// same SelectionModifier, which collapses a range to its edge for a
/// character move (ModifyMovingLeft / Right).
fn moveSelectionByKey(target: *Instance, right: bool, extend: bool, granularity: []const u8) void {
    const document = nodeDocument(target) orelse return;
    const selection = (interfaces.Document.call_getSelection(document) catch return) orelse return;
    if ((interfaces.Selection.get_rangeCount(selection) catch 0) == 0) return;
    const starts_selection = extend and (interfaces.Selection.get_isCollapsed(selection) catch false);
    const caret_node = interfaces.Selection.get_focusNode(selection) catch null;
    const caret_offset = interfaces.Selection.get_focusOffset(selection) catch 0;
    modifySelection(selection, extend, right, granularity);
    // Extending a caret into a range starts a selection: the Selection API's
    // selectstart, at the caret's container, and a cancelled one leaves the
    // caret where it was. Only when the extension moved something: Blink's
    // FrameSelection::Modify runs the SelectionModifier first, returns when
    // it did not move, then DispatchSelectStart at the extent's container
    // (selection/onselectstart-on-key-in-contenteditable.html: no
    // selectstart at the host's start or end).
    if (starts_selection and !(interfaces.Selection.get_isCollapsed(selection) catch true)) {
        const node = caret_node orelse return;
        interfaces.Selection.call_collapse(selection, node, .passed(caret_offset)) catch return;
        if (!@import("execcommand/root.zig").fireSelectStart(node)) return;
        if ((interfaces.Selection.get_rangeCount(selection) catch 0) == 0) return;
        modifySelection(selection, extend, right, granularity);
    }
}

fn modifySelection(selection: *Instance, extend: bool, right: bool, granularity: []const u8) void {
    const Opt = webidl.Opt(runtime.DOMString);
    interfaces.Selection.call_modify(
        selection,
        Opt.passed(runtime.DOMString.initInterned(if (extend) "extend" else "move")),
        Opt.passed(runtime.DOMString.initInterned(if (right) "right" else "left")),
        Opt.passed(runtime.DOMString.initInterned(granularity)),
    ) catch {};
}

/// The text control `node` is, or is inside (its own editor owns its
/// caret).
fn textControlAncestor(node: *Instance) ?*Instance {
    var current: ?*Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (isElement(n) and textControlKind(n) != .none) return n;
    }
    return null;
}

/// Whether a click at `target` is one a disabled form control swallows: HTML
/// 4.10.19.5, "A form control that is disabled must prevent any click events
/// that are queued on the user interaction task source from being
/// dispatched on the element" - the element, or a button's content.
fn isInDisabledFormControl(target: *Instance) bool {
    var current: ?*Instance = target;
    while (current) |n| : (current = parentOf(n)) {
        if (!isElement(n)) return false;
        // HTML option disabledness also suppresses trusted clicks. An
        // enabled option must still reach a disabled ancestor select.
        if (n.stateAs(interfaces.HTMLOptionElement.State) != null and @import("forms/options.zig").isDisabled(n)) return true;
        if (form_associated.isButton(n) or form_associated.isInput(n) or form_associated.isSelect(n) or form_associated.isTextArea(n)) {
            return form_associated.isDisabled(n);
        }
    }
    return false;
}

/// The nearest common inclusive ancestor of `a` and `b`, or null (different
/// trees).
fn commonAncestor(a: *Instance, b: *Instance) ?*Instance {
    var a_chain: [64]*Instance = undefined;
    const a_len = ancestors(a, &a_chain);
    var current: ?*Instance = b;
    while (current) |n| : (current = parentOf(n)) {
        if (!isElement(n)) return null;
        if (std.mem.indexOfScalar(*Instance, a_chain[0..a_len], n) != null) return n;
    }
    return null;
}

/// Release `button` on `pointer` (a mouse or a pen) over the element under
/// it, or at its capture target: pointerup, the implicit release of its
/// capture, mouseup, then click (auxclick for a non-primary button) - at the
/// capture target when the pointerup was captured, else at the nearest
/// common inclusive ancestor of where it went down and came up (Pointer
/// Events 3.3.12.3).
pub fn pointerUp(pointer: *Pointer, button: u3, modifiers: Modifiers) void {
    const bit = buttonBit(button);
    if (pointer.buttons & bit == 0) return;
    pointer.buttons &= ~bit;
    const down = if (pointer.down_targets[button]) |weak| weak.get() else null;
    pointer.down_targets[button] = null;
    const suppressed = pointer.compatibility_suppressed;
    if (pointer.buttons == 0) pointer.compatibility_suppressed = false;
    const hit = pointer.currentTarget() orelse return;
    const target = pointerEventTarget(pointer, hit, modifiers, true);
    const captured = capturedTarget(pointer, target) != null;
    if (pointer.buttons == 0) {
        // The pointing device is up: nothing is being actively pointed at,
        // already inside pointerup and mouseup listeners
        // (css/selectors/active-observable.html, all three engines).
        if (down) |pressed| if (nodeDocument(pressed)) |document| dom.pointer_states.set(document, .pointed, null);
        if (nodeDocument(target)) |document| dom.pointer_states.set(document, .pointed, null);
        // HTML 6.4.2: "pointerup, provided the event's pointerType is not
        // mouse" is an activation-triggering input event (a pen's).
        if (pointer.pointer_type != .mouse) if (nodeDocument(target)) |document| user_activation.notifyActivation(document);
        _ = firePointerEventOnly(target, "pointerup", pointer, modifiers, @intCast(button), 0, null);
        // 8.5: "Immediately after firing the pointerup ... clear the pending
        // pointer capture target override ... and then run process pending
        // pointer capture steps to fire lostpointercapture if necessary."
        implicitlyReleaseCapture(pointer, target, modifiers);
    } else {
        _ = firePointerEventOnly(target, "pointermove", pointer, modifiers, @intCast(button), 0, null);
    }
    const up_target = if (captured) target else pointer.currentTarget() orelse return;
    if (!suppressed and isConnected(up_target) and fireMouseEvent(up_target, "mouseup", modifiers, @intCast(button), pointer.buttons, 1, null)) {
        if (mouseTargetNow(if (captured) null else pointer, up_target)) |current| @import("forms/select_picker.zig").mouseUp(current, button);
    }
    // 3.3.12.3 step 3: "If ... userEvent was dispatched while the
    // corresponding pointer was captured, then let target be the target of
    // userEvent", even though lostpointercapture has fired since.
    const click_target = if (captured) blk: {
        if (!isConnected(target)) return;
        break :blk target;
    } else blk: {
        const pressed = down orelse return;
        const click_up = pointer.currentTarget() orelse return;
        if (!isConnected(pressed) or nodeDocument(pressed) != nodeDocument(click_up)) return;
        break :blk commonAncestor(pressed, click_up) orelse return;
    };
    if (isInDisabledFormControl(click_target)) return;
    // The click is a PointerEvent (UI Events 3.5.1.1, Pointer Events 4.2.3).
    if (button == 0) {
        _ = firePointerEventOnly(click_target, "click", pointer, modifiers, 0, 1, null);
    } else {
        _ = firePointerEventOnly(click_target, "auxclick", pointer, modifiers, @intCast(button), 1, null);
    }
}

// ============================================================================
// Pointer capture (Pointer Events 4 section 8)
// ============================================================================

/// The active pointers of the top-level traversable `node`'s document is in
/// (`BrowsingContext.active_pointers`), or null for a document with no
/// browsing context.
fn activePointersOf(node: *Instance) ?*pointer_capture.ActivePointers {
    const document = nodeDocument(node) orelse return null;
    const window = windowOf(document) orelse return null;
    const context = dom.browser_state.browsingContextOf(window) orelse return null;
    return &context.getTop().active_pointers;
}

/// `pointer`'s entry among the active pointers of `node`'s traversable. A
/// mouse or a pen is active while it is over the page (made here when it is
/// first needed); a touch only while it is in contact (`touchFrame`).
fn pointerEntry(pointer: *const Pointer, node: *Instance) ?*pointer_capture.Entry {
    const pointers = activePointersOf(node) orelse return null;
    return switch (pointer.pointer_type) {
        .mouse => pointer_capture.find(pointers, pointer.pointer_id),
        .pen => pointer_capture.activate(pointers, pointer.pointer_id, .pen),
        .touch => pointer_capture.find(pointers, pointer.pointer_id),
    };
}

/// 3.1.3.2 "Process pending pointer capture" for `pointer`, whose event is
/// about to go to (or near) `node`: lostpointercapture at the capture target
/// it is losing, gotpointercapture at the one it is gaining, then the
/// pending override becomes the override. 8.5: an override that is no longer
/// connected becomes its document (which then loses it), a pending one is
/// cleared.
fn processPendingPointerCapture(pointer: *Pointer, node: *Instance, modifiers: Modifiers) void {
    const entry = pointerEntry(pointer, node) orelse return;
    if (pointer_capture.get(entry.pending)) |pending| {
        if (!isConnected(pending)) entry.pending = null;
    }
    if (pointer_capture.get(entry.override)) |override| {
        if (isElement(override) and !isConnected(override)) {
            entry.override = if (nodeDocument(override)) |document| pointer_capture.refOf(document) else null;
        }
    } else entry.override = null;
    // Step 1: "If the pointer capture target override for this pointer is
    // set and is not equal to the pending pointer capture target override,
    // then fire a pointer event named lostpointercapture at the pointer
    // capture target override node."
    if (pointer_capture.get(entry.override)) |override| {
        if (pointer_capture.get(entry.pending) != override) {
            _ = firePointerEventOnly(override, "lostpointercapture", pointer, modifiers, -1, 0, null);
        }
    }
    // A listener may have changed the state: read it again - and 8.5's
    // rule again, for a pending target a lostpointercapture listener
    // removed (it never gets the capture: all three browsers,
    // pointerevent_lostpointercapture_remove_setcapture_node.html).
    const fresh = pointerEntry(pointer, node) orelse return;
    if (pointer_capture.get(fresh.pending)) |pending| {
        if (!isConnected(pending)) fresh.pending = null;
    }
    // Step 2: "If the pending pointer capture target override for this
    // pointer is set and is not equal to the pointer capture target
    // override, then fire a pointer event named gotpointercapture at the
    // pending pointer capture target override."
    if (pointer_capture.get(fresh.pending)) |pending| {
        if (pointer_capture.get(fresh.override) != pending) {
            _ = firePointerEventOnly(pending, "gotpointercapture", pointer, modifiers, -1, 0, null);
        }
    }
    // Step 3: "Set the pointer capture target override to the pending
    // pointer capture target override, if set. Otherwise, clear the pointer
    // capture target override."
    const last = pointerEntry(pointer, node) orelse return;
    last.override = if (pointer_capture.get(last.pending) != null) last.pending else null;
}

/// `pointer`'s capture target override, if it is set (and still names an
/// object); `near` finds its traversable.
fn capturedTarget(pointer: *const Pointer, near: *Instance) ?*Instance {
    const entry = pointerEntry(pointer, near) orelse return null;
    return pointer_capture.get(entry.override);
}

/// `pointer`'s capture target override, else `target`.
fn capturedOr(pointer: *const Pointer, target: *Instance) *Instance {
    return capturedTarget(pointer, target) orelse target;
}

/// 3.1.3 "Firing events using the PointerEvent interface", for a
/// pointerdown, pointermove or pointerup of `pointer` whose hit test found
/// `hit`: process pending pointer capture, then "determine the target" - the
/// pointer capture target override if set, else `hit` - and set the
/// pointer's active document to the target's node document, and its active
/// buttons state.
fn pointerEventTarget(pointer: *Pointer, hit: *Instance, modifiers: Modifiers, sets_active_document: bool) *Instance {
    processPendingPointerCapture(pointer, hit, modifiers);
    const target = capturedOr(pointer, hit);
    if (pointerEntry(pointer, target)) |entry| {
        entry.buttons_active = pointer.buttons != 0 or (pointer.pointer_type == .touch and pointer.in_contact);
        if (sets_active_document) if (nodeDocument(target)) |document| {
            entry.active_document = pointer_capture.refOf(document);
        };
    }
    return target;
}

/// 8.5 "Implicit release of pointer capture", after `pointer`'s pointerup
/// or pointercancel at `target`.
fn implicitlyReleaseCapture(pointer: *Pointer, target: *Instance, modifiers: Modifiers) void {
    const entry = pointerEntry(pointer, target) orelse return;
    entry.pending = null;
    entry.buttons_active = false;
    processPendingPointerCapture(pointer, target, modifiers);
}

/// The input device behind `pointer` is gone (the embedder ends its input
/// session): it is no active pointer of the traversable it was acting on
/// any more, and holds no capture there. No event fires.
pub fn pointerGone(pointer: *Pointer) void {
    const near = (if (pointer.touch_start) |weak| weak.get() else null) orelse
        (if (pointer.touch_hit) |weak| weak.get() else null) orelse
        (if (pointer.hit) |weak| weak.get() else null) orelse return;
    const pointers = activePointersOf(near) orelse return;
    if (pointer.pointer_type == .mouse) {
        if (pointer_capture.find(pointers, pointer.pointer_id)) |entry| {
            entry.pending = null;
            entry.override = null;
            entry.buttons_active = false;
        }
        return;
    }
    pointer_capture.deactivate(pointers, pointer.pointer_id);
}

// ============================================================================
// Touch (Touch Events; Pointer Events for a pointer that does not hover)
// ============================================================================

/// Deliver one touch frame: every touch point of a touch screen, each with
/// its change since the last frame (`Pointer.touch_change`, and for a
/// pressed or moved point the element under it, `Pointer.touch_hit`) - one
/// platform touch event, as Blink receives a WebTouchEvent. For each changed
/// point, its pointer events (Pointer Events: a touch does not hover, so its
/// boundary events come with contact - pointerover and pointerenter before
/// pointerdown, pointerout and pointerleave after pointerup; and it is
/// implicitly captured to the element it went down on, 8.4); then the touch
/// events (Touch Events: one per kind of change and target, its
/// changedTouches the points changed so, touches every point in contact,
/// targetTouches those that started on that target); then, for a single
/// contact that went down and came up where it started with no touch event
/// canceled, the tap's mouse events and click (Touch Events, "Interaction
/// with Mouse Events and click": mousemove, mousedown, mouseup, click).
///
/// The order is Blink's (PointerEventManager::HandleTouchEvents fires the
/// frame's pointer events, then TouchEventManager the touch events, then
/// GestureManager::HandleGestureTap the mouse events), and Gecko's for a
/// touch screen. Golden rule 2: Chrome and Firefox fire touch events for
/// WebDriver touch input, Safari does not ship Touch Events on its desktop
/// (shadow-dom/touch-event-retargeting-leak.html: 1/1, 1/1, 0/1 at wpt.fyi
/// 2358bd4835); Crane exposes the touch event APIs (ontouchstart, the
/// TouchEvent interface).
///
/// Stated deviation: no long-press gesture - a contact of any length that
/// lifts where it went down is a tap (Blink and Gecko make a long press a
/// contextmenu and no click).
pub fn touchFrame(points: []const *Pointer, modifiers: Modifiers) void {
    // Pointer events, point by point.
    for (points) |point| switch (point.touch_change) {
        .stationary => {},
        .pressed => touchPressed(point, modifiers),
        .moved => touchMoved(point, modifiers),
        .released => touchLifted(point, modifiers, false),
        .cancelled => touchLifted(point, modifiers, true),
    };
    // Touch Events: "Gestures involving ... multi-touch interactions - with
    // two or more active touch points - will usually only generate touch
    // events": a frame with more than one point in play makes none of them
    // a tap.
    var in_play: usize = 0;
    for (points) |point| {
        if (point.in_contact or point.touch_change != .stationary) in_play += 1;
    }
    if (in_play > 1) for (points) |point| {
        if (point.in_contact or point.touch_change != .stationary) point.not_a_tap = true;
    };
    // Touch events, by kind of change.
    fireTouchEvents(points, .pressed, "touchstart", modifiers);
    fireTouchEvents(points, .moved, "touchmove", modifiers);
    fireTouchEvents(points, .released, "touchend", modifiers);
    fireTouchEvents(points, .cancelled, "touchcancel", modifiers);
    // A tap: the one contact of its gesture lifted where it went down.
    for (points) |point| {
        if (point.touch_change != .released) continue;
        if (!point.not_a_tap and point.is_primary) tap(point, modifiers);
    }
    // The frame is delivered: a lifted point is out of contact for good.
    for (points) |point| {
        switch (point.touch_change) {
            .released, .cancelled => {
                point.touch_start = null;
                point.not_a_tap = false;
                point.compatibility_suppressed = false;
            },
            else => {},
        }
        point.touch_change = .stationary;
    }
}

fn touchPressed(point: *Pointer, modifiers: Modifiers) void {
    const hit = if (point.touch_hit) |weak| weak.get() else null;
    const target = hit orelse return;
    if (!isConnected(target)) return;
    const pointers = activePointersOf(target) orelse return;
    // 3.1.2: primary when no other touch is in contact; a second contact
    // makes every contact of the gesture no tap.
    point.is_primary = pointer_capture.wouldBePrimary(pointers, point.pointer_id, .touch);
    const entry = pointer_capture.activate(pointers, point.pointer_id, .touch) orelse return;
    point.in_contact = true;
    point.buttons = 1;
    point.touch_start = Weak.of(target);
    point.not_a_tap = !point.is_primary;
    entry.buttons_active = true;
    if (nodeDocument(target)) |document| {
        entry.active_document = pointer_capture.refOf(document);
        dom.pointer_states.set(document, .pointed, target);
        focus.noteInputModality(document, true);
    }
    // A touch does not hover: it enters its target as it touches it.
    processPendingPointerCapture(point, target, modifiers);
    _ = firePointerEventOnly(target, "pointerover", point, modifiers, -1, 0, null);
    var chain: [64]*Instance = undefined;
    const len = ancestors(target, &chain);
    var i = len;
    while (i > 0) {
        i -= 1;
        _ = firePointerEventOnly(chain[i], "pointerenter", point, modifiers, -1, 0, null);
    }
    // 3.1.3 / 8.4: a direct manipulation device's pointerdown implicitly
    // captures the pointer to its target, "just before the invocation of
    // any pointerdown listeners" - so hasPointerCapture() is true in them,
    // and gotpointercapture fires before its next event.
    if (isConnected(target)) entry.pending = pointer_capture.refOf(target);
    // 4.1.3.1: canceling pointerdown prevents the compatibility mouse
    // events; the click still comes (Blink's GestureManager drops a tap's
    // mouse events, not its click, after a canceled pointerdown).
    point.compatibility_suppressed = !firePointerEventOnly(target, "pointerdown", point, modifiers, 0, 0, null);
}

fn touchMoved(point: *Pointer, modifiers: Modifiers) void {
    if (!point.in_contact) return;
    const start = if (point.touch_start) |weak| weak.get() else null;
    const hit = (if (point.touch_hit) |weak| weak.get() else null) orelse start orelse return;
    // Leaving the element it went down on makes it no tap.
    if (start == null or hit != start.?) point.not_a_tap = true;
    const target = pointerEventTarget(point, hit, modifiers, true);
    if (!isConnected(target)) return;
    _ = firePointerEventOnly(target, "pointermove", point, modifiers, -1, 0, null);
}

fn touchLifted(point: *Pointer, modifiers: Modifiers, cancelled: bool) void {
    if (!point.in_contact) return;
    const start = if (point.touch_start) |weak| weak.get() else null;
    const hit = (if (point.touch_hit) |weak| weak.get() else null) orelse start orelse {
        point.in_contact = false;
        point.buttons = 0;
        return;
    };
    // Out of the active buttons state before its pointerup fires: a
    // setPointerCapture() in a pointerup listener does nothing (8.2 step 5).
    point.buttons = 0;
    point.in_contact = false;
    const target = pointerEventTarget(point, hit, modifiers, !cancelled);
    if (nodeDocument(target)) |document| dom.pointer_states.set(document, .pointed, null);
    if (cancelled) {
        // 3.1.3.3 "suppress a pointer event stream": pointercancel,
        // pointerout, pointerleave, and the implicit release.
        point.not_a_tap = true;
        _ = firePointerEventOnly(target, "pointercancel", point, modifiers, -1, 0, null);
    } else {
        // HTML 6.4.2: "pointerup, provided the event's pointerType is not
        // mouse" - a touch's - is activation-triggering.
        if (nodeDocument(target)) |document| user_activation.notifyActivation(document);
        _ = firePointerEventOnly(target, "pointerup", point, modifiers, 0, 0, null);
    }
    // 8.5: the implicit release right after pointerup or pointercancel.
    implicitlyReleaseCapture(point, target, modifiers);
    // A touch does not hover: it leaves as it lifts.
    if (isConnected(target)) {
        _ = firePointerEventOnly(target, "pointerout", point, modifiers, -1, 0, null);
        var chain: [64]*Instance = undefined;
        const len = ancestors(target, &chain);
        for (chain[0..len]) |element| _ = firePointerEventOnly(element, "pointerleave", point, modifiers, -1, 0, null);
    }
    if (activePointersOf(target)) |pointers| pointer_capture.deactivate(pointers, point.pointer_id);
}

/// The touch events for the points of `points` whose change is `change`:
/// one TouchEvent named `event_type` per target those points started on.
fn fireTouchEvents(points: []const *Pointer, change: TouchChange, comptime event_type: []const u8, modifiers: Modifiers) void {
    var done: [16]*Instance = undefined;
    var done_count: usize = 0;
    for (points) |point| {
        if (point.touch_change != change) continue;
        const target = (if (point.touch_start) |weak| weak.get() else null) orelse continue;
        if (std.mem.indexOfScalar(*Instance, done[0..done_count], target) != null) continue;
        if (done_count < done.len) {
            done[done_count] = target;
            done_count += 1;
        }
        if (!isConnected(target)) continue;
        if (!fireTouchEvent(target, event_type, points, change, modifiers)) {
            // Touch Events: a canceled touchstart, touchmove or touchend
            // prevents "any mouse event that would be a consequential result
            // of the prevented touch event" - the tap's mouse events and
            // click.
            for (points) |other| {
                if (other.touch_change != change) continue;
                const other_target = (if (other.touch_start) |weak| weak.get() else null) orelse continue;
                if (other_target == target) other.not_a_tap = true;
            }
        }
    }
}

/// Fire one TouchEvent named `event_type` at `target`: changedTouches the
/// points changed by `change` that started on `target`, touches every point
/// still in contact (and, for touchstart and touchmove, those changed),
/// targetTouches those of touches that started on `target`. Whether it was
/// not canceled.
fn fireTouchEvent(target: *Instance, comptime event_type: []const u8, points: []const *Pointer, change: TouchChange, modifiers: Modifiers) bool {
    const allocator = target.ctx.allocator;
    var touches: std.ArrayList(*Instance) = .empty;
    defer touches.deinit(allocator);
    var target_touches: std.ArrayList(*Instance) = .empty;
    defer target_touches.deinit(allocator);
    var changed: std.ArrayList(*Instance) = .empty;
    defer changed.deinit(allocator);
    // Each point's Touch, made once for this event; freed below unless
    // script kept one.
    var made: std.ArrayList(struct { touch: *Instance, generation: u64 }) = .empty;
    defer {
        for (made.items) |m| m.touch.releaseIfUnwrapped(m.generation);
        made.deinit(allocator);
    }
    for (points) |point| {
        const start = (if (point.touch_start) |weak| weak.get() else null) orelse continue;
        const lifted = point.touch_change == .released or point.touch_change == .cancelled;
        const in_list = point.in_contact or point.touch_change == change;
        if (!in_list) continue;
        const touch = makeTouch(point, start) orelse continue;
        made.append(allocator, .{ .touch = touch, .generation = runtime.SlabAllocator.generationOf(touch) }) catch {
            touch.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(touch));
            continue;
        };
        if (point.touch_change == change and start == target) changed.append(allocator, touch) catch {};
        // touchend and touchcancel: "must not be included in the touches
        // and targetTouches attributes".
        if (lifted) continue;
        touches.append(allocator, touch) catch {};
        if (start == target) target_touches.append(allocator, touch) catch {};
    }
    const init: dictionaries.TouchEventInit = .{
        .base = .{
            .base = .{
                .base = .{ .bubbles = true, .cancelable = !std.mem.eql(u8, event_type, "touchcancel"), .composed = true },
                .view = viewOf(target),
                .detail = 0,
            },
            .ctrlKey = modifiers.ctrl,
            .shiftKey = modifiers.shift,
            .altKey = modifiers.alt,
            .metaKey = modifiers.meta,
        },
        .touches = touches.items,
        .targetTouches = target_touches.items,
        .changedTouches = changed.items,
    };
    // HTML 6.4.2: touchend is an activation-triggering input event.
    if (comptime std.mem.eql(u8, event_type, "touchend")) {
        if (nodeDocument(target)) |document| user_activation.notifyActivation(document);
    }
    const event = interfaces.TouchEvent.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.TouchEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return true;
    };
    return dispatch(target, event);
}

/// A Touch for `point`, which started on `start`, in `start`'s realm.
fn makeTouch(point: *const Pointer, start: *Instance) ?*Instance {
    const tilt = point.tilt();
    return interfaces.Touch.call_constructor(start.ctx, .{
        .identifier = point.pointer_id,
        .target = start,
        .radiusX = @as(f32, @floatCast(point.width / 2)),
        .radiusY = @as(f32, @floatCast(point.height / 2)),
        .force = point.pressure orelse if (point.in_contact) 0.5 else 0,
        .altitudeAngle = tilt.altitude,
        .azimuthAngle = tilt.azimuth,
        .touchType = ._direct_,
    }) catch |err| {
        log.debug("touch not made: {}", .{err});
        return null;
    };
}

/// Touch Events, "Interaction with Mouse Events and click": a tap's mouse
/// events at the element under the lifted point - mousemove (after the
/// boundary events of the mouse the page saw last moving there, Pointer
/// Events 10.1), mousedown and its default actions, mouseup and its, and
/// click (a PointerEvent of the touch, Pointer Events 3.3.12) at the target
/// its captured pointerup had.
fn tap(point: *Pointer, modifiers: Modifiers) void {
    const target = (if (point.touch_start) |weak| weak.get() else null) orelse return;
    if (!isConnected(target)) return;
    if (point.compatibility_suppressed) {
        if (!isInDisabledFormControl(target)) _ = firePointerEventOnly(target, "click", point, modifiers, 0, 1, null);
        return;
    }
    legacyMouseMoveTo(point, target, modifiers);
    if (!isConnected(target)) return;
    _ = fireMouseEvent(target, "mousemove", modifiers, 0, 0, 0, null);
    if (!isConnected(target)) return;
    // HTML 6.4.2: mousedown is activation-triggering.
    if (nodeDocument(target)) |document| user_activation.notifyActivation(document);
    if (fireMouseEvent(target, "mousedown", modifiers, 0, 1, 1, null)) mousedownDefaults(null, target, 0);
    if (!isConnected(target)) return;
    if (fireMouseEvent(target, "mouseup", modifiers, 0, 0, 1, null)) {
        if (isConnected(target)) @import("forms/select_picker.zig").mouseUp(target, 0);
    }
    if (!isConnected(target) or isInDisabledFormControl(target)) return;
    _ = firePointerEventOnly(target, "click", point, modifiers, 0, 1, null);
}

/// Pointer Events 10.1, "Tracking the effective position of the legacy mouse
/// pointer", for a tap's mouse events: the mouse boundary events of a mouse
/// moving from where the touch's last tap left it to `target` - mouseout and
/// mouseleave at the old element, mouseover and mouseenter at the new, enter
/// and leave stopping at their deepest common ancestor.
fn legacyMouseMoveTo(point: *Pointer, target: *Instance, modifiers: Modifiers) void {
    const previous = if (point.legacy_mouse) |weak| weak.get() else null;
    point.legacy_mouse = Weak.of(target);
    if (previous == target) return;
    var old_chain: [64]*Instance = undefined;
    var new_chain: [64]*Instance = undefined;
    const old_len = if (previous) |p| (if (isConnected(p)) ancestors(p, &old_chain) else 0) else 0;
    const new_len = ancestors(target, &new_chain);
    var common: usize = 0;
    while (common < old_len and common < new_len and
        old_chain[old_len - 1 - common] == new_chain[new_len - 1 - common]) : (common += 1)
    {}
    if (old_len != 0) {
        _ = fireMouseEvent(old_chain[0], "mouseout", modifiers, 0, 0, 0, target);
        for (old_chain[0 .. old_len - common]) |element| _ = fireMouseEvent(element, "mouseleave", modifiers, 0, 0, 0, target);
    }
    if (!isConnected(target)) return;
    const related = if (old_len != 0) old_chain[0] else null;
    _ = fireMouseEvent(target, "mouseover", modifiers, 0, 0, 0, related);
    var i = new_len - common;
    while (i > 0) {
        i -= 1;
        _ = fireMouseEvent(new_chain[i], "mouseenter", modifiers, 0, 0, 0, related);
    }
}

// ============================================================================
// Keyboards
// ============================================================================

/// A key, as its KeyboardEvents report it.
pub const Key = struct {
    /// The `key` attribute: a character, or a named key ("Enter").
    key: []const u8,
    code: []const u8 = "",
    location: u32 = 0,
    /// The legacy keyCode for keydown and keyup.
    key_code: u32 = 0,
    /// The character the key produces, if any (keypress and text input).
    text: ?[]const u8 = null,
    repeat: bool = false,
};

/// A keyboard's state, owned by the embedder.
pub const Keyboard = struct {
    /// The element a Space keydown armed for keyboard activation: its keyup
    /// clicks it (Blink's HTMLButtonElement / checkbox handling).
    space_armed: ?Weak = null,
};

/// HTML "when a key event is to be routed in a top-level traversable":
/// the DOM anchor of the currently focused area of the top-level traversable
/// `document` is in, the body element or document element standing for a
/// Document.
pub fn keyTarget(document: *Instance) ?*Instance {
    const area = focus.currentlyFocusedArea(document);
    if (isElement(area)) return area;
    return bodyOrDocumentElement(area);
}

fn keyboardInit(target: *Instance, key: Key, modifiers: Modifiers, key_code: u32, char_code: u32) dictionaries.KeyboardEventInit {
    return .{
        .base = .{
            .base = .{
                .base = .{ .bubbles = true, .cancelable = true, .composed = true },
                .view = viewOf(target),
                .which = if (key_code != 0) key_code else char_code,
            },
            .ctrlKey = modifiers.ctrl,
            .shiftKey = modifiers.shift,
            .altKey = modifiers.alt,
            .metaKey = modifiers.meta,
        },
        .key = runtime.DOMString.initInterned(key.key),
        .code = runtime.DOMString.initInterned(key.code),
        .location = key.location,
        .repeat = key.repeat,
        .isComposing = false,
        .charCode = char_code,
        .keyCode = key_code,
    };
}

fn fireKeyboardEvent(target: *Instance, comptime event_type: []const u8, key: Key, modifiers: Modifiers, key_code: u32, char_code: u32) bool {
    const init = keyboardInit(target, key, modifiers, key_code, char_code);
    const event = interfaces.KeyboardEvent.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.KeyboardEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return true;
    };
    return dispatch(target, event);
}

/// The first code point of `text`.
fn firstCodePoint(text: []const u8) u32 {
    const len = std.unicode.utf8ByteSequenceLength(text[0]) catch return text[0];
    if (len > text.len) return text[0];
    return std.unicode.utf8Decode(text[0..len]) catch text[0];
}

fn isKey(key: Key, comptime name: []const u8) bool {
    return std.mem.eql(u8, key.key, name);
}

/// Press `key` with the focus in the top-level traversable `document` is
/// in: keydown, keypress for a key that produces a character (or Enter),
/// and the default action.
pub fn keyDown(keyboard: *Keyboard, document: *Instance, key: Key, modifiers: Modifiers) void {
    const target = keyTarget(document) orelse return;
    // HTML 6.10.1: on desktop platforms Esc is a close request, "the key
    // being pressed down" - targeted at the document the key goes to. Its
    // close request steps: step 1 (a fullscreen element ends it before any
    // event), step 3 fires "the single keydown event" below, step 5 returns
    // when it was canceled, and steps 6-9 process the close watchers as the
    // keydown's default action (Blink: KeyboardEventManager::
    // DefaultKeyboardEventHandler -> the window's CloseWatcherStack).
    const escape = isKey(key, "Escape");
    const close_request_document = if (escape) nodeDocument(target) else null;
    if (close_request_document) |d| if (close_watchers.closeRequestEndsInFullscreen(d)) return;
    // HTML 6.4.2: keydown is an activation-triggering input event, "provided
    // the key is neither the Esc key nor a shortcut key reserved by the user
    // agent".
    if (!escape) {
        if (nodeDocument(target)) |d| user_activation.notifyActivation(d);
    }
    // Selectors 4 section 9.4 leaves focus-visible to a UA heuristic.
    // Ctrl/Alt/Meta shortcuts preserve pointer modality; Shift alone does
    // not (Blink KeyboardEventManager::KeyEvent, 97f9cf6fa75f :355-359;
    // wpt.fyi focus-visible-012, ffc4686d11: Chrome/Firefox/Safari 1/1).
    if (!modifiers.ctrl and !modifiers.alt and !modifiers.meta) {
        if (nodeDocument(target)) |d| focus.noteInputModality(d, false);
    }
    if (!fireKeyboardEvent(target, "keydown", key, modifiers, key.key_code, 0)) {
        // A cancelled keydown has no default action, and disarms Space.
        keyboard.space_armed = null;
        return;
    }
    // The close request steps 6-9: the keydown was not canceled. A close
    // watcher that closed something consumed the key.
    if (close_request_document) |d| if (close_watchers.closeRequestSteps(d)) return;
    // The key may have moved the focus: the default action is the focused
    // element's now.
    const focused = keyTarget(document) orelse return;
    if (@import("forms/select_picker.zig").keyDown(focused, key.key, modifiers.ctrl or modifiers.alt or modifiers.meta)) return;
    const produces_character = key.text != null and !modifiers.ctrl and !modifiers.meta;
    if (produces_character or isKey(key, "Enter")) {
        const char_code: u32 = if (key.text) |t| firstCodePoint(t) else 13;
        // keypress's keyCode is its charCode, as in every browser.
        if (!fireKeyboardEvent(focused, "keypress", key, modifiers, char_code, char_code)) return;
        // Typeahead is a printable-keypress default. Script can cancel it;
        // Ctrl/Alt/Meta shortcuts never enter the select's prefix session.
        if (produces_character and !modifiers.alt) {
            if (@import("forms/select_picker.zig").typeAhead(focused, key.text.?)) return;
        }
    }
    defaultKeyDownAction(keyboard, focused, key, modifiers);
}

/// Release `key`: keyup, then Space's keyboard activation.
pub fn keyUp(keyboard: *Keyboard, document: *Instance, key: Key, modifiers: Modifiers) void {
    const target = keyTarget(document) orelse return;
    const armed = if (keyboard.space_armed) |weak| weak.get() else null;
    if (isKey(key, " ")) keyboard.space_armed = null;
    const released = fireKeyboardEvent(target, "keyup", key, modifiers, key.key_code, 0);
    if (isKey(key, " ")) {
        if (released) if (armed) |element| {
            if (element == target and isConnected(element)) fireSyntheticClick(element, modifiers);
        };
        // Space's release ends the formal activation state its keydown began
        // (Blink KeyboardClickableInputTypeView / BaseCheckableInputType;
        // html/semantics/forms/the-input-element/radio-double-activate-pseudo.html)
        // - whichever key source pressed it.
        if (nodeDocument(target)) |d| dom.pointer_states.set(d, .activated, null);
        if (armed) |element| if (nodeDocument(element)) |d| dom.pointer_states.set(d, .activated, null);
    }
}

/// What a text control's value can be edited through.
const TextControl = enum { none, selection, value_only };

fn textControlKind(element: *Instance) TextControl {
    if (form_associated.isTextArea(element)) return .selection;
    if (!form_associated.isInput(element)) return .none;
    var buffer: [16]u8 = undefined;
    const input_type = form_associated.inputType(element, &buffer);
    const selection_types = [_][]const u8{ "text", "search", "tel", "url", "password" };
    for (selection_types) |t| if (std.mem.eql(u8, input_type, t)) return .selection;
    if (std.mem.eql(u8, input_type, "email") or std.mem.eql(u8, input_type, "number")) return .value_only;
    return .none;
}

/// Whether the user may edit `element`: not disabled, not readonly.
fn isMutable(element: *Instance) bool {
    if (form_associated.isDisabled(element)) return false;
    return !form_associated.hasAttribute(element, "readonly");
}

fn defaultKeyDownAction(keyboard: *Keyboard, target: *Instance, key: Key, modifiers: Modifiers) void {
    // Tab and Shift+Tab: sequential focus navigation (HTML 6.6.5).
    if (isKey(key, "Tab")) {
        const document = nodeDocument(target) orelse return;
        // Moving the focus with Tab ends :active - the formal activation
        // state Space began, and the press of a pointing device still held:
        // no element matches :active afterwards. Not specified; Chrome and
        // Safari (html/semantics/forms/the-button-element/active-onblur.html),
        // all three (the-input-element/checkable-active-onblur.html) and
        // Chrome and Firefox (checkable-active-onblur-with-click.html) at
        // wpt.fyi cc74d2669f.
        dom.pointer_states.set(document, .activated, null);
        dom.pointer_states.set(document, .pointed, null);
        keyboard.space_armed = null;
        focus.navigateSequentially(document, if (modifiers.shift) .backward else .forward);
        return;
    }
    const kind = textControlKind(target);
    // The clipboard shortcuts, in a text control or anywhere else: the
    // Clipboard API's copy, cut and paste actions as the user's own
    // (execcommand/clipboard.zig; Blink's "Copy" / "Cut" / "Paste" editor
    // commands from the key bindings, which run in text fields too).
    if (editingShortcut(target, key, modifiers)) |shortcut| switch (shortcut) {
        .copy => return @import("execcommand/clipboard.zig").byKey(target, .copy),
        .cut => return @import("execcommand/clipboard.zig").byKey(target, .cut),
        .paste => return @import("execcommand/clipboard.zig").byKey(target, .paste),
        .select_all => {},
    };
    if (kind != .none) {
        // SD1-TEXTCONTROL-WORD-KEYS: navigation also applies to readonly
        // controls. The modifier follows navigator.platform, as WPT's
        // EditorTestUtils does; ordinary keys take no new string lookups.
        if ((modifiers.alt or modifiers.ctrl) and !modifiers.meta and kind == .selection and
            (isKey(key, "ArrowLeft") or isKey(key, "ArrowRight")))
        {
            if (form_associated.isDisabled(target)) return;
            const window = viewOf(target) orelse return;
            const navigator = interfaces.Window.get_navigator(window) catch return;
            var platform = interfaces.Navigator.get_platform(navigator) catch return;
            defer platform.deinit(target.ctx.allocator);
            if (isWordModifier(platform.asSlice(), modifiers)) {
                // Like Selection.modify, direction is logical; visual bidi/RTL
                // word movement still requires the layout direction machinery.
                moveTextControlByWord(target, isKey(key, "ArrowRight"), modifiers.shift);
            }
            return;
        }
        if (!modifiers.ctrl and !modifiers.alt and !modifiers.meta and (isKey(key, "ArrowLeft") or isKey(key, "ArrowRight"))) {
            if (form_associated.isDisabled(target)) return;
            moveTextControlByCharacter(target, isKey(key, "ArrowRight"), modifiers.shift);
            return;
        }
        if (!isMutable(target)) return;
        if (key.text) |text| {
            if (!modifiers.ctrl and !modifiers.meta) insertText(target, kind, text, "insertText");
        } else if (isKey(key, "Enter")) {
            if (form_associated.isTextArea(target)) insertText(target, kind, "\n", "insertLineBreak");
        } else if (isKey(key, "Backspace")) {
            deleteContent(target, kind, .backward);
        } else if (isKey(key, "Delete")) {
            deleteContent(target, kind, .forward);
        }
        return;
    }
    // The editing shortcuts outside text controls: Ctrl+A - Meta+A where
    // navigator.platform names a Mac, as WPT's EditorTestUtils and every
    // browser's key bindings choose (Blink editing_behavior.cc's
    // kKeyboardCodeKeyA with the command modifier, "SelectAll") - runs the
    // selectAll command: the editing host's contents, or the document's
    // (execcommand/select_all.zig).
    if (editingShortcut(target, key, modifiers)) |shortcut| switch (shortcut) {
        .select_all => {
            @import("execcommand/root.zig").selectAllByKey(target);
            return;
        },
        .copy, .cut, .paste => unreachable,
    };
    // Backspace and Delete in an editing host (Editing spec, "Additional
    // requirements": the key runs the delete / forwardDelete command).
    if ((isKey(key, "Backspace") or isKey(key, "Delete")) and !modifiers.ctrl and !modifiers.alt and !modifiers.meta) {
        const execcommand = @import("execcommand/root.zig");
        if (execcommand.isEditableTarget(target)) {
            execcommand.deleteByKey(target, if (isKey(key, "Backspace")) .delete else .forward_delete);
            return;
        }
    }
    // With the word modifier (Ctrl, Alt where navigator.platform names a
    // Mac - isWordModifier, as WPT's EditorTestUtils.deleteWordModifier),
    // Backspace and Delete delete a word: Blink's key bindings
    // "DeleteWordBackward" / "DeleteWordForward" (editing_behavior.cc),
    // Gecko's cmd_deleteWordBackward, inputType deleteWordBackward /
    // deleteWordForward (Input Events 2). The word is found over the inline
    // formatting context's text, across inline element edges
    // (execcommand/visible_position.zig): "abc <span>def</span>[]" deletes
    // "def" as "abc def[]" does (editing/whitespaces/delete-word-around-
    // span.html compares the two).
    // TODO(renderer): the line forms (Meta+Backspace on a Mac:
    // deleteSoftLineBackward) need line boundaries, a renderer read.
    if ((isKey(key, "Backspace") or isKey(key, "Delete")) and (modifiers.ctrl or modifiers.alt) and !modifiers.meta and !modifiers.shift) {
        const execcommand = @import("execcommand/root.zig");
        if (execcommand.isEditableTarget(target)) {
            const window = viewOf(target) orelse return;
            const navigator = interfaces.Window.get_navigator(window) catch return;
            var platform = interfaces.Navigator.get_platform(navigator) catch return;
            defer platform.deinit(target.ctx.allocator);
            if (isWordModifier(platform.asSlice(), modifiers)) execcommand.deleteWordByKey(target, isKey(key, "Delete"));
            return;
        }
    }
    // Home and End in an editing host: the caret moves (Shift: the
    // selection extends) to the start or end of its line - Blink's key
    // bindings MoveToBeginningOfLine / MoveToEndOfLine and their
    // AndModifySelection forms, Selection.modify(..., "lineboundary").
    // Where a line ends is a read on the renderer (soft wraps); with none,
    // Selection.modify leaves the caret (TODO(renderer)).
    if ((isKey(key, "Home") or isKey(key, "End")) and !modifiers.ctrl and !modifiers.alt and !modifiers.meta) {
        const execcommand = @import("execcommand/root.zig");
        if (execcommand.isEditableTarget(target)) {
            moveSelectionByKey(target, isKey(key, "End"), modifiers.shift, "lineboundary");
            return;
        }
    }
    // ArrowLeft and ArrowRight in an editing host: the caret moves (Shift:
    // the selection extends) by a character, or by a word with the word
    // modifier - Blink's key bindings MoveLeft / MoveRight /
    // MoveWordLeft / MoveWordRight and their AndModifySelection forms,
    // which run the SelectionModifier that Selection.modify drives (the
    // same here). Without Shift, a character move collapses a selection
    // that is not collapsed to its left or right edge (Blink's
    // SelectionModifier::ModifyMovingLeft / Right "if (selection_.IsRange())",
    // in Selection.modify; Gecko's nsFrameSelection::MoveCaret likewise).
    if ((isKey(key, "ArrowLeft") or isKey(key, "ArrowRight")) and !modifiers.meta) {
        const execcommand = @import("execcommand/root.zig");
        if (execcommand.isEditableTarget(target)) {
            const right = isKey(key, "ArrowRight");
            var granularity: []const u8 = "character";
            if (modifiers.ctrl or modifiers.alt) {
                const window = viewOf(target) orelse return;
                const navigator = interfaces.Window.get_navigator(window) catch return;
                var platform = interfaces.Navigator.get_platform(navigator) catch return;
                defer platform.deinit(target.ctx.allocator);
                if (!isWordModifier(platform.asSlice(), modifiers)) return;
                granularity = "word";
            }
            moveSelectionByKey(target, right, modifiers.shift, granularity);
            return;
        }
    }
    // Typing in an editing host (Editing spec, "Additional requirements"):
    // a character runs insertText, Enter insertParagraph and Shift+Enter
    // insertLineBreak, each announced by a cancelable beforeinput at the
    // editing host. Ctrl and Meta combinations are shortcuts, not text.
    {
        const execcommand = @import("execcommand/root.zig");
        if (execcommand.isEditableTarget(target)) {
            if (isKey(key, "Enter")) {
                if (!modifiers.ctrl and !modifiers.alt and !modifiers.meta) {
                    execcommand.lineBreakByKey(target, if (modifiers.shift) "insertLineBreak" else "insertParagraph");
                }
                return;
            }
            if (key.text) |text| {
                if (!modifiers.ctrl and !modifiers.meta) execcommand.typeByKey(target, text);
                return;
            }
        }
    }
    // A radio button: the arrow keys move the checkedness through its group.
    // Blink RadioInputType::HandleKeydownEvent and Gecko HTMLInputElement::
    // PostHandleEvent's eKeyPress radio branch leave modified arrows alone.
    if (isRadio(target) and !form_associated.isDisabled(target) and
        !modifiers.ctrl and !modifiers.alt and !modifiers.meta)
    {
        if (isKey(key, "ArrowDown") or isKey(key, "ArrowRight")) return moveInRadioGroup(target, .forward, modifiers);
        if (isKey(key, "ArrowUp") or isKey(key, "ArrowLeft")) return moveInRadioGroup(target, .backward, modifiers);
    }
    // Buttons, checkboxes and radio buttons: Space arms keyboard activation
    // for its keyup; Enter activates a button now.
    if (isKeyboardActivatable(target)) {
        if (isKey(key, " ")) {
            keyboard.space_armed = Weak.of(target);
            // HTML 4.16.3: a button held by Space is "in a formal activation
            // state" until its keyup. Space only, on buttons, button-like
            // inputs, checkboxes and radio buttons: Blink
            // KeyboardClickableInputTypeView::HandleKeydownEvent and
            // BaseCheckableInputType::HandleKeydownEvent SetActive(true) for
            // " " alone (Enter clicks on keypress, with no :active), and
            // Gecko and WebKit agree (checkable-active-onblur.html passes in
            // all three). A cancelled keydown, an untrusted one, or a control
            // its keydown listener disabled never gets here
            // (checkable-active-space-key-*.html).
            if (nodeDocument(target)) |document| dom.pointer_states.set(document, .activated, target);
        } else if (isKey(key, "Enter") and !isCheckable(target)) {
            fireSyntheticClick(target, modifiers);
        }
        return;
    }
    // A link: Enter follows it.
    if (form_associated.isElementNamed(target, "a") and form_associated.hasAttribute(target, "href") and isKey(key, "Enter")) {
        fireSyntheticClick(target, modifiers);
        return;
    }
    // A drop-down select: the arrow keys change its selection.
    if (form_associated.isSelect(target)) {
        if (isKey(key, "ArrowDown")) moveSelection(target, .forward) else if (isKey(key, "ArrowUp")) moveSelection(target, .backward);
    }
}

fn isCheckable(element: *Instance) bool {
    if (!form_associated.isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    const input_type = form_associated.inputType(element, &buffer);
    return std.mem.eql(u8, input_type, "checkbox") or std.mem.eql(u8, input_type, "radio");
}

fn isRadio(element: *Instance) bool {
    if (!form_associated.isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    return std.mem.eql(u8, form_associated.inputType(element, &buffer), "radio");
}

/// Borrowed during the read-only radio walk, never used after firing script.
fn radioName(element: *Instance) []const u8 {
    const data = dom.element_data.of(element) orelse return "";
    const index = data.indexOfQualifiedName("name") orelse return "";
    return (data.attributeAt(index) orelse return "").value;
}

fn previousInRadioTree(node: *Instance, root: *Instance) ?*Instance {
    if (node == root) return null;
    if (interfaces.Node.get_previousSibling(node) catch null) |sibling| {
        var last = sibling;
        while (interfaces.Node.get_lastChild(last) catch null) |child| last = child;
        return last;
    }
    return form_associated.parentOf(node);
}

/// The arrow keys on a radio button (Blink's RadioInputType and Gecko's
/// HTMLInputElement keyboard handling; HTML 4.10.5.1.15's radio button
/// group): the focus moves to the next (previous) focusable radio button of
/// its group in tree order, wrapping, and that button is activated as a
/// key press activates it - which checks it and fires input and change.
fn moveInRadioGroup(radio: *Instance, direction: focus.Direction, modifiers: Modifiers) void {
    const name = radioName(radio);
    if (name.len == 0) return;
    const owner = form_associated.formOwner(radio);
    const root = form_associated.rootOf(radio);
    // HTML 4.10.5.1.15: same non-empty name, form owner and tree. Walk in
    // the requested direction and wrap without allocating or capping group
    // membership. External form-associated controls can be outside the form.
    var candidate = radio;
    while (true) {
        if (direction == .forward) {
            candidate = form_associated.nextInTree(candidate, root, false) orelse root;
        } else if (previousInRadioTree(candidate, root)) |previous| {
            candidate = previous;
        } else {
            candidate = root;
            while (interfaces.Node.get_lastChild(candidate) catch null) |child| candidate = child;
        }
        if (candidate == radio) return;
        if (!isRadio(candidate) or !std.mem.eql(u8, radioName(candidate), name) or
            form_associated.formOwner(candidate) != owner) continue;
        // Blink FindNextFocusableRadioButtonInGroup and WebKit's radio
        // key handler check full focusability, not just disabledness.
        if (!focus.isFocusableArea(candidate)) continue;
        const candidate_ref = Weak.of(candidate);
        focus.focusingSteps(candidate, null, .keyboard);
        // A focus listener can remove and collect the candidate. Reuse the
        // device's generation guard instead of reading that old pointer.
        // TODO(refcount step 7): hold a counted reference across both steps;
        // Blink still clicks a removed candidate that its strong hold keeps
        // alive, while this guard skips one that has already been collected.
        if (candidate_ref.get()) |live| fireSyntheticClick(live, modifiers);
        return;
    }
}

fn isKeyboardActivatable(element: *Instance) bool {
    if (form_associated.isDisabled(element)) return false;
    return form_associated.isButtonControl(element) or isCheckable(element) or
        @import("details.zig").isSummaryForParentDetails(element);
}

// ============================================================================
// Text editing
// ============================================================================

fn getValue(element: *Instance) ?runtime.DOMString {
    if (dom.form_controls.editorText(element) catch return null) |text| return text;
    if (form_associated.isTextArea(element)) return interfaces.HTMLTextAreaElement.get_value(element) catch null;
    return interfaces.HTMLInputElement.get_value(element) catch null;
}

fn selectionOf(element: *Instance) ?[2]u32 {
    if (form_associated.isTextArea(element)) {
        const start = interfaces.HTMLTextAreaElement.get_selectionStart(element) catch return null;
        const end = interfaces.HTMLTextAreaElement.get_selectionEnd(element) catch return null;
        return .{ start, end };
    }
    // An email or number input has no selection APIs but still a text
    // control selection (its caret): the input's own, through its hook.
    const selection = dom.form_controls.editorSelection(element) orelse return null;
    return .{ selection.start, selection.end };
}

/// ArrowLeft / ArrowRight in a text control, without Ctrl, Alt or Meta: a
/// selection collapses to its start (left) or end (right); a caret moves one
/// grapheme cluster (Blink and WebKit move by character granularity, a
/// grapheme cluster); with Shift the focus end moves instead, the anchor
/// staying. Logical direction: the visual order of bidirectional text needs
/// the layout backend. The control's own text control selection, through
/// its hook (an input's, a textarea's): setSelectionRange would also fire
/// select, which a caret movement does not.
fn moveTextControlByCharacter(target: *Instance, forward: bool, extend: bool) void {
    const selection = dom.form_controls.editorSelection(target) orelse return;
    var value = getValue(target) orelse return;
    defer value.deinit(target.ctx.allocator);
    const text = value.asSlice();
    const anchor = if (selection.backward) selection.end else selection.start;
    const caret = if (selection.backward) selection.start else selection.end;
    var next: u32 = undefined;
    if (!extend and selection.start != selection.end) {
        next = if (forward) selection.end else selection.start;
    } else {
        next = graphemeBoundary(text, caret, forward);
    }
    const start = if (extend) @min(anchor, next) else next;
    const end = if (extend) @max(anchor, next) else next;
    dom.form_controls.setEditorSelection(target, .{ .start = start, .end = end, .backward = extend and next < anchor });
}

/// The grapheme cluster boundary before (or after) UTF-16 offset `offset` of
/// `text` (intl's UAX #29 iterator); the offset itself at either end.
fn graphemeBoundary(text: []const u8, offset: u32, forward: bool) u32 {
    var iterator = @import("intl").segmenter.GraphemeIterator.init(text);
    var at: u32 = 0;
    while (iterator.next()) |cluster| {
        const after = at + form_associated.utf16Length(cluster);
        if (forward and after > offset) return after;
        if (!forward and after >= offset) return at;
        at = after;
    }
    return if (forward) at else @min(offset, at);
}

const EditingShortcut = enum { select_all, copy, cut, paste };

/// The editing shortcut `key` with `modifiers` is, or null: the platform's
/// command modifier (Meta on a Mac, else Ctrl; navigator.platform decides,
/// see isCommandModifier) alone with the letter - A select all, C copy, X
/// cut, V paste (Blink editing_behavior.cc's key table: kKeyboardCodeKeyA
/// "SelectAll", C "Copy", X "Cut", V "Paste", each with the command
/// modifier).
fn editingShortcut(target: *Instance, key: Key, modifiers: Modifiers) ?EditingShortcut {
    if (!modifiers.ctrl and !modifiers.meta) return null;
    if (key.key.len != 1) return null;
    const shortcut: EditingShortcut = switch (std.ascii.toLower(key.key[0])) {
        'a' => .select_all,
        'c' => .copy,
        'x' => .cut,
        'v' => .paste,
        else => return null,
    };
    const window = viewOf(target) orelse return null;
    const navigator = interfaces.Window.get_navigator(window) catch return null;
    var platform = interfaces.Navigator.get_platform(navigator) catch return null;
    defer platform.deinit(target.ctx.allocator);
    if (!isCommandModifier(platform.asSlice(), modifiers)) return null;
    return shortcut;
}

/// Whether `modifiers` is exactly the platform's command modifier: Meta
/// where navigator.platform names a Mac, Ctrl elsewhere (no Alt, no Shift,
/// not both).
fn isCommandModifier(platform: []const u8, modifiers: Modifiers) bool {
    if (modifiers.alt or modifiers.shift or (modifiers.ctrl and modifiers.meta)) return false;
    return if (std.mem.indexOf(u8, platform, "Mac") != null) modifiers.meta else modifiers.ctrl;
}

test "the command modifier follows navigator platform" {
    try std.testing.expect(isCommandModifier("MacIntel", .{ .meta = true }));
    try std.testing.expect(!isCommandModifier("MacIntel", .{ .ctrl = true }));
    try std.testing.expect(isCommandModifier("Linux x86_64", .{ .ctrl = true }));
    try std.testing.expect(!isCommandModifier("Linux x86_64", .{ .meta = true }));
    try std.testing.expect(!isCommandModifier("Linux x86_64", .{ .ctrl = true, .shift = true }));
    try std.testing.expect(!isCommandModifier("Win32", .{ .ctrl = true, .alt = true }));
    try std.testing.expect(!isCommandModifier("MacIntel", .{ .ctrl = true, .meta = true }));
}

fn isWordModifier(platform: []const u8, modifiers: Modifiers) bool {
    if (modifiers.meta or (modifiers.alt and modifiers.ctrl)) return false;
    return if (std.mem.indexOf(u8, platform, "Mac") != null) modifiers.alt else modifiers.ctrl;
}

test "word modifier follows navigator platform and rejects combined shortcuts" {
    for ([_][]const u8{ "MacIntel", "Linux x86_64", "Win32", "Unknown" }) |platform| {
        const is_mac = std.mem.indexOf(u8, platform, "Mac") != null;
        try std.testing.expectEqual(is_mac, isWordModifier(platform, .{ .alt = true }));
        try std.testing.expectEqual(!is_mac, isWordModifier(platform, .{ .ctrl = true }));
        try std.testing.expectEqual(is_mac, isWordModifier(platform, .{ .alt = true, .shift = true }));
        try std.testing.expectEqual(!is_mac, isWordModifier(platform, .{ .ctrl = true, .shift = true }));
        try std.testing.expect(!isWordModifier(platform, .{}));
        try std.testing.expect(!isWordModifier(platform, .{ .alt = true, .ctrl = true }));
        try std.testing.expect(!isWordModifier(platform, .{ .alt = true, .meta = true }));
        try std.testing.expect(!isWordModifier(platform, .{ .ctrl = true, .meta = true }));
    }
}

/// Blink MoveCommands / SelectionModifier at 8d5ba1795f0c: word commands
/// move the focus endpoint, and extending preserves the selection's anchor.
/// Generated setters supply the existing select/selectionchange scheduling.
fn moveTextControlByWord(target: *Instance, forward: bool, extend: bool) void {
    const range = selectionOf(target) orelse return;
    var direction = if (form_associated.isTextArea(target))
        interfaces.HTMLTextAreaElement.get_selectionDirection(target) catch return
    else
        (interfaces.HTMLInputElement.get_selectionDirection(target) catch return) orelse return;
    defer direction.deinit(target.ctx.allocator);
    const backward = std.mem.eql(u8, direction.asSlice(), "backward");
    const anchor = if (backward) range[1] else range[0];
    const caret = if (backward) range[0] else range[1];
    var value = getValue(target) orelse return;
    defer value.deinit(target.ctx.allocator);
    const next = @import("word_navigation.zig").move(value.asSlice(), caret, forward);
    const start = if (extend) @min(anchor, next) else next;
    const end = if (extend) @max(anchor, next) else next;
    const next_direction = runtime.DOMString.initInterned(if (!extend or anchor == next) "none" else if (next < anchor) "backward" else "forward");
    if (form_associated.isTextArea(target)) {
        interfaces.HTMLTextAreaElement.call_setSelectionRange(target, start, end, .passed(next_direction)) catch {};
    } else {
        interfaces.HTMLInputElement.call_setSelectionRange(target, start, end, .passed(next_direction)) catch {};
    }
}

/// setRangeText's optional selectMode argument type, as the interface's own
/// signature names it (html imports no enums module).
const SelectionModeArgument = @typeInfo(@TypeOf(interfaces.HTMLInputElement.call_setRangeText__1)).@"fn".param_types[4].?;

fn setRangeText(element: *Instance, replacement: []const u8, start: u32, end: u32) void {
    const text = runtime.DOMString.initInterned(replacement);
    const mode = SelectionModeArgument.passed(._end_);
    if (form_associated.isTextArea(element)) {
        interfaces.HTMLTextAreaElement.call_setRangeText__1(element, text, start, end, mode) catch |err| log.debug("setRangeText: {}", .{err});
    } else {
        interfaces.HTMLInputElement.call_setRangeText__1(element, text, start, end, mode) catch |err| log.debug("setRangeText: {}", .{err});
    }
}

fn setValue(element: *Instance, value: []const u8) void {
    const text = runtime.DOMString.initInterned(value);
    if (form_associated.isTextArea(element)) {
        interfaces.HTMLTextAreaElement.set_value(element, text) catch {};
    } else {
        interfaces.HTMLInputElement.set_value(element, text) catch {};
    }
}

/// The control's maximum allowed value length, where maxlength applies, in
/// UTF-16 code units.
fn maxLengthOf(element: *Instance) ?u32 {
    const max = if (form_associated.isTextArea(element))
        interfaces.HTMLTextAreaElement.get_maxLength(element) catch return null
    else blk: {
        var buffer: [16]u8 = undefined;
        // "maxlength ... does not apply" to number inputs.
        if (std.mem.eql(u8, form_associated.inputType(element, &buffer), "number")) return null;
        break :blk interfaces.HTMLInputElement.get_maxLength(element) catch return null;
    };
    return if (max < 0) null else @intCast(max);
}

/// Fire a beforeinput or input InputEvent at `target`; whether it was not
/// cancelled.
fn fireInputEvent(target: *Instance, comptime event_type: []const u8, input_type: []const u8, data: ?[]const u8) bool {
    const cancelable = comptime std.mem.eql(u8, event_type, "beforeinput");
    const init: dictionaries.InputEventInit = .{
        .base = .{ .base = .{ .bubbles = true, .cancelable = cancelable, .composed = true }, .view = viewOf(target) },
        .data = if (data) |d| runtime.DOMString.initInterned(d) else null,
        .isComposing = false,
        .inputType = runtime.DOMString.initInterned(input_type),
    };
    const event = interfaces.InputEvent.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.InputEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return true;
    };
    return dispatch(target, event);
}

/// The user types `text` into `target`: beforeinput, then (unless it was
/// cancelled) the text replaces the selection - cut to the control's
/// maxlength - and input fires.
fn insertText(target: *Instance, kind: TextControl, text_in: []const u8, input_type: []const u8) void {
    if (!fireInputEvent(target, "beforeinput", input_type, if (carriesData(input_type)) text_in else null)) return;
    if (!isConnected(target)) return;
    var text = text_in;
    var value = getValue(target) orelse return;
    defer value.deinit(target.ctx.allocator);
    const current = value.asSlice();
    const selection: [2]u32 = selectionOf(target) orelse blk: {
        const length = form_associated.utf16Length(current);
        break :blk .{ length, length };
    };
    // A number input takes only what keeps it a number in the making.
    var filtered: std.ArrayList(u8) = .empty;
    defer filtered.deinit(target.ctx.allocator);
    if (isNumberInput(target)) {
        filterNumberText(target.ctx.allocator, current, selection, text, &filtered) catch return;
        text = filtered.items;
        if (text.len == 0) return;
    }
    // HTML 4.10.18.2: "the user agent must prevent the user from" making the
    // value's length exceed the maximum allowed value length.
    if (maxLengthOf(target)) |max| {
        const kept = form_associated.utf16Length(current) - (selection[1] - selection[0]);
        const room = if (max > kept) max - kept else 0;
        if (form_associated.utf16Length(text) > room) text = text[0..form_associated.byteOffsetOfUtf16(text, room)];
        if (text.len == 0) return;
    }
    focus.willEditByUser(target);
    if (kind == .none) return;
    const cut_start = form_associated.byteOffsetOfUtf16(current, selection[0]);
    const cut_end = form_associated.byteOffsetOfUtf16(current, selection[1]);
    const joined = std.mem.concat(target.ctx.allocator, u8, &.{ current[0..cut_start], text, current[cut_end..] }) catch return;
    defer target.ctx.allocator.free(joined);
    const caret = selection[0] + form_associated.utf16Length(text);
    if (!(dom.form_controls.userEdit(target, .{ .text = joined, .selection_start = caret, .selection_end = caret }) catch return)) {
        switch (kind) {
            .selection => setRangeText(target, text, selection[0], selection[1]),
            .value_only => setValue(target, joined),
            .none => unreachable,
        }
    }
    _ = fireInputEvent(target, "input", input_type, if (carriesData(input_type)) text else null);
}

/// Whether a text control's beforeinput and input of `input_type` carry the
/// inserted text as data: insertText, and insertFromPaste - Input Events
/// 2's data "for ... insertFromPaste ... in a text control" (its
/// dataTransfer is null there; editing/other/
/// data_transfer_on_input_event_with_insertfrompaste_type.html, all three
/// browsers).
fn carriesData(input_type: []const u8) bool {
    return std.mem.eql(u8, input_type, "insertText") or std.mem.eql(u8, input_type, "insertFromPaste");
}

/// The focused area of `document` when it is a text control (an input
/// whose value is edited as text, or a textarea).
pub fn focusedTextControl(document: *Instance) ?*Instance {
    const focused = (interfaces.Document.get_activeElement(document) catch return null) orelse return null;
    return if (textControlKind(focused) != .none) focused else null;
}

/// Whether `element` is a text control: an input whose value is edited as
/// text, or a textarea.
pub fn isTextControl(element: *Instance) bool {
    return textControlKind(element) != .none;
}

/// Whether the user may edit the text control `element`.
pub fn isMutableTextControl(element: *Instance) bool {
    return textControlKind(element) != .none and isMutable(element);
}

/// The paste action into the text control `control` (Clipboard API 8.3
/// step 3.1.1): `text` replaces its selection as typed text does, with
/// beforeinput and input of inputType insertFromPaste.
pub fn pasteIntoTextControl(control: *Instance, text: []const u8) void {
    const kind = textControlKind(control);
    if (kind == .none or !isMutable(control)) return;
    insertText(control, kind, text, "insertFromPaste");
}

/// The cut action's removal in the text control `control` (8.2 step
/// 3.1.2): its selection goes, with beforeinput and input of inputType
/// deleteByCut. Nothing for a collapsed selection.
pub fn deleteByCut(control: *Instance) void {
    const kind = textControlKind(control);
    if (kind == .none or !isMutable(control)) return;
    deleteContent(control, kind, .cut);
}

/// execCommand("insertText" / "insertHTML") while `document`'s focused area
/// is a text control: the text goes into the control at its selection, as
/// typed text does (beforeinput, the maxlength cut, input). The Editing spec's
/// commands act on editing hosts and do not cover text controls; Chrome and
/// Safari run these two in the control's own editor (Blink's inner editor in
/// the control's UA shadow tree, WebKit's the same):
/// constraints/input-maxlength-emoji.html, where Firefox fails as Crane did.
/// Null when no mutable text control is focused (the editing-host path then
/// runs); otherwise whether the command ran.
pub fn execInsertIntoTextControl(document: *Instance, text: []const u8, input_type: []const u8) ?bool {
    const focused = (interfaces.Document.get_activeElement(document) catch return null) orelse return null;
    const kind = textControlKind(focused);
    if (kind == .none) return null;
    if (!isMutable(focused)) return false;
    // A text control holds no line breaks but a textarea's.
    insertText(focused, kind, text, input_type);
    return true;
}

fn isNumberInput(element: *Instance) bool {
    if (!form_associated.isInput(element)) return false;
    var buffer: [16]u8 = undefined;
    return std.mem.eql(u8, form_associated.inputType(element, &buffer), "number");
}

fn isSign(c: u8) bool {
    return c == '+' or c == '-';
}

fn isE(c: u8) bool {
    return c == 'e' or c == 'E';
}

/// Typing into a number input (HTML 4.10.5.1.12: "User agents must not
/// allow the user to set the value to a non-empty string that is not a valid
/// floating-point number"): the characters of `text` that may stand, given
/// the editor text `current` and the selection the insertion replaces.
/// Blink NumberInputType::FilterBeforeTextInserted, one character at a time;
/// WebKit NumberInputType::handleBeforeTextInsertedEvent applies the same
/// rules (the-input-element/number-invalid-scientific-key-events.html: Chrome
/// and Safari 4/4). Where WebKit refuses more (a sign in the middle without an
/// 'e'; an 'e' after a leading '+'), Chrome and Firefox (no filter) accept:
/// the majority, so Blink's set. Full-width digit normalization is not done.
fn filterNumberText(allocator: std.mem.Allocator, current: []const u8, selection: [2]u32, text: []const u8, out: *std.ArrayList(u8)) !void {
    // Left and right of the replaced selection.
    var left: std.ArrayList(u8) = .empty;
    defer left.deinit(allocator);
    try left.appendSlice(allocator, current[0..form_associated.byteOffsetOfUtf16(current, selection[0])]);
    const right = current[form_associated.byteOffsetOfUtf16(current, selection[1])..];
    for (text) |c| {
        // StripInvalidNumberCharacters(text, "0123456789.Ee-+").
        if (!(std.ascii.isDigit(c) or c == '.' or isE(c) or isSign(c))) continue;
        const l = left.items;
        if (c == '.') {
            // Another decimal point; an 'e' before the caret; a sign after
            // the caret that does not follow an 'e'.
            if (std.mem.indexOfScalar(u8, l, '.') != null or std.mem.indexOfScalar(u8, right, '.') != null or
                std.mem.indexOfAny(u8, l, "eE") != null or signNotAfterE(right)) continue;
        } else if (isE(c)) {
            // Another 'e'; a decimal point after the caret.
            if (std.mem.indexOfAny(u8, l, "eE") != null or std.mem.indexOfAny(u8, right, "eE") != null or
                std.mem.indexOfScalar(u8, right, '.') != null) continue;
        } else if (isSign(c)) {
            // Two signs already; with an 'e', the caret neither at the start
            // nor just after the 'e'; a sign right after the caret; a
            // leading '+' with an 'e'.
            const signs = std.mem.count(u8, l, "+") + std.mem.count(u8, l, "-") + std.mem.count(u8, right, "+") + std.mem.count(u8, right, "-");
            const has_e = std.mem.indexOfAny(u8, l, "eE") != null or std.mem.indexOfAny(u8, right, "eE") != null;
            if (signs >= 2 or (has_e and !(l.len == 0 or isE(l[l.len - 1]))) or
                (right.len != 0 and isSign(right[0])) or (c == '+' and has_e and l.len == 0)) continue;
        } else {
            // A digit before a leading sign; a digit between an 'e' and its sign.
            if ((l.len == 0 and right.len != 0 and isSign(right[0])) or
                (l.len != 0 and isE(l[l.len - 1]) and right.len != 0 and isSign(right[0]))) continue;
        }
        try left.append(allocator, c);
        try out.append(allocator, c);
    }
}

/// Blink's HasSignNotAfterE: the first sign of `text` is not just after an 'e'.
fn signNotAfterE(text: []const u8) bool {
    for (text, 0..) |c, i| if (isSign(c)) return i == 0 or !isE(text[i - 1]);
    return false;
}

const DeleteDirection = enum { backward, forward, cut };

/// The UTF-16 length of the code point that ends (backward) or starts
/// (forward) at UTF-16 offset `offset` of `value`.
fn codePointUnits(value: []const u8, offset: u32, direction: DeleteDirection) u32 {
    const byte = form_associated.byteOffsetOfUtf16(value, offset);
    switch (direction) {
        .forward => {
            if (byte >= value.len) return 0;
            const len = std.unicode.utf8ByteSequenceLength(value[byte]) catch return 1;
            return if (len == 4) 2 else 1;
        },
        .backward => {
            if (byte == 0) return 0;
            var start = byte - 1;
            while (start > 0 and value[start] & 0xC0 == 0x80) start -= 1;
            return if (byte - start == 4) 2 else 1;
        },
        .cut => return 0,
    }
}

/// Backspace (backward) or Delete (forward): the selection, or the code
/// point before (after) the caret.
fn deleteContent(target: *Instance, kind: TextControl, direction: DeleteDirection) void {
    const input_type = switch (direction) {
        .backward => "deleteContentBackward",
        .forward => "deleteContentForward",
        .cut => "deleteByCut",
    };
    var value = getValue(target) orelse return;
    defer value.deinit(target.ctx.allocator);
    const current = value.asSlice();
    const length = form_associated.utf16Length(current);
    var range: [2]u32 = selectionOf(target) orelse .{ length, length };
    if (range[0] == range[1]) {
        if (direction == .cut) return;
        const units = codePointUnits(current, range[0], direction);
        if (units == 0) return;
        if (direction == .backward) range[0] -= units else range[1] += units;
    }
    if (!fireInputEvent(target, "beforeinput", input_type, null)) return;
    if (!isConnected(target)) return;
    // A beforeinput listener may replace the value. Keep the pending
    // deletion range, as the previous setRangeText path did, but apply it
    // to the live editor text with both endpoints clamped (HTML 4.10.20,
    // setRangeText steps 5–6). Preserve the pre-batch pending-range policy;
    // browser behavior when the listener moves the caret is unverified.
    var live_value = getValue(target) orelse return;
    defer live_value.deinit(target.ctx.allocator);
    const live_text = live_value.asSlice();
    const live_length = form_associated.utf16Length(live_text);
    range[0] = @min(range[0], live_length);
    range[1] = @min(range[1], live_length);
    focus.willEditByUser(target);
    if (kind == .none) return;
    const cut_start = form_associated.byteOffsetOfUtf16(live_text, range[0]);
    const cut_end = form_associated.byteOffsetOfUtf16(live_text, range[1]);
    const joined = std.mem.concat(target.ctx.allocator, u8, &.{ live_text[0..cut_start], live_text[cut_end..] }) catch return;
    defer target.ctx.allocator.free(joined);
    if (!(dom.form_controls.userEdit(target, .{ .text = joined, .selection_start = range[0], .selection_end = range[0] }) catch return)) {
        switch (kind) {
            .selection => setRangeText(target, "", range[0], range[1]),
            .value_only => setValue(target, joined),
            .none => unreachable,
        }
    }
    _ = fireInputEvent(target, "input", input_type, null);
}

// ============================================================================
// Select elements
// ============================================================================

/// ArrowDown/ArrowUp on a drop-down select (neither multiple nor with a
/// display size above 1): select the next (previous) enabled option, then
/// fire input and change - what Blink and Gecko do outside macOS.
fn moveSelection(select: *Instance, direction: focus.Direction) void {
    if (interfaces.HTMLSelectElement.get_multiple(select) catch true) return;
    if ((interfaces.HTMLSelectElement.get_size(select) catch 0) > 1) return;
    if (form_associated.isDisabled(select)) return;
    const length = interfaces.HTMLSelectElement.get_length(select) catch return;
    const current = interfaces.HTMLSelectElement.get_selectedIndex(select) catch return;
    var index: i64 = current;
    while (true) {
        index += if (direction == .forward) 1 else -1;
        if (index < 0 or index >= length) return;
        const option = (interfaces.HTMLSelectElement.call_item(select, @intCast(index)) catch return) orelse return;
        if (interfaces.HTMLOptionElement.get_disabled(option) catch true) continue;
        break;
    }
    interfaces.HTMLSelectElement.set_selectedIndex(select, @intCast(index)) catch return;
    // HTML select update notifications: mark the committed user change.
    dom.form_controls.setUserValidity(select, true) catch {};
    form_associated.fireSimpleEvent(select, "input", .{ .bubbles = true, .composed = true }) catch {};
    form_associated.fireSimpleEvent(select, "change", .{ .bubbles = true }) catch {};
}

test "an area's coords parse as a list of numbers" {
    var coords: [8]f64 = undefined;
    try std.testing.expectEqual(@as(usize, 4), parseCoords("0,0, 50 ;50", &coords));
    try std.testing.expectEqual(@as(f64, 50), coords[3]);
    try std.testing.expectEqual(@as(usize, 0), parseCoords("", &coords));
}

test "button bits follow UI Events' buttons" {
    try std.testing.expectEqual(@as(u16, 1), buttonBit(0));
    try std.testing.expectEqual(@as(u16, 4), buttonBit(1));
    try std.testing.expectEqual(@as(u16, 2), buttonBit(2));
    try std.testing.expectEqual(@as(u16, 8), buttonBit(3));
    try std.testing.expectEqual(@as(u16, 16), buttonBit(4));
}

test "the code point before or after a caret, in UTF-16 units" {
    try std.testing.expectEqual(@as(u32, 1), codePointUnits("ab", 2, .backward));
    try std.testing.expectEqual(@as(u32, 0), codePointUnits("ab", 0, .backward));
    try std.testing.expectEqual(@as(u32, 1), codePointUnits("ab", 0, .forward));
    try std.testing.expectEqual(@as(u32, 0), codePointUnits("ab", 2, .forward));
    // U+1F600 is two UTF-16 code units.
    try std.testing.expectEqual(@as(u32, 2), codePointUnits("a\u{1F600}", 3, .backward));
    try std.testing.expectEqual(@as(u32, 2), codePointUnits("\u{1F600}b", 0, .forward));
}
