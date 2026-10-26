//! The Editing spec's delete and forwardDelete commands, from script and
//! from the keyboard (https://w3c.github.io/editing/docs/execCommand/,
//! cached as specs/w3c/execCommand.md).
//!
//! Script: document.execCommand("delete" | "forwardDelete") runs the
//! method's steps 3 and 5-8 here: not enabled -> false; the action; an
//! input event (inputType deleteContentBackward / deleteContentForward) at
//! the affected editing host when the DOM changed; true. Step 4's
//! beforeinput is NOT fired for a script's execCommand: no browser does
//! (WPT input-events/input-events-exec-command.html, "execCommand() should
//! only trigger 'input'" - Chrome 156 and Firefox 158 pass its "shouldn't
//! fire beforeinput" subtests at wpt.fyi c645564b0e; Safari fires none
//! either). Golden rule 2, no newer spec involved: the browsers decide.
//!
//! Keys: Backspace and Delete in an editing host ("Additional requirements":
//! the key must call execCommand("delete") / ("forwarddelete")) fire a
//! cancelable beforeinput at the editing host first - that is user input,
//! which every browser announces - then share the same action and input
//! event. No selection range, no beforeinput and nothing done
//! (editing/other/no-beforeinput-when-no-selection.html, all browsers).
//!
//! Layout: common.zig (definitions), whitespace.zig (canonical space
//! sequences), split_parent.zig, delete.zig (the actions), overrides.zig
//! (the recording/restoring machinery, TODO mocks until the formatting
//! commands exist).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");

pub const common = @import("common.zig");
pub const whitespace = @import("whitespace.zig");
pub const split_parent = @import("split_parent.zig");
pub const delete = @import("delete.zig");
pub const overrides = @import("overrides.zig");
pub const wrap = @import("wrap.zig");

const Instance = runtime.Instance;
const Edit = common.Edit;
const log = std.log.scoped(.editing);

/// The commands this module answers.
pub const Command = enum {
    delete,
    forward_delete,

    /// The command named by `name`, ASCII case-insensitively, or null.
    pub fn fromName(name: []const u8) ?Command {
        if (std.ascii.eqlIgnoreCase(name, "delete")) return .delete;
        if (std.ascii.eqlIgnoreCase(name, "forwarddelete")) return .forward_delete;
        return null;
    }

    /// "map an edit command to input type value".
    pub fn inputType(self: Command) []const u8 {
        return switch (self) {
            .delete => "deleteContentBackward",
            .forward_delete => "deleteContentForward",
        };
    }
};

/// The edit context for `document`, or null without a Selection (a document
/// with no browsing context).
fn beginEdit(document: *Instance) !?Edit {
    const selection = (try interfaces.Document.call_getSelection(document)) orelse return null;
    return .{ .document = document, .selection = selection, .allocator = document.ctx.allocator };
}

/// "enabled" for the non-miscellaneous commands: the active range is not
/// null, its start and end nodes are each editable or an editing host, and
/// some editing host is an inclusive ancestor of both.
fn isEnabledIn(edit: *Edit) !bool {
    const start = (try edit.rangeStart()) orelse return false;
    const end = (try edit.rangeEnd()) orelse return false;
    if (!try common.isEditableOrEditingHost(start.node)) return false;
    if (!try common.isEditableOrEditingHost(end.node)) return false;
    return (try affectedEditingHostOf(start.node, end.node)) != null;
}

/// queryCommandEnabled for a command of this module.
pub fn isEnabled(document: *Instance, command: Command) bool {
    _ = command;
    var edit = (beginEdit(document) catch return false) orelse return false;
    return isEnabledIn(&edit) catch false;
}

/// The "affected editing host": the editing host that is an inclusive
/// ancestor of both nodes and is not the ancestor of another such host -
/// the nearest one above their common ancestor.
fn affectedEditingHostOf(start_node: *Instance, end_node: *Instance) !?*Instance {
    var current: ?*Instance = start_node;
    while (current) |c| : (current = try common.parent(c)) {
        if (!common.isInclusiveDescendantOf(end_node, c)) continue;
        if (try common.isEditingHost(c)) return c;
    }
    return null;
}

fn affectedEditingHost(edit: *Edit) !?*Instance {
    const start = (try edit.rangeStart()) orelse return null;
    const end = (try edit.rangeEnd()) orelse return null;
    return try affectedEditingHostOf(start.node, end.node);
}

fn runAction(edit: *Edit, command: Command) !bool {
    return switch (command) {
        .delete => try delete.deleteAction(edit),
        .forward_delete => try delete.forwardDeleteAction(edit),
    };
}

/// document.execCommand(command) for a command of this module: the method's
/// steps 3 and 5-8 (no beforeinput, see the module comment).
pub fn execCommand(document: *Instance, command: Command) bool {
    var edit = (beginEdit(document) catch return false) orelse return false;
    // Step 3: not enabled -> false.
    if (!(isEnabledIn(&edit) catch false)) return false;
    // Step 4.5: the host the input event goes to, computed beforehand.
    const host = (affectedEditingHost(&edit) catch null) orelse return false;
    // Step 5: the action.
    const result = runAction(&edit, command) catch |err| {
        log.debug("{s}: {}", .{ @tagName(command), err });
        return false;
    };
    // Step 6.
    if (!result) return false;
    // Step 7: input, if the action modified the DOM tree.
    if (edit.modified and isConnected(host)) _ = fireInputEvent(host, "input", command.inputType());
    // Step 8.
    return true;
}

/// The insertText command's first step (specs/w3c/execCommand.md, "The
/// insertText command", action step 1): "If the active range is not
/// collapsed, delete the selection, with strip wrappers false", so a join
/// follows the browsers' rules (delete.zig) and the wrappers around the
/// range's start stay for the typed text (`foo<b>[bar]</b>baz` ->
/// `foo<b>a</b>baz`, editing/run/inserttext.html). The record and restore of
/// the overrides (steps 9 and 15) wait for the formatting batch, which
/// overrides.zig mocks until then. Whether it ran.
pub fn deleteSelectionBeforeInsert(document: *Instance) bool {
    var edit = (beginEdit(document) catch return false) orelse return false;
    if (edit.rangeCollapsed() catch true) return false;
    delete.deleteTheSelection(&edit, true, false, .forward) catch |err| {
        log.debug("insertText's delete the selection: {}", .{err});
        return false;
    };
    // Step 14.1, for the text inserted where the deletion left the caret:
    // "If node has only one child, which is a collapsed line break, remove
    // its child" - the br that padded the emptied block or wrapper
    // (`<blockquote><font color=blue>[foo]</font></blockquote>` -> `<font
    // color="blue">a</font>`, editing/run/inserttext.html; Chrome 155,
    // Firefox 158 and Safari 27). Steps 6-8 first: a Text node beside the
    // caret takes the text instead.
    removeLoneCollapsedLineBreak(&edit) catch |err| log.debug("insertText step 14.1: {}", .{err});
    return true;
}

fn removeLoneCollapsedLineBreak(edit: *Edit) !void {
    const start = (try edit.rangeStart()) orelse return;
    if (common.isText(start.node)) return;
    if (try common.childBefore(start.node, start.offset)) |before| if (common.isText(before)) return;
    if (try common.childAt(start.node, start.offset)) |at| if (common.isText(at)) return;
    if ((try common.childCount(start.node)) != 1) return;
    const only = (try common.firstChild(start.node)).?;
    if (!try common.isCollapsedLineBreak(only)) return;
    if (!try common.isEditable(only)) return;
    try edit.removeNode(only);
}

/// Whether `target` (the focused element, or the body for a design-mode
/// document) is where Backspace and Delete edit rich text.
pub fn isEditableTarget(target: *Instance) bool {
    return common.isEditableOrEditingHost(target) catch false;
}

/// Backspace (`.delete`) or Delete (`.forward_delete`) pressed with the
/// focus in an editing host: beforeinput at the affected editing host, the
/// action unless it was cancelled, then input.
pub fn deleteByKey(target: *Instance, command: Command) void {
    const document = nodeDocument(target) orelse return;
    var edit = (beginEdit(document) catch return) orelse return;
    // No active range in an editing host: the browsers do nothing, and
    // fire no beforeinput.
    if (!(isEnabledIn(&edit) catch false)) return;
    const host = (affectedEditingHost(&edit) catch null) orelse return;
    if (!fireInputEvent(host, "beforeinput", command.inputType())) return;
    if (!isConnected(host)) return;
    // Step 4.4: a beforeinput listener may have moved or removed the
    // selection.
    if (!(isEnabledIn(&edit) catch false)) return;
    const affected = (affectedEditingHost(&edit) catch null) orelse return;
    const result = runAction(&edit, command) catch |err| {
        log.debug("{s} by key: {}", .{ @tagName(command), err });
        return;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEvent(affected, "input", command.inputType());
}

fn nodeDocument(node: *Instance) ?*Instance {
    if (common.isDocument(node)) return node;
    return interfaces.Node.get_ownerDocument(node) catch null;
}

fn isConnected(node: *Instance) bool {
    return interfaces.Node.get_isConnected(node) catch false;
}

fn viewOf(target: *Instance) ?*Instance {
    const document = nodeDocument(target) orelse return null;
    return interfaces.Document.get_defaultView(document) catch null;
}

/// Fire a beforeinput or input InputEvent at `target` with `input_type`;
/// whether it was not cancelled. The event is freed unless a listener kept
/// it.
fn fireInputEvent(target: *Instance, comptime event_type: []const u8, input_type: []const u8) bool {
    const cancelable = comptime std.mem.eql(u8, event_type, "beforeinput");
    const init: dictionaries.InputEventInit = .{
        .base = .{ .base = .{ .bubbles = true, .cancelable = cancelable, .composed = true }, .view = viewOf(target) },
        .data = null,
        .isComposing = false,
        .inputType = runtime.DOMString.initInterned(input_type),
    };
    const event = interfaces.InputEvent.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.InputEventInit).passed(init)) catch |err| {
        log.debug("{s} not fired: {}", .{ event_type, err });
        return true;
    };
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    return dom.fire_event.dispatchTrusted(target, event) catch true;
}

test "command names are ASCII case-insensitive" {
    try std.testing.expectEqual(Command.delete, Command.fromName("delete").?);
    try std.testing.expectEqual(Command.delete, Command.fromName("DELETE").?);
    try std.testing.expectEqual(Command.forward_delete, Command.fromName("forwardDelete").?);
    try std.testing.expectEqual(Command.forward_delete, Command.fromName("FORWARDDELETE").?);
    try std.testing.expect(Command.fromName("insertText") == null);
    try std.testing.expectEqualStrings("deleteContentBackward", Command.delete.inputType());
    try std.testing.expectEqualStrings("deleteContentForward", Command.forward_delete.inputType());
}
