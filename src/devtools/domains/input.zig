//! The Input domain on page sessions (tmp/plans/cdp-part1-design.md 3.7):
//! a device's events, through src/html/user_input.zig - trusted UI Events
//! with their default actions, as a real keyboard's and mouse's - never
//! script on the page (AGENTS.md "No invented paths").
//!
//! Chrome's InputHandler (content/browser/devtools/protocol/
//! input_handler.cc, BSD-3) turns each command into a native input event
//! for the page's widget; Blink's EventHandler then targets it. Here:
//! - dispatchKeyEvent: keyDown / rawKeyDown / keyUp go to user_input's
//!   keyDown / keyUp on the tab's document (the key target is the focused
//!   area); `char` inserts its text as a committed composition does. The
//!   macOS editing `commands` Playwright adds on darwin are ignored:
//!   user_input performs a key's editing action itself on every platform,
//!   as Chrome on Linux and Windows does, where Playwright sends none.
//! - insertText: the text goes into the focused text control or editing
//!   host with beforeinput/input "insertText", no key events (Chrome:
//!   InputHandler::InsertText -> WidgetInputHandler::ImeCommitText).
//! - dispatchMouseEvent: the event goes where the platform's hit test puts
//!   the point. With no renderer there is nothing at any point, so nothing
//!   is hit and no event fires (decision D7, the user 2026-11-21 6:14 PM ET);
//!   the testing platform keeps its no-layout stand-in - the document's root
//!   element - as the WPT runner's test driver does (the user's ruling of
//!   2026-10-27). A press carries its clickCount as the device's click
//!   count (the events' `detail`; 2 adds a dblclick; 0, CDP's default, is a
//!   press with no click), and mouseWheel turns the wheel: one trusted
//!   `wheel` at the hit (user_input.wheel), deltaMode DOM_DELTA_PIXEL - Chrome
//!   makes a precise-pixel WebMouseWheelEvent of it.

const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const platform = @import("platform");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const json_rpc = @import("../json_rpc.zig");
const dispatch_mod = @import("../dispatch.zig");
const dom_domain = @import("dom.zig");

const user_input = html.user_input;
const I = protocol.Input;

/// Per-session state of the domain: the session's keyboard and mouse.
pub const State = struct {
    keyboard: user_input.Keyboard = .{},
    pointer: user_input.Pointer = .{},
};

pub fn sessionEnded(session: *PageSession) void {
    user_input.pointerGone(&session.states.Input.pointer);
}

/// CDP's modifiers bit field: Alt=1, Ctrl=2, Meta/Command=4, Shift=8.
fn modifiersOf(bits: ?i64) user_input.Modifiers {
    const m = bits orelse 0;
    return .{ .alt = m & 1 != 0, .ctrl = m & 2 != 0, .meta = m & 4 != 0, .shift = m & 8 != 0 };
}

/// The tab's active document (its top-level traversable's).
fn tabDocument(session: *PageSession) ?*runtime.Instance {
    const b = session.browser orelse return null;
    const navigables = dom.browser_state.existingNavigablesIn(b.scope) orelse return null;
    const bc = navigables.byId(session.tab) orelse return null;
    const document = bc.getActiveDocument() orelse return null;
    return @ptrCast(@alignCast(document));
}

pub fn dispatchKeyEvent(session: *PageSession, params: I.dispatchKeyEvent.Params) !I.dispatchKeyEvent.Result {
    const document = tabDocument(session) orelse return session.fail("Target closed");
    const modifiers = modifiersOf(params.modifiers);
    // Chrome's InputHandler: a key named nowhere is "Unidentified".
    const key: user_input.Key = .{
        .key = params.key orelse "Unidentified",
        .code = params.code orelse "",
        .location = @intCast(@max(params.location orelse 0, 0)),
        .key_code = @intCast(@max(params.windowsVirtualKeyCode orelse 0, 0)),
        // keyDown carries its text (keypress, insertion); rawKeyDown does
        // not - a `char` event brings it.
        .text = switch (params.type) {
            .keyDown => if (params.text) |t| (if (t.len > 0) t else null) else null,
            else => null,
        },
        .repeat = params.autoRepeat orelse false,
    };
    const keyboard = &session.states.Input.keyboard;
    switch (params.type) {
        .keyDown, .rawKeyDown => user_input.keyDown(keyboard, document, key, modifiers),
        .keyUp => user_input.keyUp(keyboard, document, key, modifiers),
        .char => if (params.text) |text| insert(document, text),
    }
    return .{};
}

pub fn insertText(session: *PageSession, params: I.insertText.Params) !I.insertText.Result {
    const document = tabDocument(session) orelse return session.fail("Target closed");
    if (params.text.len > 0) insert(document, params.text);
    return .{};
}

/// Committed text into the focused text control, else the editing host the
/// key target is in (beforeinput/input "insertText").
fn insert(document: *runtime.Instance, text: []const u8) void {
    if (user_input.execInsertIntoTextControl(document, text, "insertText") != null) return;
    const target = user_input.keyTarget(document) orelse return;
    if (html.execcommand.isEditableTarget(target)) html.execcommand.typeByKey(target, text);
}

/// Chrome's checks, in its order (content/browser/devtools/protocol/
/// input_handler.cc CreateWebMouseEvent, BSD-3; its messages): a wheel needs
/// both deltas and float-sized ones; any other event's pointer properties
/// must be in their ranges.
fn checkMouseParams(session: *PageSession, params: I.dispatchMouseEvent.Params) !void {
    if (params.type == .mouseWheel) {
        const dx = params.deltaX orelse return session.failWithCode(.invalid_params, "'deltaX' and 'deltaY' are expected for mouseWheel event");
        const dy = params.deltaY orelse return session.failWithCode(.invalid_params, "'deltaX' and 'deltaY' are expected for mouseWheel event");
        const max: f64 = std.math.floatMax(f32);
        if (!(@abs(dx) <= max) or !(@abs(dy) <= max)) return session.failWithCode(.invalid_params, "Wheel deltas exceed the supported range");
        return;
    }
    if (params.force) |f| if (!(f >= 0 and f <= 1)) return session.failWithCode(.invalid_params, "'force' should be in the range of [0,1]");
    if (params.tangentialPressure) |t| if (!(t >= -1 and t <= 1)) return session.failWithCode(.invalid_params, "'tangential_pressure' should be in the range of [-1,1]");
    if (params.tiltX) |t| if (!(t >= -90 and t <= 90)) return session.failWithCode(.invalid_params, "'tilt_x' should be in the range of [-90,90]");
    if (params.tiltY) |t| if (!(t >= -90 and t <= 90)) return session.failWithCode(.invalid_params, "'tilt_y' should be in the range of [-90,90]");
    if (params.twist) |t| if (!(t >= 0 and t <= 359)) return session.failWithCode(.invalid_params, "'twist' should be in the range of [0,359]");
}

pub fn dispatchMouseEvent(session: *PageSession, params: I.dispatchMouseEvent.Params) !I.dispatchMouseEvent.Result {
    try checkMouseParams(session, params);
    const document = tabDocument(session) orelse return session.fail("Target closed");
    const hit = hitAt(document, params.x, params.y) orelse return .{};
    const modifiers = modifiersOf(params.modifiers);
    const pointer = &session.states.Input.pointer;
    // The device's report with the event (input_handler.cc: pointer_type,
    // force, tangential pressure, tilt, twist on the WebMouseEvent; a mouse
    // by default, whose pressure Pointer Events gives as 0.5 while a button
    // is down).
    pointer.pointer_type = if (params.pointerType) |t| switch (t) {
        .pen => .pen,
        .mouse => .mouse,
    } else .mouse;
    pointer.pressure = if (params.force) |f| @floatCast(f) else null;
    pointer.tangential_pressure = if (params.tangentialPressure) |t| @floatCast(t) else 0;
    pointer.tilt_x = if (params.tiltX) |t| @intFromFloat(@round(t)) else null;
    pointer.tilt_y = if (params.tiltY) |t| @intFromFloat(@round(t)) else null;
    pointer.twist = if (params.twist) |t| @intCast(t) else 0;
    switch (params.type) {
        .mouseMoved => user_input.pointerMove(pointer, hit, modifiers),
        .mousePressed, .mouseReleased => {
            // A press or release where the pointer is not yet: it moves there
            // first, as the device's own movement would have.
            const over = pointer.currentTarget();
            if (over == null or over.? != hit) user_input.pointerMove(pointer, hit, modifiers);
            const button = buttonIndex(params.button orelse .none) orelse return .{};
            if (params.type == .mousePressed) {
                // The click count the press reports: its mousedown's,
                // mouseup's and click's detail (input_handler.cc
                // "click_count = click_count.value_or(0)"; Blink's
                // SetClickCount at the press).
                pointer.click_count = @intCast(std.math.clamp(params.clickCount orelse 0, 0, std.math.maxInt(i32)));
                user_input.pointerDown(pointer, button, modifiers);
            } else user_input.pointerUp(pointer, button, modifiers);
        },
        // One wheel event at the hit: Chrome's precise-pixel
        // WebMouseWheelEvent (delta_units kScrollByPrecisePixel ->
        // DOM_DELTA_PIXEL), its deltas negated there and back again by
        // Blink's WheelEvent (delta_x = -deltaX; WheelEvent deltaX =
        // -delta_x), so the DOM sees CDP's deltaX and deltaY; the phase-ended
        // event Chrome adds has no deltas and makes no DOM event. Its
        // default action, scrolling, is geometry: the renderer's.
        .mouseWheel => _ = user_input.wheel(pointer, hit, .{ .x = params.deltaX.?, .y = params.deltaY.?, .mode = 0 }, modifiers),
    }
    return .{};
}

/// UI Events' `button` numbering.
fn buttonIndex(button: I.MouseButton) ?u3 {
    return switch (button) {
        .none => null,
        .left => 0,
        .middle => 1,
        .right => 2,
        .back => 3,
        .forward => 4,
    };
}

/// What the platform's hit test puts at (x, y) in the tab's viewport.
fn hitAt(document: *runtime.Instance, x: f64, y: f64) ?*runtime.Instance {
    if (comptime platform.capabilities.layout != .unsupported) {
        // TODO(cdpt): a renderer's hit test (platform.hitTest) maps its
        // LayoutNode back to the node through the DOM domain's node ids
        // (design 3.6); no platform has layout yet.
        _ = .{ x, y };
        return null;
    }
    // Decision D7: no renderer, nothing at any point - except on the
    // testing platform, whose stand-in is the root element.
    if (comptime std.mem.eql(u8, platform.name, "testing")) {
        return dom.document_internals.getDocumentElement(document);
    }
    return null;
}

// ============================================================================
// In-process MCP element-targeted trusted input (User Ruling Option 2,
// 2026-11-23 12:51 PM ET, tmp/plans/mcp1-design.md §6 & §11)
// ============================================================================

/// Local-only commands invoked exclusively by Crane's in-process MCP server
/// (`SessionLink.is_local == true`). External WebSocket/pipe CDP clients
/// always receive standard method-not-found (-32601).
pub fn dispatchRaw(session: *PageSession, method: []const u8, raw: []const u8) bool {
    if (!session.link.is_local) return false;
    const Action = enum { check, click, hover, drag_start, drag_drop };
    const action: Action = if (std.mem.eql(u8, method, "Input._craneCheckElement"))
        .check
    else if (std.mem.eql(u8, method, "Input._craneClickElement"))
        .click
    else if (std.mem.eql(u8, method, "Input._craneHoverElement"))
        .hover
    else if (std.mem.eql(u8, method, "Input._craneDragStart"))
        .drag_start
    else if (std.mem.eql(u8, method, "Input._craneDragDrop"))
        .drag_drop
    else
        return false;

    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const parsed = json_rpc.parse(arena, raw) catch {
        dispatch_mod.sendError(session.link, null, @backingInt(json_rpc.Code.internal_error), "Out of memory", null);
        return true;
    };
    const cmd = switch (parsed) {
        .failure => |f| {
            dispatch_mod.sendError(session.link, f.id, @backingInt(f.code), f.message, null);
            return true;
        },
        .command => |c| c,
    };
    const obj = cmd.params.object;
    const outcome: anyerror!void = switch (action) {
        .check => handleCheckElement(session, obj),
        .click => handleClickElement(session, obj),
        .hover => handleHoverElement(session, obj),
        .drag_start => handleDragStart(session, obj),
        .drag_drop => handleDragDrop(session, obj),
    };
    outcome catch |err| {
        const code: i32 = if (err == error.Protocol) session.failure.code else @backingInt(json_rpc.Code.server_error);
        const message: []const u8 = if (err == error.Protocol and session.failure.len != 0) session.failure.message() else @errorName(err);
        dispatch_mod.sendError(session.link, cmd.id, code, message, null);
        session.failure.len = 0;
        return true;
    };
    const reply = json_rpc.encodeRawResult(session.link.allocator, cmd.id, "{}", session.link.sessionId()) catch return true;
    session.link.send(reply);
    return true;
}

fn optString(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = obj.get(key) orelse return null;
    return if (v == .string) v.string else null;
}

fn optInt(obj: std.json.ObjectMap, key: []const u8) ?i64 {
    const v = obj.get(key) orelse return null;
    return if (v == .integer) v.integer else null;
}

fn optBool(obj: std.json.ObjectMap, key: []const u8) ?bool {
    const v = obj.get(key) orelse return null;
    return if (v == .bool) v.bool else null;
}

/// Option 2 hit-testability & enabledness validation: refuses elements that
/// computed style or HTML state says cannot be interacted with, naming why.
fn validateElement(session: *PageSession, node: *runtime.Instance, check_enabled: bool, check_pointer_events: bool) !void {
    if ((interfaces.Node.get_nodeType(node) catch 0) != 1) return session.fail("Node is not an Element.");
    if (!(interfaces.Node.get_isConnected(node) catch false)) return session.fail("Node is detached from document.");
    const doc = (interfaces.Node.get_ownerDocument(node) catch null) orelse return session.fail("Node is detached from document.");
    if (!dom.document_activity.fullyActive(doc, runtime.SlabAllocator.generationOf(doc))) return session.fail("Element's document is not active.");
    if (!(dom.style.isBeingRendered(node) catch false)) return session.fail("Element is not visible (display: none).");
    if (dom.style.computedStyle(node, null) catch null) |held| {
        defer held.release();
        const style = held.style;
        if (style.keyword(.visibility) != .visible) return session.fail("Element is not visible (visibility: hidden).");
        if (check_pointer_events and style.keyword(.pointer_events) == .none) return session.fail("Element cannot receive pointer events (pointer-events: none).");
    }
    if (html.focus.isInertNode(node)) return session.fail("Element is inert and cannot be interacted with.");
    if (check_enabled and html.accessibility_host.options.is_disabled(node)) return session.fail("Element is disabled and cannot be interacted with.");
}

fn handleCheckElement(session: *PageSession, obj: std.json.ObjectMap) !void {
    const node = try dom_domain.nodeNamed(session, null, optInt(obj, "backendNodeId"), optString(obj, "objectId"));
    try validateElement(session, node, optBool(obj, "checkEnabled") orelse true, optBool(obj, "checkPointerEvents") orelse false);
}

fn handleHoverElement(session: *PageSession, obj: std.json.ObjectMap) !void {
    const node = try dom_domain.nodeNamed(session, null, optInt(obj, "backendNodeId"), optString(obj, "objectId"));
    // Puppeteer's Locator.hover does not wait for enabled, only visible/hit-testable.
    try validateElement(session, node, false, true);
    const pointer = &session.states.Input.pointer;
    const hit = user_input.hitTest(node, 0, 0);
    pointer.pointer_type = .mouse;
    pointer.position = .{ .origin = user_input.Weak.of(node), .x = 0, .y = 0 };
    user_input.pointerMove(pointer, hit, .{});
}

fn handleClickElement(session: *PageSession, obj: std.json.ObjectMap) !void {
    const node = try dom_domain.nodeNamed(session, null, optInt(obj, "backendNodeId"), optString(obj, "objectId"));
    try validateElement(session, node, optBool(obj, "checkEnabled") orelse true, true);
    const click_count: u32 = @intCast(std.math.clamp(optInt(obj, "clickCount") orelse 1, 1, 2));
    const pointer = &session.states.Input.pointer;
    const hit = user_input.hitTest(node, 0, 0);
    pointer.pointer_type = .mouse;
    pointer.position = .{ .origin = user_input.Weak.of(node), .x = 0, .y = 0 };
    user_input.pointerMove(pointer, hit, .{});
    defer pointer.click_count = 1;
    var c: u32 = 1;
    while (c <= click_count) : (c += 1) {
        pointer.click_count = c;
        user_input.pointerDown(pointer, 0, .{});
        user_input.pointerUp(pointer, 0, .{});
    }
}

fn handleDragStart(session: *PageSession, obj: std.json.ObjectMap) !void {
    const from = try dom_domain.nodeNamed(session, null, optInt(obj, "fromBackendNodeId"), optString(obj, "fromObjectId"));
    const to = try dom_domain.nodeNamed(session, null, optInt(obj, "toBackendNodeId"), optString(obj, "toObjectId"));
    try validateElement(session, from, false, true);
    try validateElement(session, to, false, true);
    const pointer = &session.states.Input.pointer;
    const from_hit = user_input.hitTest(from, 0, 0);
    const to_hit = user_input.hitTest(to, 0, 0);
    pointer.pointer_type = .mouse;
    pointer.position = .{ .origin = user_input.Weak.of(from), .x = 0, .y = 0 };
    user_input.pointerMove(pointer, from_hit, .{});
    pointer.click_count = 1;
    user_input.pointerDown(pointer, 0, .{});
    // Ensure drag threshold (>= 4 CSS px) is exceeded even when from == to.
    pointer.position = .{ .origin = user_input.Weak.of(to), .x = if (from == to) 10 else 0, .y = 0 };
    user_input.pointerMove(pointer, to_hit, .{});
}

fn handleDragDrop(session: *PageSession, obj: std.json.ObjectMap) !void {
    const pointer = &session.states.Input.pointer;
    defer user_input.pointerUp(pointer, 0, .{});
    const to = dom_domain.nodeNamed(session, null, optInt(obj, "toBackendNodeId"), optString(obj, "toObjectId")) catch return;
    if ((interfaces.Node.get_nodeType(to) catch 0) != 1) return;
    if (!(interfaces.Node.get_isConnected(to) catch false)) return;
    const to_hit = user_input.hitTest(to, 0, 0);
    pointer.position = .{ .origin = user_input.Weak.of(to), .x = 0, .y = 0 };
    user_input.pointerMove(pointer, to_hit, .{});
}
