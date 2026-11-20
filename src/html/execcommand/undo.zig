//! The undo and redo commands: recording each editing command's primitive
//! DOM changes into an undo step, and replaying the steps.
//!
//! The Editing spec defines neither command ("Action: As defined by the
//! UndoManager specification", specs/w3c/execCommand.md "The undo command" -
//! a draft no browser ships), so the browsers decide (golden rule 2). Blink
//! and Gecko both undo a command's own primitives, not a diff of the tree:
//!
//! - Blink: an UndoStep per command holds SimpleEditCommands
//!   (InsertNodeBeforeCommand / AppendNodeCommand, RemoveNodeCommand,
//!   SplitTextNodeCommand, InsertIntoTextNodeCommand,
//!   DeleteFromTextNodeCommand, SetNodeAttributeCommand) with the starting
//!   and ending selections; UndoStep::Unapply runs each command's DoUnapply
//!   in reverse and restores the starting selection, Reapply runs DoReapply
//!   in order and restores the ending one, and each primitive checks its own
//!   preconditions - a node whose parent is gone or no longer editable is
//!   left alone (third_party/blink/renderer/core/editing/commands/
//!   undo_step.cc, remove_node_command.cc, insert_node_before_command.cc,
//!   append_node_command.cc, insert_into_text_node_command.cc,
//!   delete_from_text_node_command.cc, set_node_attribute_command.cc;
//!   chromium main 2026-11, BSD-3 - reproduced, not copied).
//! - Gecko: an EditAggregateTransaction per action of CreateElement /
//!   DeleteNode / InsertText / DeleteText / ChangeAttribute transactions
//!   (editor/libeditor, the same model).
//!
//! WPT pins the primitive model: undoing insertParagraph after script moved
//! one of the split blocks still joins the text back into the left block
//! (editing/other/undo-insertparagraph-after-moving-split-nodes.html), and
//! redoing insertLineBreak after script appended a child appends the line
//! breaks after it (editing/run/undo-redo-after-mutation.html) - Chrome 157,
//! Firefox 160 and Safari 27.2 pass both (wpt.fyi 2358bd4835). A mutation by
//! script outside editing leaves the history alone, as in all three.
//!
//! Recording: every DOM change an editing command makes goes through one of
//! common.Edit's primitives (or the attribute and style writers that find
//! the recording step through the node's document), and each primitive
//! appends its record to the command's step (`Edit.step`). The step - its
//! memory and its node holds - is html_core's (editing/history.zig).
//!
//! The typing commands (insertText, delete, forwardDelete, insertLineBreak,
//! insertParagraph, from a key or from script) merge into the last step while
//! it is still open for typing, as Blink's TypingCommand does
//! (TypingCommand::InsertText, DeleteKeyPressed, ... -
//! LastTypingCommandIfStillOpenForTyping): open until any other command, an
//! undo or redo, or a selection change since the step ended.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html_core = @import("html_core");
const common = @import("common.zig");

const history = html_core.editing.history;
const EditorState = html_core.editing.state.EditorState;
const Instance = runtime.Instance;
const DOMString = runtime.DOMString;
const Edit = common.Edit;

/// `document`'s undo history, made with its editor state on first use.
fn stackOf(document: *Instance, allocator: std.mem.Allocator) !*history.UndoStack {
    const state = try html_core.editing.executor.editorStateOf(allocator, @ptrCast(document));
    return &state.undo_stack;
}

/// `document`'s undo history if its editor state exists.
fn existingStackOf(document: *Instance) ?*history.UndoStack {
    const pointer = dom.document_internals.editorState(@ptrCast(@alignCast(document))) orelse return null;
    const state: *EditorState = @ptrCast(@alignCast(pointer));
    return &state.undo_stack;
}

// ============================================================================
// Recording
// ============================================================================

/// The step a mutation of `node` records into: its document's recording
/// step while an editing command runs, else null. For the writers that
/// have no Edit (common.setAttribute, the style writers).
pub fn recordingStepOf(node: *Instance) ?*history.Step {
    const document = if (common.isDocument(node)) node else (interfaces.Node.get_ownerDocument(node) catch return null) orelse return null;
    const stack = existingStackOf(document) orelse return null;
    return stack.recording;
}

/// A child list change: `node` went into (`.insert`) or came out of
/// (`.remove`) `parent`, before `reference`.
pub fn recordChild(allocator: std.mem.Allocator, step: *history.Step, comptime kind: enum { insert, remove }, parent: *Instance, node: *Instance, reference: ?*Instance) !void {
    var change: history.ChildChange = .{};
    change.parent.set(parent);
    change.node.set(node);
    change.reference.set(reference);
    errdefer {
        change.parent.release();
        change.node.release();
        change.reference.release();
    }
    try step.records.append(allocator, switch (kind) {
        .insert => .{ .insert_node = change },
        .remove => .{ .remove_node = change },
    });
}

/// Text `data` went into (`.insert`) or came out of (`.delete`) `node` at the
/// UTF-16 offset `offset`.
pub fn recordText(allocator: std.mem.Allocator, step: *history.Step, comptime kind: enum { insert, delete }, node: *Instance, offset: u32, data: []const u8) !void {
    if (data.len == 0) return;
    var change: history.TextChange = .{ .offset = offset };
    change.data = try allocator.dupe(u8, data);
    errdefer allocator.free(change.data);
    change.node.set(node);
    errdefer change.node.release();
    try step.records.append(allocator, switch (kind) {
        .insert => .{ .insert_text = change },
        .delete => .{ .delete_text = change },
    });
}

/// `element`'s attribute `name` changed from `old` to `new` (null: absent).
pub fn recordAttribute(allocator: std.mem.Allocator, step: *history.Step, element: *Instance, name: []const u8, old: ?[]const u8, new: ?[]const u8) !void {
    if (old == null and new == null) return;
    if (old != null and new != null and std.mem.eql(u8, old.?, new.?)) return;
    var change: history.AttributeChange = .{};
    change.name = try allocator.dupe(u8, name);
    errdefer allocator.free(change.name);
    change.old = if (old) |o| try allocator.dupe(u8, o) else null;
    errdefer if (change.old) |o| allocator.free(o);
    change.new = if (new) |n| try allocator.dupe(u8, n) else null;
    errdefer if (change.new) |n| allocator.free(n);
    change.element.set(element);
    errdefer change.element.release();
    try step.records.append(allocator, .{ .attribute = change });
}

/// `element`'s attribute `name` now, owned by `allocator`, or null.
pub fn attributeValue(allocator: std.mem.Allocator, element: *Instance, name: []const u8) !?[]u8 {
    var value = (try interfaces.Element.call_getAttribute(element, DOMString.initInterned(name))) orelse return null;
    defer value.deinit(element.ctx.allocator);
    return try allocator.dupe(u8, value.asSlice());
}

/// Around a write to `element`'s attribute `name` that has no Edit (the
/// attribute and style writers): `begin` reads its value before, `end`
/// records the change into the recording step, if any.
pub const AttributeWrite = struct {
    step: ?*history.Step = null,
    allocator: std.mem.Allocator,
    element: *Instance,
    name: []const u8,
    old: ?[]u8 = null,

    pub fn begin(element: *Instance, name: []const u8) !AttributeWrite {
        const allocator = element.ctx.allocator;
        var write: AttributeWrite = .{ .allocator = allocator, .element = element, .name = name };
        write.step = recordingStepOf(element);
        if (write.step != null) write.old = try attributeValue(allocator, element, name);
        return write;
    }

    pub fn end(self: *AttributeWrite) !void {
        defer if (self.old) |old| self.allocator.free(old);
        const step = self.step orelse return;
        const new = try attributeValue(self.allocator, self.element, self.name);
        defer if (new) |n| self.allocator.free(n);
        try recordAttribute(self.allocator, step, self.element, self.name, self.old, new);
    }

    /// The write failed: nothing to record.
    pub fn abandon(self: *AttributeWrite) void {
        if (self.old) |old| self.allocator.free(old);
        self.old = null;
    }
};

/// A selection as a step keeps it.
fn snapshotSelection(selection: *Instance, out: *history.Selection) void {
    out.release();
    const anchor = (interfaces.Selection.get_anchorNode(selection) catch null) orelse return;
    const focus = (interfaces.Selection.get_focusNode(selection) catch null) orelse return;
    out.anchor.node.set(anchor);
    out.anchor.offset = interfaces.Selection.get_anchorOffset(selection) catch 0;
    out.focus.node.set(focus);
    out.focus.offset = interfaces.Selection.get_focusOffset(selection) catch 0;
    out.present = true;
}

/// Whether `selection` is where `recorded` says.
fn selectionIs(selection: *Instance, recorded: *const history.Selection) bool {
    const anchor = interfaces.Selection.get_anchorNode(selection) catch return false;
    if (!recorded.present) return anchor == null;
    if (anchor == null or anchor.? != recorded.anchor.node.hold.get()) return false;
    const focus = (interfaces.Selection.get_focusNode(selection) catch return false) orelse return false;
    if (focus != recorded.focus.node.hold.get()) return false;
    return (interfaces.Selection.get_anchorOffset(selection) catch return false) == recorded.anchor.offset and
        (interfaces.Selection.get_focusOffset(selection) catch return false) == recorded.focus.offset;
}

/// The commands Blink runs as TypingCommands, whose steps merge.
pub fn isTyping(name: []const u8) bool {
    for ([_][]const u8{ "insertText", "delete", "forwardDelete", "insertLineBreak", "insertParagraph" }) |typing| {
        if (std.mem.eql(u8, name, typing)) return true;
    }
    return false;
}

/// One command's recording: the step its primitives append to.
pub const Recording = struct {
    stack: *history.UndoStack,
    step: *history.Step,
    /// The step is the open typing step this command merges into.
    merged: bool,
};

/// Start recording the command `edit` runs (`typing`: a typing command),
/// whose affected editing host is `host`. Null when nothing can record
/// (out of memory: the command still runs, unrecorded).
pub fn begin(edit: *Edit, typing: bool, host: *Instance) ?Recording {
    const stack = stackOf(edit.document, edit.allocator) catch return null;
    // A command inside another's recording (insertText's insertParagraph)
    // records into the same step.
    if (stack.recording != null) return null;
    if (typing) {
        if (stack.openTypingStep()) |open| {
            if (selectionIs(edit.selection, &open.ending_selection)) {
                stack.recording = open;
                edit.step = open;
                return .{ .stack = stack, .step = open, .merged = true };
            }
        }
    }
    stack.closeTyping();
    const step = stack.createStep() catch return null;
    step.typing = typing;
    snapshotSelection(edit.selection, &step.starting_selection);
    step.starting_root.set(host);
    stack.recording = step;
    edit.step = step;
    return .{ .stack = stack, .step = step, .merged = false };
}

/// The command ended: a step that changed something goes on the undo list
/// (Blink Editor::AppliedEditing -> UndoStack::RegisterUndoStep), one that
/// changed nothing is dropped. `host` is the affected editing host now.
pub fn end(edit: *Edit, recording: Recording, host: ?*Instance) void {
    recording.stack.recording = null;
    edit.step = null;
    const step = recording.step;
    if (recording.merged) {
        snapshotSelection(edit.selection, &step.ending_selection);
        return;
    }
    if (step.records.items.len == 0) {
        recording.stack.destroyStep(step);
        return;
    }
    snapshotSelection(edit.selection, &step.ending_selection);
    step.ending_root.set(host orelse step.starting_root.hold.get());
    recording.stack.registerUndoStep(step) catch {
        recording.stack.destroyStep(step);
        return;
    };
}

// ============================================================================
// Replaying
// ============================================================================

/// Blink's IsEditable for a primitive's precondition: the node is editable
/// content or an editing host.
fn isEditable(node: *Instance) bool {
    return common.isEditableOrEditingHost(node) catch false;
}

fn isConnected(node: *Instance) bool {
    return interfaces.Node.get_isConnected(node) catch false;
}

/// The node a hold held, null when it held none; error when the node it
/// held is gone (freed under it - a teardown net).
fn heldOrNull(hold: *const dom.node_holds.RefHold) error{Gone}!?*Instance {
    if (hold.hold.node == null) return null;
    return hold.hold.get() orelse error.Gone;
}

fn removeFromParent(node: *Instance) void {
    const parent = (common.parent(node) catch return) orelse return;
    _ = interfaces.Node.call_removeChild(parent, node) catch {};
}

fn setAttributeTo(element: *Instance, name: []const u8, value: ?[]const u8) void {
    if (value) |v| {
        common.setAttribute(element, name, v) catch {};
    } else {
        common.removeAttribute(element, name) catch {};
    }
}

/// Undo one primitive (its DoUnapply).
fn unapplyRecord(record: *const history.Record) void {
    switch (record.*) {
        .insert_node => |*change| {
            // InsertNodeBeforeCommand::DoUnapply: the reference's parent must
            // be editable; AppendNodeCommand::DoUnapply: the parent must be.
            const node = (heldOrNull(&change.node) catch return) orelse return;
            const reference = heldOrNull(&change.reference) catch return;
            const parent = if (reference) |r| (common.parent(r) catch return) orelse return else (heldOrNull(&change.parent) catch return) orelse return;
            if (!isEditable(parent)) return;
            removeFromParent(node);
        },
        .remove_node => |*change| {
            // RemoveNodeCommand::DoUnapply: back into its parent before its
            // old next sibling, if the parent is editable; a reference that is
            // no longer the parent's child fails the insertion (ignored).
            const parent = (heldOrNull(&change.parent) catch return) orelse return;
            if (!isEditable(parent)) return;
            const node = (heldOrNull(&change.node) catch return) orelse return;
            const reference = heldOrNull(&change.reference) catch return;
            _ = interfaces.Node.call_insertBefore(parent, node, reference) catch {};
        },
        .insert_text => |*change| {
            // InsertIntoTextNodeCommand::DoUnapply.
            const node = (heldOrNull(&change.node) catch return) orelse return;
            if (!isEditable(node)) return;
            interfaces.CharacterData.call_deleteData(node, change.offset, common.utf16Length(change.data)) catch {};
        },
        .delete_text => |*change| {
            // DeleteFromTextNodeCommand::DoUnapply.
            const node = (heldOrNull(&change.node) catch return) orelse return;
            if (!isEditable(node)) return;
            interfaces.CharacterData.call_insertData(node, change.offset, DOMString.initInterned(change.data)) catch {};
        },
        .attribute => |*change| {
            // SetNodeAttributeCommand::DoUnapply (no editability check).
            const element = (heldOrNull(&change.element) catch return) orelse return;
            setAttributeTo(element, change.name, change.old);
        },
    }
}

/// Redo one primitive (its DoReapply, which is its DoApply).
fn reapplyRecord(record: *const history.Record) void {
    switch (record.*) {
        .insert_node => |*change| {
            const node = (heldOrNull(&change.node) catch return) orelse return;
            const reference = heldOrNull(&change.reference) catch return;
            if (reference) |r| {
                // InsertNodeBeforeCommand::DoApply: into the reference's
                // parent, if it has one and it is editable.
                const parent = (common.parent(r) catch return) orelse return;
                if (!isEditable(parent)) return;
                _ = interfaces.Node.call_insertBefore(parent, node, r) catch {};
                return;
            }
            // AppendNodeCommand::DoApply: not into a parent in the document
            // that is not editable.
            const parent = (heldOrNull(&change.parent) catch return) orelse return;
            if (!isEditable(parent) and isConnected(parent)) return;
            _ = interfaces.Node.call_appendChild(parent, node) catch {};
        },
        .remove_node => |*change| {
            // RemoveNodeCommand::DoApply: from its parent now, unless that is
            // a parent in the document that is not editable.
            const node = (heldOrNull(&change.node) catch return) orelse return;
            const parent = (common.parent(node) catch return) orelse return;
            if (!isEditable(parent) and isConnected(parent)) return;
            _ = interfaces.Node.call_removeChild(parent, node) catch {};
        },
        .insert_text => |*change| {
            const node = (heldOrNull(&change.node) catch return) orelse return;
            if (!isEditable(node)) return;
            interfaces.CharacterData.call_insertData(node, change.offset, DOMString.initInterned(change.data)) catch {};
        },
        .delete_text => |*change| {
            const node = (heldOrNull(&change.node) catch return) orelse return;
            if (!isEditable(node)) return;
            interfaces.CharacterData.call_deleteData(node, change.offset, common.utf16Length(change.data)) catch {};
        },
        .attribute => |*change| {
            const element = (heldOrNull(&change.element) catch return) orelse return;
            setAttributeTo(element, change.name, change.new);
        },
    }
}

/// Blink UndoStep's CorrectedSelectionAfterCommand + ChangeSelectionAfterCommand:
/// the recorded selection where its nodes are still in the document (and
/// the offsets still fit), else no selection.
fn restoreSelection(document: *Instance, recorded: *const history.Selection) void {
    const selection = (interfaces.Document.call_getSelection(document) catch return) orelse return;
    if (recorded.present) {
        const anchor = recorded.anchor.node.hold.get();
        const focus = recorded.focus.node.hold.get();
        if (anchor != null and focus != null and isConnected(anchor.?) and isConnected(focus.?) and
            (common.nodeLength(anchor.?) catch 0) >= recorded.anchor.offset and (common.nodeLength(focus.?) catch 0) >= recorded.focus.offset)
        {
            interfaces.Selection.call_setBaseAndExtent(selection, anchor.?, recorded.anchor.offset, focus.?, recorded.focus.offset) catch {};
            return;
        }
    }
    interfaces.Selection.call_removeAllRanges(selection) catch {};
}

/// The editing hosts a replayed step announces itself at.
const Roots = struct {
    starting: dom.node_holds.RefHold = .{},
    ending: dom.node_holds.RefHold = .{},

    fn of(step: *const history.Step) Roots {
        var roots: Roots = .{};
        roots.starting.set(step.starting_root.hold.get());
        roots.ending.set(step.ending_root.hold.get());
        return roots;
    }

    fn release(self: *Roots) void {
        self.starting.release();
        self.ending.release();
    }
};

/// Whether `document` has a step to undo (the undo command's enabled).
pub fn canUndo(document: *Instance) bool {
    const stack = existingStackOf(document) orelse return false;
    return stack.canUndo() and stack.recording == null;
}

/// Whether `document` has a step to redo (the redo command's enabled).
pub fn canRedo(document: *Instance) bool {
    const stack = existingStackOf(document) orelse return false;
    return stack.canRedo() and stack.recording == null;
}

pub const Fire = *const fn (target: *Instance, input_type: []const u8) void;

/// The undo command's action (Blink UndoStack::Undo -> UndoStep::Unapply):
/// the last step's primitives undone in reverse, the starting selection
/// restored, the step moved to the redo list, then input (inputType
/// historyUndo) at the editing hosts it edited. Whether there was a step.
pub fn undo(document: *Instance, fire: Fire) bool {
    const stack = existingStackOf(document) orelse return false;
    if (stack.recording != null) return false;
    const step = stack.popUndo() orelse return false;
    var index = step.records.items.len;
    while (index > 0) {
        index -= 1;
        unapplyRecord(&step.records.items[index]);
    }
    restoreSelection(document, &step.starting_selection);
    var roots = Roots.of(step);
    defer roots.release();
    stack.registerRedoStep(step) catch stack.destroyStep(step);
    announce(&roots, "historyUndo", fire);
    return true;
}

/// The redo command's action (Blink UndoStack::Redo -> UndoStep::Reapply):
/// the last undone step's primitives redone in order, the ending selection
/// restored, the step back on the undo list (the redo list kept), then input
/// (inputType historyRedo). Whether there was a step.
pub fn redo(document: *Instance, fire: Fire) bool {
    const stack = existingStackOf(document) orelse return false;
    if (stack.recording != null) return false;
    const step = stack.popRedo() orelse return false;
    for (step.records.items) |*record| reapplyRecord(record);
    restoreSelection(document, &step.ending_selection);
    var roots = Roots.of(step);
    defer roots.release();
    stack.in_redo = true;
    stack.registerUndoStep(step) catch stack.destroyStep(step);
    stack.in_redo = false;
    announce(&roots, "historyRedo", fire);
    return true;
}

/// Blink DispatchInputEventEditableContentChanged(starting root, ending
/// root, ...): input at the starting root, and at the ending root when it
/// is another.
fn announce(roots: *const Roots, input_type: []const u8, fire: Fire) void {
    const starting = roots.starting.hold.get();
    const ending = roots.ending.hold.get();
    if (starting) |root| fire(root, input_type);
    if (ending) |root| if (root != starting) fire(root, input_type);
}
