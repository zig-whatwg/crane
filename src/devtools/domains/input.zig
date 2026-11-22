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
//!   2026-10-27).

const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const platform = @import("platform");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

const user_input = html.user_input;
const I = protocol.Input;

/// Per-session state of the domain: the session's keyboard and mouse.
pub const State = struct {
    keyboard: user_input.Keyboard = .{},
    pointer: user_input.Pointer = .{},
};

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

pub fn dispatchMouseEvent(session: *PageSession, params: I.dispatchMouseEvent.Params) !I.dispatchMouseEvent.Result {
    const document = tabDocument(session) orelse return session.fail("Target closed");
    const hit = hitAt(document, params.x, params.y) orelse return .{};
    const modifiers = modifiersOf(params.modifiers);
    const pointer = &session.states.Input.pointer;
    // TODO(cdpt): clickCount as the events' detail once user_input takes a
    // click count (its "detail is always 1" deviation, design 3.7).
    switch (params.type) {
        .mouseMoved => user_input.pointerMove(pointer, hit, modifiers),
        .mousePressed, .mouseReleased => {
            // A press or release where the pointer is not yet: it moves there
            // first, as the device's own movement would have.
            const over = pointer.currentTarget();
            if (over == null or over.? != hit) user_input.pointerMove(pointer, hit, modifiers);
            const button = buttonIndex(params.button orelse .none) orelse return .{};
            if (params.type == .mousePressed) user_input.pointerDown(pointer, button, modifiers) else user_input.pointerUp(pointer, button, modifiers);
        },
        // A wheel scrolls what is under the point: geometry, the renderer's.
        // Nothing is hit with no renderer (above), so nothing scrolls.
        .mouseWheel => {},
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
