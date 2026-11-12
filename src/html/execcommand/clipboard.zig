//! Clipboard API and events 8 "Clipboard Actions" (specs/w3c/clipboard-apis.md):
//! the copy, cut and paste actions, and Appendix A's "fire a clipboard
//! event" and "write content to the clipboard" - reached from the user's
//! Ctrl/Meta+C, X and V (src/html/user_input.zig, script-triggered unset)
//! and from document.execCommand("copy" | "cut" | "paste") (root.zig,
//! script-triggered set). The clipboard itself is the platform's, through
//! the protocol only (clipboard_platform.zig).
//!
//! The browsers' code this follows: Blink's ClipboardCommands::ExecuteCopy /
//! ExecuteCut / ExecutePaste and DispatchClipboardEvent
//! (core/editing/commands/clipboard_commands.cc), Gecko's
//! nsCopySupport::FireClipboardEvent (dom/base/nsCopySupport.cpp) with
//! EditorBase::CutAsAction / HTMLEditor::PasteAsAction, and WebKit's
//! Editor::copy / cut / paste with Editor::dispatchClipboardEvent
//! (editing/Editor.cpp).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const common = @import("common.zig");
const clipboard_platform = @import("clipboard_platform.zig");
const serialization = @import("../serialization.zig");
const user_activation = @import("../user_activation.zig");

const Instance = runtime.Instance;
const Part = clipboard_platform.Part;
const log = std.log.scoped(.clipboard);

pub const Action = enum {
    copy,
    cut,
    paste,

    fn eventType(self: Action) []const u8 {
        return @tagName(self);
    }
};

/// The action's script-triggered flag: set for execCommand, unset for the
/// user's own shortcut keys.
const Trigger = enum { user, script };

/// The user pressed the platform's copy, cut or paste shortcut with the
/// focus on `target`: the action, as from the user agent's own interface
/// (clipboard-apis 5.3.1 and 5.3.2: such an action may write and read the
/// clipboard). Its events fire inside the keydown's default action, before
/// keyup (5.3.4).
pub fn byKey(target: *Instance, action: Action) void {
    const document = nodeDocument(target) orelse return;
    _ = run(document, action, .user);
}

/// document.execCommand("copy" | "cut" | "paste"): the action with the
/// script-triggered flag set; its return value is execCommand's.
pub fn execCommand(document: *Instance, action: Action) bool {
    return run(document, action, .script);
}

fn run(document: *Instance, action: Action, trigger: Trigger) bool {
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    const scratch = arena.allocator();
    return switch (action) {
        .copy => copyAction(document, trigger, scratch),
        .cut => cutAction(document, trigger, scratch),
        .paste => pasteAction(document, trigger, scratch),
    } catch |err| {
        log.debug("{s}: {}", .{ @tagName(action), err });
        return false;
    };
}

/// The script-may-access-clipboard flag for copy and cut (8, "allowed to
/// modify the clipboard", 5.3.1): the user's own action, or script that is
/// "allowed to show a popup" - its window has transient activation (HTML
/// 6.4.1). Blink's ClipboardCommands::CanWriteClipboard (a user gesture or
/// the javascript-can-access-clipboard setting), Gecko's
/// nsContentUtils::IsCutCopyAllowed (user input handling), WebKit's
/// Editor::canDHTMLCopy path (UserGestureIndicator): the three agree.
fn mayModifyClipboard(document: *Instance, trigger: Trigger) bool {
    if (trigger == .user) return true;
    const window = interfaces.Document.get_defaultView(document) catch return false;
    return user_activation.hasTransientActivation(window orelse return false);
}

/// 8.1 The copy action.
fn copyAction(document: *Instance, trigger: Trigger, scratch: std.mem.Allocator) !bool {
    // 1. Script-triggered without script-may-access-clipboard: false.
    const may_access = mayModifyClipboard(document, trigger);
    if (trigger == .script and !may_access) return false;
    // 2. Fire a clipboard event named copy.
    const fired = try fireClipboardEvent(document, .copy, null, scratch);
    if (fired.not_canceled) {
        // 3.1. "Copy the selected contents, if any, to the clipboard",
        //      with text/html and text/plain alternates.
        const parts = try selectedContents(document, scratch);
        if (parts.len > 0) _ = try clipboard_platform.write(document.ctx, document.ctx.allocator, may_access, parts);
        // 3.2. TODO(clipboardchange): fire clipboardchange (5.2.1.1 "fire a
        //      clipboardchange event", with its focus and change-id steps).
    } else {
        // 4.1. "Write content to the clipboard" from the event's items.
        try writeContent(document, fired, may_access);
    }
    // 5.
    return true;
}

/// 8.2 The cut action.
fn cutAction(document: *Instance, trigger: Trigger, scratch: std.mem.Allocator) !bool {
    // 1. Script-triggered without script-may-access-clipboard: false.
    const may_access = mayModifyClipboard(document, trigger);
    if (trigger == .script and !may_access) return false;
    // 2. Fire a clipboard event named cut.
    const fired = try fireClipboardEvent(document, .cut, null, scratch);
    if (fired.not_canceled) {
        // 3.1. A selection in an editable context where cutting is enabled.
        const control = @import("../user_input.zig").focusedTextControl(document);
        const editable = if (control) |c| @import("../user_input.zig").isMutableTextControl(c) else @import("root.zig").hasEditableSelection(document);
        // 3.2. Otherwise: false.
        if (!editable) return false;
        // 3.1.1. Copy the selected contents.
        const parts = try selectedContents(document, scratch);
        if (parts.len > 0) _ = try clipboard_platform.write(document.ctx, document.ctx.allocator, may_access, parts);
        // 3.1.2. Remove them and collapse the selection (with 3.1.4's
        //        beforeinput and input, deleteByCut).
        if (control) |c| {
            @import("../user_input.zig").deleteByCut(c);
        } else {
            @import("root.zig").deleteByCut(document);
        }
        // 3.1.3. TODO(clipboardchange), as in the copy action.
    } else {
        // 4.1. Write content to the clipboard; 4.2 TODO(clipboardchange).
        try writeContent(document, fired, may_access);
    }
    // 5.
    return true;
}

/// 8.3 The paste action.
fn pasteAction(document: *Instance, trigger: Trigger, scratch: std.mem.Allocator) !bool {
    // 1. Script-triggered: script-may-access-clipboard needs an
    //    implementation-specific permission that Crane does not grant (no
    //    site or app is configured to read the clipboard; 5.3.2), so false
    //    and no event - Chrome's default (ClipboardCommands::CanReadClipboard
    //    asks ContentSettingsClient::AllowReadFromClipboard, false unless an
    //    extension holds clipboardRead).
    if (trigger == .script) return false;
    // Fire-a-clipboard-event step 7.1.2 reads "each clipboard-part on the OS
    // clipboard": the read happens first, synchronously.
    var contents = try clipboard_platform.read(document.ctx, document.ctx.allocator, true, &.{ "text/plain", "text/html" });
    defer if (contents) |*c| c.deinit();
    // 2. Fire a clipboard event named paste.
    const fired = try fireClipboardEvent(document, .paste, if (contents) |*c| c else null, scratch);
    // 4. Canceled: false.
    if (!fired.not_canceled) return false;
    // 3.1. A selection or cursor in an editable context: 3.1.1 insert the
    //      most suitable content found on the clipboard, 3.1.2 with its
    //      events (insertFromPaste).
    const markup: ?[]const u8 = if (contents) |*c| c.find("text/html") else null;
    const text: ?[]const u8 = if (contents) |*c| c.find("text/plain") else null;
    const user_input = @import("../user_input.zig");
    if (user_input.focusedTextControl(document)) |control| {
        if (!user_input.isMutableTextControl(control)) return false;
        // A text control takes plain text: the clipboard's, or the
        // markup's text (Blink's TextFieldInputType reads PlainText).
        const plain = text orelse if (markup) |m| try @import("insert_content.zig").plainTextOf(document, m, scratch) else return true;
        user_input.pasteIntoTextControl(control, plain);
        return true;
    }
    // 3.2. Otherwise: false.
    if (!@import("root.zig").hasEditableSelection(document)) return false;
    if (markup == null and text == null) return true;
    const data_transfer = try pastedDataTransfer(document, markup, text, scratch);
    defer if (data_transfer) |held| held.release();
    _ = @import("root.zig").insertFromPaste(document, markup, text, if (data_transfer) |held| held.instance else null);
    // 5.
    return true;
}

/// A natively made object kept for a native caller: freed unless script
/// (an event's traced edge, a listener) gave it a wrapper.
const Held = struct {
    instance: *Instance,
    generation: u64,

    fn of(instance: *Instance) Held {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn release(self: Held) void {
        self.instance.releaseIfUnwrapped(self.generation);
    }
};

/// The read-only DataTransfer the paste's beforeinput and input carry
/// (Input Events 2, dataTransfer for insertFromPaste in an editing host):
/// text/plain - the clipboard's, or the markup's text - and text/html.
fn pastedDataTransfer(document: *Instance, markup: ?[]const u8, text: ?[]const u8, scratch: std.mem.Allocator) !?Held {
    const data_transfer = try interfaces.DataTransfer.call_constructor(document.ctx);
    const held = Held.of(data_transfer);
    errdefer held.release();
    const store = dom.drag_data_store.storeOf(data_transfer) orelse return error.NotSupported;
    const plain = text orelse if (markup) |m| try @import("insert_content.zig").plainTextOf(document, m, scratch) else "";
    _ = try store.addText(plain, "text/plain");
    if (markup) |m| _ = try store.addText(m, "text/html");
    store.setMode(.read_only);
    return held;
}

/// What firing a clipboard event left for the action.
const Fired = struct {
    not_canceled: bool,
    /// A canceled copy or cut: the event's DataTransfer's text items, in
    /// `scratch`, for "write content to the clipboard".
    items: []const Part = &.{},
    clear_was_called: bool = false,
    types_to_clear: usize = 0,
};

/// Appendix A "fire a clipboard event" `action` - for paste, with the
/// clipboard's `contents` (null: nothing could be read).
fn fireClipboardEvent(document: *Instance, action: Action, contents: ?*const clipboard_platform.Contents, scratch: std.mem.Allocator) !Fired {
    // 6. The target.
    const target = eventTarget(document) orelse return .{ .not_canceled = true };
    const realm = target.ctx;
    // 1-2. clear-was-called and types-to-clear: the store's, from 3 on.
    // 3. clipboard-event-data: a new DataTransfer with an empty items list.
    const data_transfer = try interfaces.DataTransfer.call_constructor(realm);
    const data_transfer_held = Held.of(data_transfer);
    defer data_transfer_held.release();
    const store = dom.drag_data_store.storeOf(data_transfer) orelse return error.NotSupported;
    // 4. clipboard-entry: null - the protocol's clipboard has no sequence
    //    numbers (so step 11.3's check never applies).
    // 5. trusted: the user agent makes the event (for execCommand too, as
    //    Blink's DispatchClipboardEvent and WebKit's dispatchClipboardEvent
    //    fire it trusted).
    // 7. Process the event.
    switch (action) {
        .paste => {
            // 7.1.1. Read-only mode.
            store.setMode(.read_only);
            // 7.1.2. trusted: each clipboard-part on the OS clipboard.
            if (contents) |c| for (c.parts.items) |part| {
                if (std.ascii.eqlIgnoreCase(part.mime_type, "text/plain")) {
                    // 7.1.2.1: plain text, a string item text/plain.
                    _ = store.addText(part.data, "text/plain") catch |err| if (err != error.NotSupportedError) return err;
                } else if (std.ascii.eqlIgnoreCase(part.mime_type, "text/html")) {
                    // 7.1.2.3: "process an HTML paste event" - its round trip
                    // through the parser changes nothing here: the part has
                    // no known source URL (step 3) and no local references
                    // (step 4). Blink's DataObject::CreateFromClipboard
                    // likewise exposes the clipboard's markup as read.
                    _ = store.addText(part.data, "text/html") catch |err| if (err != error.NotSupportedError) return err;
                }
                // 7.1.2.2 and 7.1.2.4 (files and binary mandatory types): the
                // read asks for text/plain and text/html only.
            };
            // 7.1.3-4: files and types follow the item list.
        },
        // 7.2. copy and cut: read/write mode.
        .copy, .cut => store.setMode(.read_write),
    }
    // 8-10. clipboardData, isTrusted (dispatchTrusted) and composed.
    // 11. Dispatched bubbling and cancelable, a ClipboardEvent, at target.
    const init: dictionaries.ClipboardEventInit = .{
        .base = .{ .bubbles = true, .cancelable = true, .composed = true },
        .clipboardData = data_transfer,
    };
    const event = try interfaces.ClipboardEvent.call_constructor(realm, runtime.DOMString.initInterned(action.eventType()), webidl.Opt(dictionaries.ClipboardEventInit).passed(init));
    const event_held = Held.of(event);
    defer event_held.release();
    const not_canceled = dom.fire_event.dispatchTrusted(target, event) catch true;
    var fired: Fired = .{ .not_canceled = not_canceled };
    if (action != .paste and !not_canceled) {
        // What "write content to the clipboard" takes: the items, and
        // step 11.1-11.2's flags.
        var items: std.ArrayList(Part) = .empty;
        for (store.items.items) |item| {
            if (item.kind != .text) continue;
            try items.append(scratch, .{ .mime_type = try scratch.dupe(u8, item.type_string), .data = try scratch.dupe(u8, item.data.text) });
        }
        fired.items = items.items;
        fired.clear_was_called = store.clear_was_called;
        fired.types_to_clear = store.types_to_clear.items.len;
    }
    // The event is over: its DataTransfer gives nothing more and takes
    // nothing (Blink: SetAccessPolicy(kNumb) after the dispatch).
    store.setMode(.protected);
    return fired;
}

/// Appendix A "write content to the clipboard" for a canceled copy or cut.
fn writeContent(document: *Instance, fired: Fired, may_access: bool) !void {
    // 1. Items: clear the clipboard and place each part (the platform
    //    places each MIME type with its own format: 1.2.1-1.2.3).
    if (fired.items.len > 0) {
        _ = try clipboard_platform.write(document.ctx, document.ctx.allocator, may_access, fired.items);
        return;
    }
    // 2. No items: clear the clipboard when clearData() was called with
    //    no type left to clear.
    if (!fired.clear_was_called) return;
    if (fired.types_to_clear == 0) {
        _ = try clipboard_platform.write(document.ctx, document.ctx.allocator, may_access, &.{});
        return;
    }
    // 2.1.2. Removing only some types "in an operating system and
    // implementation-specific way" is at risk in the spec (its issue): the
    // protocol has no such operation, and the clipboard is left as it is.
}

/// Fire-a-clipboard-event step 6: the event's target. The spec takes the
/// selection's start in an editable context and the focused node
/// otherwise; Blink's FindEventTargetForClipboardEvent and WebKit's
/// Editor::findEventTargetFromSelection take the element at the selection's
/// start whenever there is a selection, and the focused element (or the
/// body) without one - golden rule 2, no newer spec involved: the
/// browsers. A focused text control is the target of its own selection
/// (the browsers' selection is in its inner editor, retargeted to it).
fn eventTarget(document: *Instance) ?*Instance {
    if (@import("../user_input.zig").focusedTextControl(document)) |control| return control;
    if (selectionStartElement(document)) |element| return element;
    if (interfaces.Document.get_activeElement(document) catch null) |focused| return focused;
    return interfaces.Document.get_body(document) catch null;
}

/// The element holding the start of `document`'s selection, if it has a
/// range.
fn selectionStartElement(document: *Instance) ?*Instance {
    const selection = (interfaces.Document.call_getSelection(document) catch return null) orelse return null;
    if ((interfaces.Selection.get_rangeCount(selection) catch 0) == 0) return null;
    const range = interfaces.Selection.call_getRangeAt(selection, 0) catch return null;
    const node = interfaces.AbstractRange.get_startContainer(range) catch return null;
    if (common.isElement(node)) return node;
    return interfaces.Node.get_parentElement(node) catch null;
}

/// "Copy the selected contents, if any": text/plain, the selection's
/// rendered text (its stringifier: a focused text control's selected
/// value, else the range's innerText-like text, as Blink's
/// Editor::SelectedTextForClipboard), and - outside a text control -
/// text/html, the HTML serialization of the range's contents (Blink's
/// CreateMarkup of the selection; Gecko's nsCopySupport HTML encoder).
/// Empty when nothing is selected. In `scratch`.
fn selectedContents(document: *Instance, scratch: std.mem.Allocator) ![]const Part {
    const selection = (try interfaces.Document.call_getSelection(document)) orelse return &.{};
    var parts: std.ArrayList(Part) = .empty;
    const text = try interfaces.Selection.serialize(selection);
    defer selection.ctx.allocator.free(text);
    if (@import("../user_input.zig").focusedTextControl(document) != null) {
        if (text.len == 0) return &.{};
        try parts.append(scratch, .{ .mime_type = "text/plain", .data = try scratch.dupe(u8, text) });
        return parts.items;
    }
    if ((try interfaces.Selection.get_rangeCount(selection)) == 0) return &.{};
    const range = try interfaces.Selection.call_getRangeAt(selection, 0);
    if (try interfaces.AbstractRange.get_collapsed(range)) return &.{};
    const fragment = try interfaces.Range.call_cloneContents(range);
    defer dom.node_creation.destroyUninserted(fragment);
    var markup = try serialization.fragment(fragment, true);
    defer markup.deinit(document.ctx.allocator);
    try parts.append(scratch, .{ .mime_type = "text/plain", .data = try scratch.dupe(u8, text) });
    try parts.append(scratch, .{ .mime_type = "text/html", .data = try scratch.dupe(u8, markup.asSlice()) });
    return parts.items;
}

fn nodeDocument(node: *Instance) ?*Instance {
    if (common.isDocument(node)) return node;
    return interfaces.Node.get_ownerDocument(node) catch null;
}
