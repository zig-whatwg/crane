//! The block formatting commands' dispatcher (lane editing4): the
//! commands' names, input types and plaintext-only rule, their actions
//! under "preserves overrides", and their states, values and
//! indeterminacies (specs/w3c/execCommand.md, "Block formatting commands").
//! root.zig gives this family one arm per verb.

const std = @import("std");
const common = @import("common.zig");
const overrides = @import("overrides.zig");
const block = @import("block.zig");
const paragraph = @import("paragraph.zig");
const indent = @import("indent.zig");
const lists = @import("lists.zig");
const alignment = @import("alignment.zig");

const Edit = common.Edit;

pub const Command = enum {
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

    /// "map an edit command to input type value"; formatBlock has no row
    /// in the table, so "".
    pub fn inputType(self: Command) []const u8 {
        return switch (self) {
            .format_block => "",
            .indent => "formatIndent",
            .outdent => "formatOutdent",
            .insert_ordered_list => "insertOrderedList",
            .insert_unordered_list => "insertUnorderedList",
            .insert_paragraph => "insertParagraph",
            .insert_line_break => "insertLineBreak",
            .insert_horizontal_rule => "insertHorizontalRule",
            .justify_center => "formatJustifyCenter",
            .justify_full => "formatJustifyFull",
            .justify_left => "formatJustifyLeft",
            .justify_right => "formatJustifyRight",
        };
    }

    /// False for a command that "must not be enabled if the editing host is
    /// in the plaintext-only state": indent, insertHorizontalRule, both
    /// list commands, the justify commands and outdent by the spec's text,
    /// and formatBlock by the browsers (its section lacks the sentence, but
    /// editing/plaintext-only/styling-commands.html's formatBlock "should
    /// be disabled" subtests pass in Chrome 156, Firefox 158 and Safari 27,
    /// wpt.fyi 5af3c135c9). insertParagraph and insertLineBreak edit
    /// plaintext-only hosts.
    pub fn enabledInPlaintextOnly(self: Command) bool {
        return switch (self) {
            .insert_paragraph, .insert_line_break => true,
            else => false,
        };
    }
};

/// The command named by `name` (already matched ASCII case-insensitively
/// by the caller's table), as rows for root.zig's fromName table.
pub const names = [_]struct { []const u8, Command }{
    .{ "formatblock", .format_block },
    .{ "indent", .indent },
    .{ "outdent", .outdent },
    .{ "insertorderedlist", .insert_ordered_list },
    .{ "insertunorderedlist", .insert_unordered_list },
    .{ "insertparagraph", .insert_paragraph },
    .{ "insertlinebreak", .insert_line_break },
    .{ "inserthorizontalrule", .insert_horizontal_rule },
    .{ "justifycenter", .justify_center },
    .{ "justifyfull", .justify_full },
    .{ "justifyleft", .justify_left },
    .{ "justifyright", .justify_right },
};

/// The command's action, given its value `argument`. Every block command "preserves
/// overrides" ("Block formatting command definitions"): record the current
/// overrides first, and after the action restore the states and values
/// when the active range is collapsed.
pub fn action(edit: *Edit, command: Command, argument: []const u8) !bool {
    const recorded = try overrides.recordCurrentOverrides(edit);
    const result = switch (command) {
        .format_block => try block.formatBlockAction(edit, argument),
        .indent => try indent.indentAction(edit),
        .outdent => try indent.outdentAction(edit),
        .insert_ordered_list => try lists.toggleListsAction(edit, "ol"),
        .insert_unordered_list => try lists.toggleListsAction(edit, "ul"),
        .insert_paragraph => try paragraph.insertParagraphAction(edit),
        .insert_line_break => try paragraph.insertLineBreakAction(edit),
        .insert_horizontal_rule => try paragraph.insertHorizontalRuleAction(edit),
        .justify_center => try alignment.justifyTheSelection(edit, .center),
        .justify_full => try alignment.justifyTheSelection(edit, .justify),
        .justify_left => try alignment.justifyTheSelection(edit, .left),
        .justify_right => try alignment.justifyTheSelection(edit, .right),
    };
    if (try edit.rangeCollapsed()) try overrides.restoreStatesAndValues(edit, recorded);
    return result;
}

/// The command's state; null when it has none.
pub fn state(edit: *Edit, command: Command) !?bool {
    return switch (command) {
        .insert_ordered_list => (try lists.selectionListState(edit)) == .ol,
        .insert_unordered_list => (try lists.selectionListState(edit)) == .ul,
        .justify_center => try alignment.justifyState(edit, .center),
        .justify_full => try alignment.justifyState(edit, .justify),
        .justify_left => try alignment.justifyState(edit, .left),
        .justify_right => try alignment.justifyState(edit, .right),
        else => null,
    };
}

/// The command's indeterminacy; null when it has none.
pub fn indeterm(edit: *Edit, command: Command) !?bool {
    return switch (command) {
        .format_block => try block.formatBlockIndeterm(edit),
        .insert_ordered_list => switch (try lists.selectionListState(edit)) {
            .mixed, .mixed_ol => true,
            else => false,
        },
        .insert_unordered_list => switch (try lists.selectionListState(edit)) {
            .mixed, .mixed_ul => true,
            else => false,
        },
        .justify_center => try alignment.justifyIndeterm(edit, .center),
        .justify_full => try alignment.justifyIndeterm(edit, .justify),
        .justify_left => try alignment.justifyIndeterm(edit, .left),
        .justify_right => try alignment.justifyIndeterm(edit, .right),
        else => null,
    };
}

/// The command's value (a static string); null when it has none.
pub fn value(edit: *Edit, command: Command) !?[]const u8 {
    return switch (command) {
        .format_block => try block.formatBlockValue(edit),
        .justify_center, .justify_full, .justify_left, .justify_right => try alignment.justifyValue(edit),
        else => null,
    };
}

test "block commands' input types and plaintext-only rule" {
    try std.testing.expectEqualStrings("formatIndent", Command.indent.inputType());
    try std.testing.expectEqualStrings("", Command.format_block.inputType());
    try std.testing.expect(Command.insert_paragraph.enabledInPlaintextOnly());
    try std.testing.expect(!Command.indent.enabledInPlaintextOnly());
}
