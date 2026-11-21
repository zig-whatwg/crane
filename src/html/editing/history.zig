//! The editing undo history of a Document: its undo list and redo list of
//! undo steps, each the primitive DOM changes one editing command made.
//!
//! The Editing spec leaves the undo and redo commands to the abandoned
//! UndoManager draft (specs/w3c/execCommand.md, "The undo command"); the
//! browsers' model is the reference. Blink keeps an UndoStack per frame of
//! UndoSteps, each a list of SimpleEditCommands - InsertNodeBeforeCommand,
//! AppendNodeCommand, RemoveNodeCommand, SplitTextNodeCommand,
//! InsertIntoTextNodeCommand, DeleteFromTextNodeCommand,
//! SetNodeAttributeCommand - with the starting and ending selections
//! (third_party/blink/renderer/core/editing/commands/undo_stack.cc,
//! undo_step.cc, chromium main 2026-11); Gecko keeps a TransactionManager of
//! EditAggregateTransactions of the same primitives (editor/txmgr,
//! editor/libeditor). Undo works on the command's own primitives, not on a
//! diff of the tree: a node script moved after the command is still put back
//! where the command took it from (editing/other/undo-insertparagraph-after-
//! moving-split-nodes.html, all three browsers).
//!
//! This file owns the history's memory and its lifetime: the steps, the
//! strings they keep, and one counted hold (dom.node_holds.RefHold) on every
//! node they name - a node a step removed must outlive its removal for undo
//! to put it back. What it holds it names to the collector through the
//! Document's own `traceHeldNodes` (dom.editor_states.trace), as Blink's
//! UndoStep::Trace traces its commands' Member<Node>s, so a held node's
//! wrapper - and its expandos - live as long as the step. A destroyed
//! Document lets go of every hold (`clear`, dom.editor_states.releaseNodes:
//! refcount step 7b, as its top layer does), and its teardown frees the rest.
//!
//! The html module records into a step and replays it
//! (src/html/execcommand/undo.zig); html_core cannot reach the interfaces.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");

const RefHold = dom.node_holds.RefHold;
const Instance = runtime.Instance;
const Tracer = dom.editor_states.Tracer;

/// Blink's kMaximumUndoStackDepth (undo_stack.cc): the oldest step goes
/// when a new one would exceed it.
pub const maximum_depth = 1000;

/// A node insertion or removal: `node` went into (or came out of) `parent`
/// before `reference` (null: as its last child).
pub const ChildChange = struct {
    parent: RefHold = .{},
    node: RefHold = .{},
    reference: RefHold = .{},

    fn release(self: *ChildChange) void {
        self.parent.release();
        self.node.release();
        self.reference.release();
    }

    fn trace(self: *const ChildChange, tracer: *Tracer) void {
        self.parent.hold.trace(tracer);
        self.node.hold.trace(tracer);
        self.reference.hold.trace(tracer);
    }
};

/// Text inserted into, or deleted from, a CharacterData node at a UTF-16
/// offset. `data` is owned by the history's allocator.
pub const TextChange = struct {
    node: RefHold = .{},
    offset: u32 = 0,
    data: []u8 = &.{},
};

/// An attribute's value changed from `old` to `new` (null: absent). The
/// strings are owned by the history's allocator.
pub const AttributeChange = struct {
    element: RefHold = .{},
    name: []u8 = &.{},
    old: ?[]u8 = null,
    new: ?[]u8 = null,
};

/// One primitive DOM change of a step.
pub const Record = union(enum) {
    insert_node: ChildChange,
    remove_node: ChildChange,
    insert_text: TextChange,
    delete_text: TextChange,
    attribute: AttributeChange,

    fn release(self: *Record, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .insert_node, .remove_node => |*change| change.release(),
            .insert_text, .delete_text => |*change| {
                change.node.release();
                allocator.free(change.data);
            },
            .attribute => |*change| {
                change.element.release();
                allocator.free(change.name);
                if (change.old) |old| allocator.free(old);
                if (change.new) |new| allocator.free(new);
            },
        }
    }

    fn trace(self: *const Record, tracer: *Tracer) void {
        switch (self.*) {
            .insert_node, .remove_node => |*change| change.trace(tracer),
            .insert_text, .delete_text => |*change| change.node.hold.trace(tracer),
            .attribute => |*change| change.element.hold.trace(tracer),
        }
    }
};

/// A boundary point of a recorded selection.
pub const Point = struct {
    node: RefHold = .{},
    offset: u32 = 0,
};

/// A selection as a step records it: its anchor and focus, or none.
pub const Selection = struct {
    present: bool = false,
    anchor: Point = .{},
    focus: Point = .{},

    pub fn release(self: *Selection) void {
        self.anchor.node.release();
        self.focus.node.release();
        self.present = false;
    }

    fn trace(self: *const Selection, tracer: *Tracer) void {
        self.anchor.node.hold.trace(tracer);
        self.focus.node.hold.trace(tracer);
    }
};

/// One undo step: the primitive changes of one editing command (or of a
/// run of typing merged into it), in the order they were made, with the
/// selection before and after and the editing hosts the command edited
/// (Blink UndoStep's starting/ending selection and root editable elements).
pub const Step = struct {
    records: std.ArrayList(Record) = .empty,
    starting_selection: Selection = .{},
    ending_selection: Selection = .{},
    starting_root: RefHold = .{},
    ending_root: RefHold = .{},
    /// Made by a typing command (insertText, delete, forwardDelete,
    /// insertLineBreak, insertParagraph): later typing may merge into it
    /// while it is still open (UndoStack.open_typing).
    typing: bool = false,

    /// Let go of every hold and string; the step itself is the caller's.
    pub fn release(self: *Step, allocator: std.mem.Allocator) void {
        for (self.records.items) |*record| record.release(allocator);
        self.records.deinit(allocator);
        self.records = .empty;
        self.starting_selection.release();
        self.ending_selection.release();
        self.starting_root.release();
        self.ending_root.release();
    }

    fn trace(self: *const Step, tracer: *Tracer) void {
        for (self.records.items) |*record| record.trace(tracer);
        self.starting_selection.trace(tracer);
        self.ending_selection.trace(tracer);
        self.starting_root.hold.trace(tracer);
        self.ending_root.hold.trace(tracer);
    }
};

/// A Document's undo and redo lists (Blink UndoStack).
pub const UndoStack = struct {
    allocator: std.mem.Allocator,
    undo_steps: std.ArrayList(*Step) = .empty,
    redo_steps: std.ArrayList(*Step) = .empty,
    /// Set while a redo re-registers its step: the redo list is kept.
    in_redo: bool = false,
    /// The last undo step while typing may still merge into it (Blink
    /// TypingCommand's "still open for typing"): set by a typing step's
    /// registration, cleared by any other step, by undo and by redo.
    open_typing: ?*Step = null,
    /// The step the editing command running now records into, or null.
    recording: ?*Step = null,

    pub fn init(allocator: std.mem.Allocator) UndoStack {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *UndoStack) void {
        self.clear();
        self.undo_steps.deinit(self.allocator);
        self.redo_steps.deinit(self.allocator);
    }

    /// A new, empty step, owned by the caller until `registerUndoStep`
    /// takes it (or `destroyStep` frees it).
    pub fn createStep(self: *UndoStack) error{OutOfMemory}!*Step {
        const step = try self.allocator.create(Step);
        step.* = .{};
        return step;
    }

    pub fn destroyStep(self: *UndoStack, step: *Step) void {
        if (self.open_typing == step) self.open_typing = null;
        if (self.recording == step) self.recording = null;
        step.release(self.allocator);
        self.allocator.destroy(step);
    }

    /// Blink UndoStack::RegisterUndoStep: the step goes on the undo list,
    /// the oldest dropping off past the maximum depth, and - unless a redo
    /// is registering it - the redo list empties.
    pub fn registerUndoStep(self: *UndoStack, step: *Step) error{OutOfMemory}!void {
        try self.undo_steps.ensureUnusedCapacity(self.allocator, 1);
        if (self.undo_steps.items.len >= maximum_depth) {
            const oldest = self.undo_steps.orderedRemove(0);
            self.destroyStep(oldest);
        }
        if (!self.in_redo) self.clearRedo();
        self.undo_steps.appendAssumeCapacity(step);
        self.open_typing = if (step.typing and !self.in_redo) step else null;
    }

    /// Blink UndoStack::RegisterRedoStep.
    pub fn registerRedoStep(self: *UndoStack, step: *Step) error{OutOfMemory}!void {
        try self.redo_steps.append(self.allocator, step);
    }

    pub fn canUndo(self: *const UndoStack) bool {
        return self.undo_steps.items.len > 0;
    }

    pub fn canRedo(self: *const UndoStack) bool {
        return self.redo_steps.items.len > 0;
    }

    /// The last undo step, taken off the list (the caller registers it as
    /// a redo step after unapplying it, or destroys it).
    pub fn popUndo(self: *UndoStack) ?*Step {
        self.open_typing = null;
        return self.undo_steps.pop();
    }

    /// The last redo step, taken off the list.
    pub fn popRedo(self: *UndoStack) ?*Step {
        self.open_typing = null;
        return self.redo_steps.pop();
    }

    /// The step typing may merge into now, or null.
    pub fn openTypingStep(self: *const UndoStack) ?*Step {
        const open = self.open_typing orelse return null;
        const last = self.undo_steps.getLastOrNull() orelse return null;
        return if (last == open) open else null;
    }

    /// Typing stops merging (a selection change, another command).
    pub fn closeTyping(self: *UndoStack) void {
        self.open_typing = null;
    }

    fn clearRedo(self: *UndoStack) void {
        for (self.redo_steps.items) |step| self.destroyStep(step);
        self.redo_steps.clearRetainingCapacity();
    }

    /// Both lists empty, every hold let go (Blink UndoStack::Clear).
    pub fn clear(self: *UndoStack) void {
        for (self.undo_steps.items) |step| self.destroyStep(step);
        self.undo_steps.clearRetainingCapacity();
        self.clearRedo();
        self.open_typing = null;
    }

    /// The collector's atomic pause (the Document's `traceHeldNodes`):
    /// every held node's wrappers. Reads only.
    pub fn trace(self: *const UndoStack, tracer: *Tracer) void {
        for (self.undo_steps.items) |step| step.trace(tracer);
        for (self.redo_steps.items) |step| step.trace(tracer);
    }
};

test "the undo stack registers, pops and clears its steps" {
    var stack = UndoStack.init(std.testing.allocator);
    defer stack.deinit();
    try std.testing.expect(!stack.canUndo());
    const first = try stack.createStep();
    first.typing = true;
    try stack.registerUndoStep(first);
    try std.testing.expect(stack.canUndo());
    try std.testing.expectEqual(first, stack.openTypingStep().?);
    // A step with owned strings: the history frees them.
    const second = try stack.createStep();
    try second.records.append(std.testing.allocator, .{ .insert_text = .{ .offset = 3, .data = try std.testing.allocator.dupe(u8, "abc") } });
    try stack.registerUndoStep(second);
    try std.testing.expect(stack.openTypingStep() == null);
    const popped = stack.popUndo().?;
    try std.testing.expectEqual(second, popped);
    try stack.registerRedoStep(popped);
    try std.testing.expect(stack.canRedo());
    // A new step empties the redo list.
    try stack.registerUndoStep(try stack.createStep());
    try std.testing.expect(!stack.canRedo());
    // A redo keeps it.
    try stack.registerRedoStep(stack.popUndo().?);
    const third = try stack.createStep();
    try stack.registerRedoStep(third);
    stack.in_redo = true;
    try stack.registerUndoStep(stack.popRedo().?);
    stack.in_redo = false;
    try std.testing.expect(stack.canRedo());
}

test "the undo stack drops its oldest step past the maximum depth" {
    var stack = UndoStack.init(std.testing.allocator);
    defer stack.deinit();
    const oldest = try stack.createStep();
    try stack.registerUndoStep(oldest);
    var i: usize = 1;
    while (i < maximum_depth) : (i += 1) try stack.registerUndoStep(try stack.createStep());
    const second = stack.undo_steps.items[1];
    try std.testing.expectEqual(oldest, stack.undo_steps.items[0]);
    try stack.registerUndoStep(try stack.createStep());
    try std.testing.expectEqual(@as(usize, maximum_depth), stack.undo_steps.items.len);
    try std.testing.expectEqual(second, stack.undo_steps.items[0]);
}
