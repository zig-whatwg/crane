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
    // nor cancel, nor cross a shadow boundary; the rest do all three.
    const is_boundary = comptime std.mem.endsWith(u8, event_type, "enter") or std.mem.endsWith(u8, event_type, "leave");
    return if (is_boundary)
        .{ .bubbles = false, .cancelable = false, .composed = false }
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
/// it was not cancelled.
fn firePointerEvent(target: *Instance, comptime event_type: []const u8, pointer: *const Pointer, modifiers: Modifiers, button: i16, detail: i32, related: ?*Instance) bool {
    const init: dictionaries.PointerEventInit = .{
        .base = mouseInit(target, flagsOf(event_type), modifiers, button, pointer.buttons, detail, related),
        .pointerId = pointer.pointer_id,
        .width = 1,
        .height = 1,
        // Pointer Events: a mouse reports 0.5 while a button is down.
        .pressure = if (pointer.buttons != 0) 0.5 else 0,
        .pointerType = runtime.DOMString.initInterned(pointer.pointer_type.name()),
        .isPrimary = true,
    };
    const event = interfaces.PointerEvent.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.PointerEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return true;
    };
    return dispatch(target, event);
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

/// Move `pointer` onto `target` (an element): UI Events and Pointer Events
/// boundary events when the element under it changes - out and leave at the
/// old one, over and enter at the new - then pointermove and mousemove.
pub fn pointerMove(pointer: *Pointer, target: *Instance, modifiers: Modifiers) void {
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
        if (previous) |old| {
            _ = firePointerEvent(old, "pointerout", pointer, modifiers, -1, 0, target);
            for (old_chain[0 .. old_len - common]) |element| _ = firePointerEvent(element, "pointerleave", pointer, modifiers, -1, 0, target);
            if (!pointer.compatibility_suppressed) {
                _ = fireMouseEvent(old, "mouseout", modifiers, 0, pointer.buttons, 0, target);
                for (old_chain[0 .. old_len - common]) |element| _ = fireMouseEvent(element, "mouseleave", modifiers, 0, pointer.buttons, 0, target);
            }
        }
        pointer.hit = Weak.of(target);
        if (nodeDocument(target)) |document| pointer.hit_document = Weak.of(document);
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
    while (current) |n| : (current = parentOf(n)) {
        if (!isElement(n)) return null;
        if (focus.isClickFocusable(n)) return n;
    }
    return null;
}

/// Press `button` on `pointer` over the element under it.
pub fn pointerDown(pointer: *Pointer, button: u3, modifiers: Modifiers) void {
    const target = pointer.currentTarget() orelse return;
    const bit = buttonBit(button);
    if (pointer.buttons & bit != 0) return;
    const first = pointer.buttons == 0;
    pointer.buttons |= bit;
    pointer.down_targets[button] = Weak.of(target);
    // HTML 6.4.2: pointerdown from a mouse, and mousedown, are
    // activation-triggering input events; the notification runs before they
    // are dispatched.
    if (pointer.pointer_type == .mouse) {
        if (nodeDocument(target)) |document| user_activation.notifyActivation(document);
    }
    if (!first) {
        // A chorded button press is a pointermove (Pointer Events 4.1.3).
        _ = firePointerEvent(target, "pointermove", pointer, modifiers, @intCast(button), 0, null);
        if (!pointer.compatibility_suppressed) _ = fireMouseEvent(target, "mousedown", modifiers, @intCast(button), pointer.buttons, 1, null);
        return;
    }
    if (!firePointerEvent(target, "pointerdown", pointer, modifiers, @intCast(button), 0, null)) {
        // A cancelled pointerdown: no compatibility mouse events until the
        // buttons are up; the click still comes.
        pointer.compatibility_suppressed = true;
        return;
    }
    const down_target = pointer.currentTarget() orelse return;
    if (!fireMouseEvent(down_target, "mousedown", modifiers, @intCast(button), pointer.buttons, 1, null)) return;
    // mousedown's default action (HTML 6.6.2): "When a user activates a click
    // focusable focusable area, the user agent must run the focusing steps
    // on the focusable area with focus trigger set to click"; pressing
    // anything else moves the focus to the viewport, as in every browser.
    const focus_target = pointer.currentTarget() orelse return;
    if (clickFocusableAncestor(focus_target)) |area| {
        focus.focusingSteps(area, null, .click);
    } else if (nodeDocument(focus_target)) |document| {
        focus.focusingSteps(document, null, .click);
    }
}

/// Whether a click at `target` is one a disabled form control swallows: HTML
/// 4.10.19.5, "A form control that is disabled must prevent any click events
/// that are queued on the user interaction task source from being
/// dispatched on the element" - the element, or a button's content.
fn isInDisabledFormControl(target: *Instance) bool {
    var current: ?*Instance = target;
    while (current) |n| : (current = parentOf(n)) {
        if (!isElement(n)) return false;
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

/// Release `button` on `pointer` over the element under it: pointerup,
/// mouseup, then click (auxclick for a non-primary button) at the nearest
/// common inclusive ancestor of where it went down and came up.
pub fn pointerUp(pointer: *Pointer, button: u3, modifiers: Modifiers) void {
    const bit = buttonBit(button);
    if (pointer.buttons & bit == 0) return;
    pointer.buttons &= ~bit;
    const down = if (pointer.down_targets[button]) |weak| weak.get() else null;
    pointer.down_targets[button] = null;
    const suppressed = pointer.compatibility_suppressed;
    if (pointer.buttons == 0) pointer.compatibility_suppressed = false;
    const target = pointer.currentTarget() orelse return;
    if (pointer.buttons == 0) {
        _ = firePointerEvent(target, "pointerup", pointer, modifiers, @intCast(button), 0, null);
    } else {
        _ = firePointerEvent(target, "pointermove", pointer, modifiers, @intCast(button), 0, null);
    }
    const up_target = pointer.currentTarget() orelse return;
    if (!suppressed) _ = fireMouseEvent(up_target, "mouseup", modifiers, @intCast(button), pointer.buttons, 1, null);
    const pressed = down orelse return;
    const click_up = pointer.currentTarget() orelse return;
    if (!isConnected(pressed) or nodeDocument(pressed) != nodeDocument(click_up)) return;
    const click_target = commonAncestor(pressed, click_up) orelse return;
    if (isInDisabledFormControl(click_target)) return;
    // The click is a PointerEvent (UI Events 3.5.1.1, Pointer Events 4.2.3).
    if (button == 0) {
        _ = firePointerEvent(click_target, "click", pointer, modifiers, 0, 1, null);
    } else {
        _ = firePointerEvent(click_target, "auxclick", pointer, modifiers, @intCast(button), 1, null);
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
    // HTML 6.4.2: keydown is an activation-triggering input event, "provided
    // the key is neither the Esc key nor a shortcut key reserved by the user
    // agent".
    if (!isKey(key, "Escape")) {
        if (nodeDocument(target)) |d| user_activation.notifyActivation(d);
    }
    if (!fireKeyboardEvent(target, "keydown", key, modifiers, key.key_code, 0)) {
        // A cancelled keydown has no default action, and disarms Space.
        keyboard.space_armed = null;
        return;
    }
    // The key may have moved the focus: the default action is the focused
    // element's now.
    const focused = keyTarget(document) orelse return;
    const produces_character = key.text != null and !modifiers.ctrl and !modifiers.meta;
    if (produces_character or isKey(key, "Enter")) {
        const char_code: u32 = if (key.text) |t| firstCodePoint(t) else 13;
        // keypress's keyCode is its charCode, as in every browser.
        if (!fireKeyboardEvent(focused, "keypress", key, modifiers, char_code, char_code)) return;
    }
    defaultKeyDownAction(keyboard, focused, key, modifiers);
}

/// Release `key`: keyup, then Space's keyboard activation.
pub fn keyUp(keyboard: *Keyboard, document: *Instance, key: Key, modifiers: Modifiers) void {
    const target = keyTarget(document) orelse return;
    const armed = if (keyboard.space_armed) |weak| weak.get() else null;
    if (isKey(key, " ")) keyboard.space_armed = null;
    if (!fireKeyboardEvent(target, "keyup", key, modifiers, key.key_code, 0)) return;
    if (isKey(key, " ")) {
        if (armed) |element| {
            if (element == target and isConnected(element)) fireSyntheticClick(element, modifiers);
        }
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
        focus.navigateSequentially(document, if (modifiers.shift) .backward else .forward);
        return;
    }
    const kind = textControlKind(target);
    if (kind != .none) {
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
    // Buttons, checkboxes and radio buttons: Space arms keyboard activation
    // for its keyup; Enter activates a button now.
    if (isKeyboardActivatable(target)) {
        if (isKey(key, " ")) {
            keyboard.space_armed = Weak.of(target);
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

fn isKeyboardActivatable(element: *Instance) bool {
    if (form_associated.isDisabled(element)) return false;
    return form_associated.isButtonControl(element) or isCheckable(element);
}

// ============================================================================
// Text editing
// ============================================================================

fn getValue(element: *Instance) ?runtime.DOMString {
    if (form_associated.isTextArea(element)) return interfaces.HTMLTextAreaElement.get_value(element) catch null;
    return interfaces.HTMLInputElement.get_value(element) catch null;
}

fn selectionOf(element: *Instance) ?[2]u32 {
    if (form_associated.isTextArea(element)) {
        const start = interfaces.HTMLTextAreaElement.get_selectionStart(element) catch return null;
        const end = interfaces.HTMLTextAreaElement.get_selectionEnd(element) catch return null;
        return .{ start, end };
    }
    const start = (interfaces.HTMLInputElement.get_selectionStart(element) catch return null) orelse return null;
    const end = (interfaces.HTMLInputElement.get_selectionEnd(element) catch return null) orelse return null;
    return .{ start, end };
}

/// setRangeText's optional selectMode argument type, as the interface's own
/// signature names it (html imports no enums module).
const SelectionModeArgument = @typeInfo(@TypeOf(interfaces.HTMLInputElement.call_setRangeText__1)).@"fn".params[4].type.?;

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
    if (!fireInputEvent(target, "beforeinput", input_type, if (std.mem.eql(u8, input_type, "insertText")) text_in else null)) return;
    if (!isConnected(target)) return;
    var text = text_in;
    var value = getValue(target) orelse return;
    defer value.deinit(target.ctx.allocator);
    const current = value.asSlice();
    const selection: [2]u32 = selectionOf(target) orelse blk: {
        const length = form_associated.utf16Length(current);
        break :blk .{ length, length };
    };
    // HTML 4.10.18.2: "the user agent must prevent the user from" making the
    // value's length exceed the maximum allowed value length.
    if (maxLengthOf(target)) |max| {
        const kept = form_associated.utf16Length(current) - (selection[1] - selection[0]);
        const room = if (max > kept) max - kept else 0;
        if (form_associated.utf16Length(text) > room) text = text[0..form_associated.byteOffsetOfUtf16(text, room)];
        if (text.len == 0) return;
    }
    focus.willEditByUser(target);
    switch (kind) {
        .selection => setRangeText(target, text, selection[0], selection[1]),
        .value_only => {
            const joined = std.mem.concat(target.ctx.allocator, u8, &.{ current, text }) catch return;
            defer target.ctx.allocator.free(joined);
            setValue(target, joined);
        },
        .none => return,
    }
    _ = fireInputEvent(target, "input", input_type, if (std.mem.eql(u8, input_type, "insertText")) text else null);
}

const DeleteDirection = enum { backward, forward };

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
    }
}

/// Backspace (backward) or Delete (forward): the selection, or the code
/// point before (after) the caret.
fn deleteContent(target: *Instance, kind: TextControl, direction: DeleteDirection) void {
    const input_type = if (direction == .backward) "deleteContentBackward" else "deleteContentForward";
    var value = getValue(target) orelse return;
    defer value.deinit(target.ctx.allocator);
    const current = value.asSlice();
    const length = form_associated.utf16Length(current);
    var range: [2]u32 = selectionOf(target) orelse .{ length, length };
    if (range[0] == range[1]) {
        const units = codePointUnits(current, range[0], direction);
        if (units == 0) return;
        if (direction == .backward) range[0] -= units else range[1] += units;
    }
    if (!fireInputEvent(target, "beforeinput", input_type, null)) return;
    if (!isConnected(target)) return;
    focus.willEditByUser(target);
    switch (kind) {
        .selection => setRangeText(target, "", range[0], range[1]),
        .value_only => {
            const cut_start = form_associated.byteOffsetOfUtf16(current, range[0]);
            const cut_end = form_associated.byteOffsetOfUtf16(current, range[1]);
            const joined = std.mem.concat(target.ctx.allocator, u8, &.{ current[0..cut_start], current[cut_end..] }) catch return;
            defer target.ctx.allocator.free(joined);
            setValue(target, joined);
        },
        .none => return,
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
    form_associated.fireSimpleEvent(select, "input", .{ .bubbles = true, .composed = true }) catch {};
    form_associated.fireSimpleEvent(select, "change", .{ .bubbles = true }) catch {};
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
