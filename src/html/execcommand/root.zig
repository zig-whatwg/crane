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
//! The inline formatting commands (backColor ... unlink, inline.zig) share
//! the same method steps; their input event's inputType follows the
//! browsers and Input Events (see Command.inputType). The block formatting
//! commands (formatBlock, indent, outdent, the list, paragraph, line break,
//! horizontal rule and justify commands: blocks.zig, over block.zig,
//! lists.zig, indent.zig, alignment.zig and paragraph.zig) share them too.
//!
//! Layout: common.zig (definitions), whitespace.zig (canonical space
//! sequences), split_parent.zig, wrap.zig, delete.zig (the delete actions),
//! inline.zig (the inline formatting commands), style_values.zig (their CSS
//! reads and writes), overrides.zig (the Document's overrides, recording
//! and restoring).
//!
//! Every entry point runs its command, query or key action with a scratch
//! arena (Edit.scratch) that lives exactly as long as it: `withEdit` makes
//! it and `defer`s its deinit, so it is freed on every exit path.

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
pub const inline_formatting = @import("inline.zig");
pub const style_values = @import("style_values.zig");
pub const insert_text = @import("insert_text.zig");
pub const insert_content = @import("insert_content.zig");
pub const blocks = @import("blocks.zig");

const Instance = runtime.Instance;
const Edit = common.Edit;
const log = std.log.scoped(.editing);

/// The commands this module answers.
pub const Command = enum {
    delete,
    forward_delete,
    // The inline formatting commands (lane editing3, inline.zig).
    back_color,
    bold,
    create_link,
    font_name,
    font_size,
    fore_color,
    hilite_color,
    italic,
    remove_format,
    strikethrough,
    subscript,
    superscript,
    underline,
    unlink,
    // insertText, insertHTML and insertImage (lane editing3,
    // insert_text.zig and insert_content.zig).
    insert_text,
    insert_html,
    insert_image,
    // The block formatting commands (lane editing4, blocks.zig).
    format_block,
    indent,
    outdent,
    insert_ordered_list,
    insert_unordered_list,
    insert_paragraph,
    insert_line_break,
    insert_horizontal_rule,
    justify_center,
    justify_full,
    justify_left,
    justify_right,

    const Row = struct { []const u8, Command };

    /// The command names, matched ASCII case-insensitively: one row per
    /// command.
    const names = [_]Row{
        .{ "delete", .delete },
        .{ "forwardDelete", .forward_delete },
        // Lane editing3: the inline formatting commands.
        .{ "backColor", .back_color },
        .{ "bold", .bold },
        .{ "createLink", .create_link },
        .{ "fontName", .font_name },
        .{ "fontSize", .font_size },
        .{ "foreColor", .fore_color },
        .{ "hiliteColor", .hilite_color },
        .{ "italic", .italic },
        .{ "removeFormat", .remove_format },
        .{ "strikethrough", .strikethrough },
        .{ "subscript", .subscript },
        .{ "superscript", .superscript },
        .{ "underline", .underline },
        .{ "unlink", .unlink },
        .{ "insertText", .insert_text },
        .{ "insertHTML", .insert_html },
        .{ "insertImage", .insert_image },
    } ++ blockRows();

    /// Lane editing4: the block formatting commands' rows, from blocks.zig.
    fn blockRows() [blocks.names.len]Row {
        var out: [blocks.names.len]Row = undefined;
        for (blocks.names, 0..) |row, i| out[i] = .{ row[0], @field(Command, @tagName(row[1])) };
        return out;
    }

    /// The block formatting command this is, or null.
    fn block(self: Command) ?blocks.Command {
        return std.meta.stringToEnum(blocks.Command, @tagName(self));
    }

    /// The command named by `name`, ASCII case-insensitively, or null.
    pub fn fromName(name: []const u8) ?Command {
        for (names) |row| if (std.ascii.eqlIgnoreCase(name, row[0])) return row[1];
        return null;
    }

    /// "map an edit command to input type value". For the inline
    /// formatting commands the spec's table lacks italic, underline,
    /// subscript, hiliteColor and removeFormat; the browsers fire
    /// formatItalic, formatUnderline, formatSubscript, formatBackColor and
    /// formatRemove (WPT input-events/input-events-exec-command.html, the
    /// Input Events inputType list): golden rule 2, the browsers decide.
    /// fontSize and unlink have no input type ("").
    pub fn inputType(self: Command) []const u8 {
        return switch (self) {
            .delete => "deleteContentBackward",
            .forward_delete => "deleteContentForward",
            .back_color, .hilite_color => "formatBackColor",
            .bold => "formatBold",
            .create_link => "insertLink",
            .font_name => "formatFontName",
            .font_size => "",
            .fore_color => "formatFontColor",
            .italic => "formatItalic",
            .remove_format => "formatRemove",
            .strikethrough => "formatStrikeThrough",
            .subscript => "formatSubscript",
            .superscript => "formatSuperscript",
            .underline => "formatUnderline",
            .unlink => "",
            .insert_text => "insertText",
            .insert_html, .insert_image => "",
            .format_block, .indent, .outdent, .insert_ordered_list, .insert_unordered_list, .insert_paragraph, .insert_line_break, .insert_horizontal_rule, .justify_center, .justify_full, .justify_left, .justify_right => self.block().?.inputType(),
        };
    }

    /// Whether the command can be enabled in a plaintext-only editing host:
    /// false for every command whose section says "This command must not
    /// be enabled if the editing host is in the plaintext-only state".
    pub fn enabledInPlaintextOnly(self: Command) bool {
        return switch (self) {
            .delete, .forward_delete, .insert_text, .insert_html => true,
            .insert_image => false,
            .back_color, .bold, .create_link, .font_name, .font_size, .fore_color, .hilite_color, .italic, .remove_format, .strikethrough, .subscript, .superscript, .underline, .unlink => false,
            .format_block, .indent, .outdent, .insert_ordered_list, .insert_unordered_list, .insert_paragraph, .insert_line_break, .insert_horizontal_rule, .justify_center, .justify_full, .justify_left, .justify_right => self.block().?.enabledInPlaintextOnly(),
        };
    }

    /// The inline formatting command this is, or null.
    fn inlineCommand(self: Command) ?inline_formatting.Command {
        return switch (self) {
            .back_color => .back_color,
            .bold => .bold,
            .create_link => .create_link,
            .font_name => .font_name,
            .font_size => .font_size,
            .fore_color => .fore_color,
            .hilite_color => .hilite_color,
            .italic => .italic,
            .remove_format => .remove_format,
            .strikethrough => .strikethrough,
            .subscript => .subscript,
            .superscript => .superscript,
            .underline => .underline,
            .unlink => .unlink,
            .delete, .forward_delete, .insert_text, .insert_html, .insert_image => null,
            .format_block, .indent, .outdent, .insert_ordered_list, .insert_unordered_list, .insert_paragraph, .insert_line_break, .insert_horizontal_rule, .justify_center, .justify_full, .justify_left, .justify_right => null,
        };
    }

    /// The input event's data: the inserted text for insertText (Input
    /// Events; every browser sets it for execCommand and typing alike,
    /// input-events/input-events-exec-command.html), null otherwise.
    fn inputData(self: Command, value: []const u8) ?[]const u8 {
        return switch (self) {
            .insert_text => value,
            else => null,
        };
    }
};

/// The edit context for `document`, or null without a Selection (a document
/// with no browsing context). `scratch` is the arena the caller owns for
/// exactly this command, query or key action.
fn beginEdit(document: *Instance, scratch: std.mem.Allocator) !?Edit {
    const selection = (try interfaces.Document.call_getSelection(document)) orelse return null;
    return .{ .document = document, .selection = selection, .allocator = document.ctx.allocator, .scratch = scratch };
}

/// "enabled" for the non-miscellaneous commands: the active range is not
/// null, its start and end nodes are each editable or an editing host, and
/// some editing host is an inclusive ancestor of both - and, for a command
/// that must not be enabled in a plaintext-only editing host, that host is
/// not one.
fn isEnabledIn(edit: *Edit, command: Command) !bool {
    const start = (try edit.rangeStart()) orelse return false;
    const end = (try edit.rangeEnd()) orelse return false;
    if (!try common.isEditableOrEditingHost(start.node)) return false;
    if (!try common.isEditableOrEditingHost(end.node)) return false;
    const host = (try affectedEditingHostOf(start.node, end.node)) orelse return false;
    if (!command.enabledInPlaintextOnly() and try isPlaintextOnly(host)) return false;
    return true;
}

/// Whether the editing host `host` is in the plaintext-only state - the
/// NEAREST editing host, as HTML defines one (an element whose
/// contenteditable is true or plaintext-only is an editing host even inside
/// another). Chrome and Safari agree: a contenteditable=plaintext-only
/// element inside a contenteditable=true host takes no bold, and a
/// contenteditable=true one inside a plaintext-only host does (editing/
/// plaintext-only/nested-with-contenteditable-true.html: Chrome 156 and
/// Safari 27 fail its "should support style edit" / "should not support
/// style edit" rows, which expect Firefox's outermost-host rule;
/// plaintext-only-in-designMode.html likewise; wpt.fyi f4febe305a /
/// 1ec6aacb4e). Golden rule 2: the majority, which is also HTML's text.
fn isPlaintextOnly(host: *Instance) !bool {
    if (!try common.isHtmlElement(host)) return false;
    var state = try interfaces.HTMLElement.get_contentEditable(host);
    defer state.deinit(host.ctx.allocator);
    return std.mem.eql(u8, state.asSlice(), "plaintext-only");
}

/// Whether the active range's editing host edits as plaintext-only (see
/// isPlaintextOnly).
pub fn activeHostIsPlaintextOnly(edit: *Edit) !bool {
    const host = (try affectedEditingHost(edit)) orelse return false;
    return try isPlaintextOnly(host);
}

/// queryCommandEnabled for a command of this module.
pub fn isEnabled(document: *Instance, command: Command) bool {
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    return isEnabledIn(&edit, command) catch false;
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

fn runAction(edit: *Edit, command: Command, value: []const u8) !bool {
    return switch (command) {
        .delete => try delete.deleteAction(edit),
        .forward_delete => try delete.forwardDeleteAction(edit),
        .back_color, .bold, .create_link, .font_name, .font_size, .fore_color, .hilite_color, .italic, .remove_format, .strikethrough, .subscript, .superscript, .underline, .unlink => try inline_formatting.action(edit, command.inlineCommand().?, value),
        .insert_text => try insert_text.action(edit, value, insertParagraphAction),
        .insert_html => try insert_content.insertHtml(edit, value),
        .insert_image => try insert_content.insertImage(edit, value),
        .format_block, .indent, .outdent, .insert_ordered_list, .insert_unordered_list, .insert_paragraph, .insert_line_break, .insert_horizontal_rule, .justify_center, .justify_full, .justify_left, .justify_right => try blocks.action(edit, command.block().?, value),
    };
}

/// insertText step 5's "take the action for the insertParagraph command",
/// through this dispatch (its action is lane editing4's, blocks.zig).
fn insertParagraphAction(edit: *Edit) anyerror!bool {
    return try runAction(edit, .insert_paragraph, "");
}

/// document.execCommand(command, showUI, value) for a command of this
/// module, `value` with execCommand()'s default "" applied (step 2): the
/// method's steps 3 and 5-8 (no beforeinput, see the module comment).
pub fn execCommand(document: *Instance, command: Command, value: []const u8) bool {
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    // Step 3: not enabled -> false.
    if (!(isEnabledIn(&edit, command) catch false)) return false;
    // Step 4.5: the host the input event goes to, computed beforehand.
    const host = (affectedEditingHost(&edit) catch null) orelse return false;
    // Step 5: the action.
    const result = runAction(&edit, command, value) catch |err| {
        log.debug("{s}: {}", .{ @tagName(command), err });
        return false;
    };
    // Step 6.
    if (!result) return false;
    // Step 7: input, if the action modified the DOM tree.
    if (edit.modified and isConnected(host)) _ = fireInputEvent(host, "input", command.inputType(), command.inputData(value));
    // Step 8.
    return true;
}

/// queryCommandState() for a command of this module: null when the
/// command has no state (the caller answers false). The state override
/// (step 2) applies to the inline formatting commands that have one.
pub fn queryState(document: *Instance, command: Command) ?bool {
    if (command.block()) |b| {
        var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
        defer arena.deinit();
        var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
        return blocks.state(&edit, b) catch |err| {
            log.debug("queryCommandState {s}: {}", .{ @tagName(command), err });
            return false;
        };
    }
    const inline_command = command.inlineCommand() orelse return null;
    if (!inline_command.hasState()) return null;
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    if ((edit.activeRange() catch null) == null) return false;
    return inline_formatting.queryState(&edit, inline_command) catch |err| {
        log.debug("queryCommandState {s}: {}", .{ @tagName(command), err });
        return false;
    };
}

/// queryCommandIndeterm() for a command of this module: null when the
/// command has no indeterminacy.
pub fn queryIndeterm(document: *Instance, command: Command) ?bool {
    if (command.block()) |b| {
        var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
        defer arena.deinit();
        var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
        return blocks.indeterm(&edit, b) catch |err| {
            log.debug("queryCommandIndeterm {s}: {}", .{ @tagName(command), err });
            return false;
        };
    }
    const inline_command = command.inlineCommand() orelse return null;
    if (!inline_command.hasIndeterm()) return null;
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    if ((edit.activeRange() catch null) == null) return false;
    return inline_formatting.commandIndeterm(&edit, inline_command) catch |err| {
        log.debug("queryCommandIndeterm {s}: {}", .{ @tagName(command), err });
        return false;
    };
}

/// queryCommandValue() for a command of this module, OWNED by `allocator`:
/// null when the command has no value (the caller answers ""). The value
/// override steps 2-3 apply to the inline formatting commands.
pub fn queryValue(document: *Instance, command: Command, allocator: std.mem.Allocator) !?[]u8 {
    if (command.block()) |b| {
        var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
        defer arena.deinit();
        var edit = (beginEdit(document, arena.allocator()) catch return try allocator.dupe(u8, "")) orelse return try allocator.dupe(u8, "");
        const result = blocks.value(&edit, b) catch |err| {
            log.debug("queryCommandValue {s}: {}", .{ @tagName(command), err });
            return try allocator.dupe(u8, "");
        };
        return if (result) |v| try allocator.dupe(u8, v) else null;
    }
    const inline_command = command.inlineCommand() orelse return null;
    if (!inline_command.hasValue()) return null;
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return try allocator.dupe(u8, "")) orelse return try allocator.dupe(u8, "");
    if ((edit.activeRange() catch null) == null) return try allocator.dupe(u8, "");
    const value = inline_formatting.queryValue(&edit, inline_command) catch |err| blk: {
        log.debug("queryCommandValue {s}: {}", .{ @tagName(command), err });
        break :blk "";
    };
    return try allocator.dupe(u8, value);
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
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return) orelse return;
    // No active range in an editing host: the browsers do nothing, and
    // fire no beforeinput.
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const host = (affectedEditingHost(&edit) catch null) orelse return;
    if (!fireInputEvent(host, "beforeinput", command.inputType(), null)) return;
    if (!isConnected(host)) return;
    // Step 4.4: a beforeinput listener may have moved or removed the
    // selection.
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const affected = (affectedEditingHost(&edit) catch null) orelse return;
    const result = runAction(&edit, command, "") catch |err| {
        log.debug("{s} by key: {}", .{ @tagName(command), err });
        return;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEvent(affected, "input", command.inputType(), null);
}

/// The user types `text` with the focus in an editing host (Editing spec,
/// "Additional requirements": the user agent must call
/// execCommand("inserttext", false, value)): a cancelable beforeinput
/// (insertText, data the text) at the affected editing host, the
/// insertText action unless it was cancelled, then input - the key path's
/// events, as deleteByKey fires them.
pub fn typeByKey(target: *Instance, text: []const u8) void {
    commandByKey(target, .insert_text, text);
}

/// The user's Enter (insertParagraph) or Shift+Enter (insertLineBreak) in
/// an editing host ("Additional requirements"), by command name (their
/// actions are lane editing4's, blocks.zig).
pub fn lineBreakByKey(target: *Instance, name: []const u8) void {
    const command = Command.fromName(name) orelse return;
    commandByKey(target, command, "");
}

/// A command the user asked for with a key: beforeinput, re-check, the
/// action, input (see deleteByKey).
fn commandByKey(target: *Instance, command: Command, value: []const u8) void {
    const document = nodeDocument(target) orelse return;
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return) orelse return;
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const host = (affectedEditingHost(&edit) catch null) orelse return;
    if (!fireInputEvent(host, "beforeinput", command.inputType(), command.inputData(value))) return;
    if (!isConnected(host)) return;
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const affected = (affectedEditingHost(&edit) catch null) orelse return;
    const result = runAction(&edit, command, value) catch |err| {
        log.debug("{s} by key: {}", .{ @tagName(command), err });
        return;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEvent(affected, "input", command.inputType(), command.inputData(value));
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
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    return dom.fire_event.dispatchTrusted(target, event) catch true;
}

test "command names are ASCII case-insensitive" {
    try std.testing.expectEqual(Command.delete, Command.fromName("delete").?);
    try std.testing.expectEqual(Command.delete, Command.fromName("DELETE").?);
    try std.testing.expectEqual(Command.forward_delete, Command.fromName("forwardDelete").?);
    try std.testing.expectEqual(Command.forward_delete, Command.fromName("FORWARDDELETE").?);
    try std.testing.expectEqual(Command.insert_text, Command.fromName("INSERTTEXT").?);
    try std.testing.expect(Command.fromName("insertParagraphs") == null);
    try std.testing.expectEqualStrings("deleteContentBackward", Command.delete.inputType());
    try std.testing.expectEqualStrings("deleteContentForward", Command.forward_delete.inputType());
}
