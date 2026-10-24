//! "Recording and restoring overrides" and the block formatting steps the
//! delete commands lean on (specs/w3c/execCommand.md): state and value
//! overrides, "record the values" / "restore the values", normalize
//! sublists, fix disallowed ancestors, block-extend and outdent.
//!
//! None of the machinery these need exists yet (golden rule 5: mock it,
//! never skip it): every formatting command's state and value is a stub
//! (src/html/editing/formatting.zig), so there is no effective command
//! value to record and no action to restore one with; the list and
//! indentation commands are stubs too. Each algorithm below is a named
//! no-op with its TODO and spec section, called from the step it belongs
//! to, so the delete algorithms read as the spec does and the batch that
//! builds the formatting commands fills them in.

const std = @import("std");
const common = @import("common.zig");

const Edit = common.Edit;
const Instance = common.Instance;

/// One recorded (command, state-or-value) pair.
pub const Override = struct {
    command: []const u8,
    value: union(enum) { state: bool, value: []const u8 },
};

/// "record current overrides" / "record current states and values": the
/// list restored after the action.
pub const Overrides = struct {
    items: []const Override = &.{},
};

/// "record current states and values" ("Recording and restoring
/// overrides", execCommand.md line 4434).
/// TODO(editing, formatting commands): read the first formattable node's
/// effective command values for createLink, bold, italic, strikethrough,
/// subscript, superscript, underline, fontName, foreColor, hiliteColor
/// and fontSize once those commands have states and values.
pub fn recordCurrentStatesAndValues(edit: *Edit) !Overrides {
    _ = edit;
    return .{};
}

/// "record current overrides" (line 4390).
/// TODO(editing, formatting commands): the Document's state and value
/// overrides, once the inline formatting commands set them.
pub fn recordCurrentOverrides(edit: *Edit) !Overrides {
    _ = edit;
    return .{};
}

/// "restore states and values" from `overrides` (line 4483).
/// TODO(editing, formatting commands): take each command's action where
/// queryCommandState/Value differ from the override, or set the
/// Document's overrides when nothing is formattable.
pub fn restoreStatesAndValues(edit: *Edit, overrides: Overrides) !void {
    _ = edit;
    _ = overrides;
}

/// "record the values" of a node list ("Assorted block formatting command
/// algorithms"): each node's effective command values for the inline
/// formatting commands, to be restored after it moves.
pub const Values = struct {
    items: []const Override = &.{},
};

/// TODO(editing, formatting commands): record each node's effective
/// command value for every inline formatting command.
pub fn recordTheValues(edit: *Edit, nodes: []const *Instance) !Values {
    _ = edit;
    _ = nodes;
    return .{};
}

/// TODO(editing, formatting commands): "force the value" of each recorded
/// node back to what was recorded.
pub fn restoreTheValues(edit: *Edit, values: Values) !void {
    _ = edit;
    _ = values;
}

/// "normalize sublists" in `item` (line 3988).
/// TODO(editing, list commands): split an li around its ol/ul children.
pub fn normalizeSublists(edit: *Edit, item: *Instance) !void {
    _ = edit;
    _ = item;
}

/// "fix disallowed ancestors" of `node` (line 3882).
/// TODO(editing, block commands): split the parent until node is an
/// allowed child of its ancestors, converting stray list items and cells
/// to the default single-line container.
pub fn fixDisallowedAncestors(edit: *Edit, node: *Instance) !void {
    _ = edit;
    _ = node;
}

/// The delete command's step 10: at the start of an indentation element,
/// block-extend the caret's range and "outdent" each of its nodes
/// ("Indenting and outdenting", line 5697).
/// TODO(editing, indent/outdent): the outdent algorithm; until it exists
/// the caret stays and nothing changes.
pub fn outdentAtIndentationElement(edit: *Edit, node: *Instance) !void {
    _ = edit;
    _ = node;
}

test "the mocks record nothing" {
    const overrides: Overrides = .{};
    try std.testing.expectEqual(@as(usize, 0), overrides.items.len);
    const values: Values = .{};
    try std.testing.expectEqual(@as(usize, 0), values.items.len);
}
