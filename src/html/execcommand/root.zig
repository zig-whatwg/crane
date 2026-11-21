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
pub const select_all = @import("select_all.zig");
pub const clipboard = @import("clipboard.zig");
pub const clipboard_platform = @import("clipboard_platform.zig");
/// The undo and redo commands and each command's undo step (undo.zig).
pub const undo = @import("undo.zig");
/// Where a caret can be and how Selection.modify moves it (Blink's
/// VisiblePosition model, layout facts from the style system).
pub const visible_position = @import("visible_position.zig");

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
    // The miscellaneous commands this module answers (select_all.zig).
    select_all,
    // The clipboard commands: Clipboard API 8's actions (clipboard.zig).
    copy,
    cut,
    paste,
    // The history commands (undo.zig).
    undo,
    redo,

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
        .{ "selectAll", .select_all },
        .{ "copy", .copy },
        .{ "cut", .cut },
        .{ "paste", .paste },
        .{ "undo", .undo },
        .{ "redo", .redo },
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
            .insert_html, .insert_image, .select_all => "",
            // The clipboard actions fire their own (deleteByCut,
            // insertFromPaste: clipboard.zig).
            .copy, .cut, .paste => "",
            // Input Events 2's history input types (undo.zig fires them).
            .undo => "historyUndo",
            .redo => "historyRedo",
            .format_block, .indent, .outdent, .insert_ordered_list, .insert_unordered_list, .insert_paragraph, .insert_line_break, .insert_horizontal_rule, .justify_center, .justify_full, .justify_left, .justify_right => self.block().?.inputType(),
        };
    }

    /// Whether the command can be enabled in a plaintext-only editing host:
    /// false for every command whose section says "This command must not
    /// be enabled if the editing host is in the plaintext-only state".
    pub fn enabledInPlaintextOnly(self: Command) bool {
        return switch (self) {
            .delete, .forward_delete, .insert_text, .insert_html, .select_all, .copy, .cut, .paste, .undo, .redo => true,
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
            .delete, .forward_delete, .insert_text, .insert_html, .insert_image, .select_all, .copy, .cut, .paste, .undo, .redo => null,
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

    /// The commands Blink runs as TypingCommands - from a key and from
    /// execCommand alike (editor_command.cc ExecuteInsertText, ExecuteDelete,
    /// ExecuteForwardDelete, ExecuteInsertLineBreak,
    /// ExecuteInsertParagraph): their undo steps merge (undo.zig).
    fn isTyping(self: Command) bool {
        return switch (self) {
            .insert_text, .delete, .forward_delete, .insert_line_break, .insert_paragraph => true,
            else => false,
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
    // "Among commands defined in this specification, those listed in
    // Miscellaneous commands are always enabled, except for the cut command
    // and the paste command."
    if (command == .select_all or command == .copy) return true;
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
    // undo and redo: enabled while their list has a step (Blink
    // EnabledUndo / EnabledRedo: Editor::CanUndo / CanRedo).
    if (command == .undo) return undo.canUndo(document);
    if (command == .redo) return undo.canRedo(document);
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
        // Blink runs execCommand("delete") as the Backspace key's
        // TypingCommand::DeleteKeyPressed, which empties a root editable
        // element with one caret position before anything else (see
        // makeEditableRootEmpty).
        .delete => (try makeEditableRootEmpty(edit)) or try delete.deleteAction(edit),
        .forward_delete => try delete.forwardDeleteAction(edit),
        .back_color, .bold, .create_link, .font_name, .font_size, .fore_color, .hilite_color, .italic, .remove_format, .strikethrough, .subscript, .superscript, .underline, .unlink => try inline_formatting.action(edit, command.inlineCommand().?, value),
        .insert_text => try insert_text.action(edit, value, insertParagraphAction),
        .insert_html => try insert_content.insertHtml(edit, value),
        .insert_image => try insert_content.insertImage(edit, value),
        .format_block, .indent, .outdent, .insert_ordered_list, .insert_unordered_list, .insert_paragraph, .insert_line_break, .insert_horizontal_rule, .justify_center, .justify_full, .justify_left, .justify_right => try blocks.action(edit, command.block().?, value),
        .select_all => try select_all.action(edit),
        // Run by clipboard.zig before an Edit exists (execCommand below).
        .copy, .cut, .paste => false,
        // Run by undo.zig with no Edit (execCommand below).
        .undo, .redo => false,
    };
}

/// The action of `command`, recorded into an undo step (undo.zig): its own,
/// or - a typing command - the open typing step it merges into. `host` is
/// the affected editing host before it runs.
fn runRecorded(edit: *Edit, command: Command, value: []const u8, host: *Instance) !bool {
    const recording = undo.begin(edit, command.isTyping(), host);
    defer if (recording) |r| undo.end(edit, r, affectedEditingHost(edit) catch null);
    return try runAction(edit, command, value);
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
    // The clipboard commands: their Clipboard API actions with the
    // script-triggered flag set (Editing spec "Clipboard commands" steps
    // 1-5; clipboard-apis 5.3.3: "Execute the corresponding action
    // synchronously", its return value the call's).
    switch (command) {
        .copy => return clipboard.execCommand(document, .copy),
        .cut => return clipboard.execCommand(document, .cut),
        .paste => return clipboard.execCommand(document, .paste),
        // undo and redo: not enabled (nothing on their list) -> false;
        // else the step replayed, input at its editing hosts (undo.zig).
        .undo => return undo.undo(document, fireHistoryInput),
        .redo => return undo.redo(document, fireHistoryInput),
        else => {},
    }
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    // A focused text control takes insertText and insertHTML into its own
    // editor (user_input.execInsertIntoTextControl: Chrome and Safari);
    // insertHTML inserts the markup's plain text, as into a plaintext-only
    // host (Blink's inner editor is one).
    if (command == .insert_text or command == .insert_html) {
        const text = if (command == .insert_html)
            (insert_content.plainTextOf(document, value, arena.allocator()) catch return false)
        else
            value;
        if (@import("../user_input.zig").execInsertIntoTextControl(document, text, command.inputType())) |ran| return ran;
    }
    // And delete and forwardDelete delete in its editor.
    if (command == .delete or command == .forward_delete) {
        if (@import("../user_input.zig").execDeleteInTextControl(document, command == .forward_delete)) |ran| return ran;
    }
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    // selectAll changes no node: no editing host, no input event (steps
    // 5-8 alone).
    if (command == .select_all) return runAction(&edit, command, value) catch |err| {
        log.debug("selectAll: {}", .{err});
        return false;
    };
    // Step 3: not enabled -> false.
    if (!(isEnabledIn(&edit, command) catch false)) return false;
    // Step 4.5: the host the input event goes to, computed beforehand.
    const host = (affectedEditingHost(&edit) catch null) orelse return false;
    // Step 5: the action.
    const result = runRecorded(&edit, command, value, host) catch |err| {
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
    if (!fireInputEventWith(host, "beforeinput", command.inputType(), null, null, selectionTargetRange(&edit))) return;
    if (!isConnected(host)) return;
    // Step 4.4: a beforeinput listener may have moved or removed the
    // selection.
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const affected = (affectedEditingHost(&edit) catch null) orelse return;
    const result = runRecorded(&edit, command, "", affected) catch |err| {
        log.debug("{s} by key: {}", .{ @tagName(command), err });
        return;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEvent(affected, "input", command.inputType(), null);
}

/// Backspace with the caret at the only place a caret can be in its root
/// editable element (no previous and no next visible position) empties
/// the root: Blink's TypingCommand::DeleteKeyPressed "when there are no
/// visible positions in the editing root, delete its entire contents"
/// (MakeEditableRootEmpty: the caret goes to the root's start, its
/// children are removed, and a block root gets a placeholder br). A lone
/// br in a block root is left alone, and an empty list item is Blink's
/// BreakOutOfEmptyListItem case, tried before it (left to the delete
/// action here). editing/other/fire-selection-change-on-deleting-empty-
/// element.html: Chrome 157 and Firefox 160 pass (one selectionchange
/// after "<h1><br></h1>" goes), Safari 27.2 fires none. The Editing
/// spec's delete action does nothing at the root's start; the browsers do
/// this for the key and for execCommand("delete") alike - Blink's
/// ExecuteDelete is DeleteKeyPressed too, and all three give `<div><div>{}
/// <br></div></div>` + delete -> `<br>` (editing/run/delete.html, PPP at
/// wpt.fyi 2358bd4835). Golden rule 2. Whether it ran.
fn makeEditableRootEmpty(edit: *Edit) !bool {
    if (!try edit.rangeCollapsed()) return false;
    const caret = (try edit.rangeStart()) orelse return false;
    const vp = visible_position;
    const root = vp.soleCaretRoot(edit.scratchAllocator(), caret) orelse return false;
    const first = (try common.firstChild(root)) orelse return false;
    const block_flow = vp.isBlockFlow(edit.scratchAllocator(), root);
    if ((try common.lastChild(root)) == first and (try common.isHtmlElementNamed(first, "br")) and block_flow) return false;
    var ancestor: ?*Instance = caret.node;
    while (ancestor) |a| : (ancestor = try common.parent(a)) {
        if (a == root) break;
        if (try common.isHtmlElementIn(a, &.{ "li", "dt", "dd" })) return false;
    }
    try edit.collapse(root, 0);
    while (try common.firstChild(root)) |child| try edit.removeNode(child);
    if (block_flow) try edit.appendChild(root, try edit.createElement("br"));
    return true;
}

/// The word modifier with Backspace (`forward` false) or Delete in an
/// editing host: a collapsed selection is first extended by a word in the
/// key's direction - Selection.modify("extend", ..., "word"), the
/// SelectionModifier Blink's TypingCommand::DeleteKeyPressed /
/// ForwardDeleteKeyPressed run with TextGranularity::kWord - then the
/// delete command's action removes it, announced by beforeinput and input
/// with inputType deleteWordBackward / deleteWordForward (Input Events 2).
/// A cancelled beforeinput leaves the selection as it was (Blink computes
/// the range to delete without moving the selection).
pub fn deleteWordByKey(target: *Instance, forward: bool) void {
    const document = nodeDocument(target) orelse return;
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return) orelse return;
    const command: Command = if (forward) .forward_delete else .delete;
    const input_type = if (forward) "deleteWordForward" else "deleteWordBackward";
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const host = (affectedEditingHost(&edit) catch null) orelse return;
    const original = (edit.rangeStart() catch return) orelse return;
    const was_collapsed = edit.rangeCollapsed() catch return;
    if (was_collapsed) {
        interfaces.Selection.call_modify(edit.selection, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned("extend")), webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(if (forward) "forward" else "backward")), webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned("word"))) catch return;
        // No word in that direction: nothing to delete.
        if (edit.rangeCollapsed() catch true) return;
    }
    if (!fireInputEventWith(host, "beforeinput", input_type, null, null, selectionTargetRange(&edit))) {
        if (was_collapsed) edit.collapse(original.node, original.offset) catch {};
        return;
    }
    if (!isConnected(host)) return;
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const affected = (affectedEditingHost(&edit) catch null) orelse return;
    const result = runRecorded(&edit, command, "", affected) catch |err| {
        log.debug("{s} by key: {}", .{ input_type, err });
        return;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEvent(affected, "input", input_type, null);
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

/// The undo (`redo` false) or redo binding pressed in an editing host:
/// when there is a step to replay (the command is enabled - Blink's
/// EditorCommand::Execute asks before it dispatches anything), a cancelable
/// beforeinput with inputType historyUndo / historyRedo and no target ranges
/// (Input Events 2) at the focused editing host, then the command
/// (undo.zig), which fires its own input.
pub fn historyByKey(target: *Instance, redo: bool) void {
    const document = nodeDocument(target) orelse return;
    if (!(if (redo) undo.canRedo(document) else undo.canUndo(document))) return;
    const host = (common.editingHostOf(target) catch null) orelse return;
    if (!fireInputEvent(host, "beforeinput", if (redo) "historyRedo" else "historyUndo", null)) return;
    _ = if (redo) undo.redo(document, fireHistoryInput) else undo.undo(document, fireHistoryInput);
}

/// The user's Enter (insertParagraph) or Shift+Enter (insertLineBreak) in
/// an editing host ("Additional requirements"), by command name (their
/// actions are lane editing4's, blocks.zig).
pub fn lineBreakByKey(target: *Instance, name: []const u8) void {
    var command = Command.fromName(name) orelse return;
    // Enter in a plaintext-only editing host inserts a line break, not a
    // paragraph; execCommand("insertParagraph") there still makes one.
    // All three browsers (editing/plaintext-only/insertLineBreak.html
    // "Pressing Enter ...": Firefox 158 and Safari 27 63/63 at
    // white-space normal, Chrome 156 45/63; wpt.fyi 5af3c135c9). Gecko:
    // HTMLEditor::HandleKeyPressEvent's NS_VK_RETURN case runs
    // InsertLineBreakAsAction for Shift+Enter "or if we're in
    // plaintext-only mode ... because Chrome does so, but
    // execCommand("insertParagraph") keeps working as
    // contenteditable=true" (editor/libeditor/HTMLEditor.cpp, gecko-dev
    // 5836a062726f). No spec covers it: the Editing draft predates
    // plaintext-only.
    if (command == .insert_paragraph and enterMakesLineBreak(target)) command = .insert_line_break;
    commandByKey(target, command, "");
}

/// Whether Enter with the focus on `target` edits a plaintext-only host.
fn enterMakesLineBreak(target: *Instance) bool {
    const document = nodeDocument(target) orelse return false;
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    return activeHostIsPlaintextOnly(&edit) catch false;
}

/// The select-all shortcut (user_input.zig): the selectAll command's action.
/// It edits nothing, so no beforeinput or input (Input Events has no
/// inputType for it; Blink runs its "SelectAll" editor command directly).
/// A user action, so the Selection API's selectstart comes first: fired at
/// the new range's start node - the node whose children are selected -
/// when the selection was empty or collapsed, and a cancelled one leaves
/// the selection alone (specs/w3c/selection.md, "selectstart event";
/// Blink FrameSelection::SelectAll dispatches it at its select-start target
/// and returns when cancelled). selection/onselectstart-on-key-in-
/// contenteditable.html "Select All when 789[]<br></div>".
pub fn selectAllByKey(target: *Instance) void {
    const document = nodeDocument(target) orelse return;
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return) orelse return;
    const node = (select_all.target(&edit) catch return) orelse {
        _ = select_all.action(&edit) catch {};
        return;
    };
    if (edit.rangeCollapsed() catch true) {
        if (!fireSelectStart(node)) return;
        // A listener may have changed the selection or the tree: the
        // action decides again.
    }
    _ = select_all.action(&edit) catch |err| log.debug("selectAll by key: {}", .{err});
}

/// Fire a selectstart Event (bubbles, cancelable) at `target`; whether it
/// was not cancelled. Also the arrow keys' (user_input.zig).
pub fn fireSelectStart(target: *Instance) bool {
    const init: dictionaries.EventInit = .{ .bubbles = true, .cancelable = true };
    const event = interfaces.Event.call_constructor(target.ctx, runtime.DOMString.initInterned("selectstart"), webidl.Opt(dictionaries.EventInit).passed(init)) catch |err| {
        log.debug("selectstart not fired: {}", .{err});
        return true;
    };
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    return dom.fire_event.dispatchTrusted(target, event) catch true;
}

/// Whether `document`'s selection is somewhere the paste action can insert
/// and the cut action delete: its active range lies in one editing host
/// (the insertHTML command's "enabled"), clipboard-apis 8.2 step 3.1's and
/// 8.3 step 3.1's "a selection or cursor in an editable context".
pub fn hasEditableSelection(document: *Instance) bool {
    return isEnabled(document, .insert_html);
}

/// The paste action's step 3.1.1 in an editing host (Clipboard API 8.3):
/// "Insert the most suitable content found on the clipboard" - the
/// clipboard's text/html through the insertHTML action, or its text/plain
/// through the insertText action - announced as user input: a cancelable
/// beforeinput and then input, inputType insertFromPaste, data null and
/// dataTransfer holding what is pasted (Input Events 2). The browsers'
/// paste is their insertHTML machinery (Blink's ClipboardCommands::Paste
/// -> ReplaceSelectionCommand, as execCommand insertHTML; Gecko's
/// HTMLEditor::PasteAsAction -> InsertHTMLWithContextAsSubAction, as
/// InsertHTMLAsAction). `data_transfer` is a read-only DataTransfer the
/// caller made. Whether there was an editable selection to paste into.
pub fn insertFromPaste(document: *Instance, markup: ?[]const u8, text: ?[]const u8, data_transfer: ?*Instance) bool {
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    const command: Command = if (markup != null) .insert_html else .insert_text;
    const value = markup orelse text orelse "";
    if (!(isEnabledIn(&edit, command) catch false)) return false;
    const host = (affectedEditingHost(&edit) catch null) orelse return false;
    if (!fireInputEventWith(host, "beforeinput", "insertFromPaste", null, data_transfer, selectionTargetRange(&edit))) return true;
    if (!isConnected(host)) return true;
    // A beforeinput listener may have moved or removed the selection.
    if (!(isEnabledIn(&edit, command) catch false)) return true;
    const affected = (affectedEditingHost(&edit) catch null) orelse return true;
    // A paste is its own step (Blink's ReplaceSelectionCommand), not typing.
    const recording = undo.begin(&edit, false, affected);
    defer if (recording) |r| undo.end(&edit, r, affectedEditingHost(&edit) catch null);
    const result = runAction(&edit, command, value) catch |err| {
        log.debug("paste: {}", .{err});
        return true;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEventWith(affected, "input", "insertFromPaste", null, data_transfer, null);
    return true;
}

/// HTML 6.11.5 step 4's drop default action in an editing host: "Insert
/// the actual data of the first item in the drag data store item list to
/// have a drag data item type string of "text/plain" ... into the ...
/// editing host" - the insertText action at the selection the caller placed
/// (html/drag_and_drop.zig: the end of the host, the spec's "at the end of
/// the field"; where the pointer is would need layout), announced as user
/// input: a cancelable beforeinput and then input, inputType insertFromDrop,
/// data null and dataTransfer the drop's (Input Events 2). Blink's
/// DragController::ConcludeEditDrag replaces the selection the same way.
/// Whether there was an editable selection to drop into.
pub fn insertFromDrop(document: *Instance, text: []const u8, data_transfer: ?*Instance) bool {
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return false) orelse return false;
    if (!(isEnabledIn(&edit, .insert_text) catch false)) return false;
    const host = (affectedEditingHost(&edit) catch null) orelse return false;
    if (!fireInputEventWith(host, "beforeinput", "insertFromDrop", null, data_transfer, selectionTargetRange(&edit))) return true;
    if (!isConnected(host)) return true;
    // A beforeinput listener may have moved or removed the selection.
    if (!(isEnabledIn(&edit, .insert_text) catch false)) return true;
    const affected = (affectedEditingHost(&edit) catch null) orelse return true;
    const result = runAction(&edit, .insert_text, text) catch |err| {
        log.debug("drop: {}", .{err});
        return true;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEventWith(affected, "input", "insertFromDrop", null, data_transfer, null);
    return true;
}

/// The cut action's step 3.1.2 in an editing host (Clipboard API 8.2):
/// "Remove the contents of the selection from the document and collapse
/// the selection" - the delete command's action on the selection, as user
/// input: beforeinput and input with inputType deleteByCut (Input Events
/// 2; Blink's ClipboardCommands::ExecuteCut -> DeleteSelectionWithSmartDelete
/// with InputType::kDeleteByCut). Nothing for a collapsed selection.
pub fn deleteByCut(document: *Instance) void {
    var arena = std.heap.ArenaAllocator.init(document.ctx.allocator);
    defer arena.deinit();
    var edit = (beginEdit(document, arena.allocator()) catch return) orelse return;
    if (!(isEnabledIn(&edit, .delete) catch false)) return;
    if (edit.rangeCollapsed() catch true) return;
    const host = (affectedEditingHost(&edit) catch null) orelse return;
    if (!fireInputEventWith(host, "beforeinput", "deleteByCut", null, null, selectionTargetRange(&edit))) return;
    if (!isConnected(host)) return;
    if (!(isEnabledIn(&edit, .delete) catch false)) return;
    if (edit.rangeCollapsed() catch true) return;
    const affected = (affectedEditingHost(&edit) catch null) orelse return;
    // A cut is its own step (Blink's DeleteSelectionCommand), not typing.
    const recording = undo.begin(&edit, false, affected);
    defer if (recording) |r| undo.end(&edit, r, affectedEditingHost(&edit) catch null);
    const result = runAction(&edit, .delete, "") catch |err| {
        log.debug("cut: {}", .{err});
        return;
    };
    if (result and edit.modified and isConnected(affected)) _ = fireInputEvent(affected, "input", "deleteByCut", null);
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
    if (!fireInputEventWith(host, "beforeinput", command.inputType(), command.inputData(value), null, selectionTargetRange(&edit))) return;
    if (!isConnected(host)) return;
    if (!(isEnabledIn(&edit, command) catch false)) return;
    const affected = (affectedEditingHost(&edit) catch null) orelse return;
    const result = runRecorded(&edit, command, value, affected) catch |err| {
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

/// undo.zig's announcement after an undo or redo: input, inputType
/// historyUndo / historyRedo, at an editing host the step edited (Blink
/// UndoStep::Unapply / Reapply -> DispatchInputEventEditableContentChanged).
fn fireHistoryInput(target: *Instance, input_type: []const u8) void {
    _ = fireInputEvent(target, "input", input_type, null);
}

/// Fire a beforeinput or input InputEvent at `target` with `input_type`;
/// whether it was not cancelled. The event is freed unless a listener kept
/// it.
fn fireInputEvent(target: *Instance, comptime event_type: []const u8, input_type: []const u8, data: ?[]const u8) bool {
    return fireInputEventWith(target, event_type, input_type, data, null, null);
}

/// A beforeinput's target range (Input Events 2, "target ranges"): the
/// content the event will modify if it is not canceled.
const TargetRange = struct { start: common.Point, end: common.Point };

/// The target range of a key's beforeinput: a selection that is not
/// collapsed is the content its action replaces or deletes (Chrome and
/// Firefox: editing/other/delete-without-unwrapping-first-line-of-child-
/// block.html's getTargetRanges() rows for Backspace and typing over a
/// selection, wpt.fyi 2358bd4835). A collapsed one gets none: what a caret's
/// Backspace or Delete removes is the action's to compute (TODO: Blink's
/// TypingCommand target ranges for a caret).
fn selectionTargetRange(edit: *Edit) ?TargetRange {
    if (edit.rangeCollapsed() catch true) return null;
    const start = (edit.rangeStart() catch return null) orelse return null;
    const end = (edit.rangeEnd() catch return null) orelse return null;
    return .{ .start = start, .end = end };
}

/// fireInputEvent with a dataTransfer (Input Events 2: insertFromPaste,
/// insertFromDrop, insertReplacementText in an editing host) and a target
/// range (the event's target ranges, as a StaticRange).
fn fireInputEventWith(target: *Instance, comptime event_type: []const u8, input_type: []const u8, data: ?[]const u8, data_transfer: ?*Instance, target_range: ?TargetRange) bool {
    const cancelable = comptime std.mem.eql(u8, event_type, "beforeinput");
    // The StaticRange outlives the event's own release below: an event
    // never wrapped lets its traced edge go first (InputEvent.deinit).
    const static_range: ?*Instance = if (target_range) |r| interfaces.StaticRange.call_constructor(target.ctx, .{ .startContainer = r.start.node, .startOffset = r.start.offset, .endContainer = r.end.node, .endOffset = r.end.offset }) catch null else null;
    const range_generation: u64 = if (static_range) |r| runtime.SlabAllocator.generationOf(r) else 0;
    defer if (static_range) |r| r.releaseIfUnwrapped(range_generation);
    var ranges: [1]*Instance = undefined;
    if (static_range) |r| ranges[0] = r;
    const init: dictionaries.InputEventInit = .{
        .base = .{ .base = .{ .bubbles = true, .cancelable = cancelable, .composed = true }, .view = viewOf(target) },
        .data = if (data) |d| runtime.DOMString.initInterned(d) else null,
        .isComposing = false,
        .inputType = runtime.DOMString.initInterned(input_type),
        .dataTransfer = data_transfer,
        .targetRanges = if (static_range != null) ranges[0..1] else null,
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
