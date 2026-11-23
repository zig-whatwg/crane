//! The DOM agent's edits and their history (lane cdpd1, batch 3), translated
//! from Chromium's DOMEditor and InspectorHistory - upstream repository
//! https://chromium.googlesource.com/chromium/src, files
//! third_party/blink/renderer/core/inspector/dom_editor.cc (the actions:
//! RemoveChild, InsertBefore, RemoveAttribute, SetAttribute, SetOuterHTML,
//! ReplaceChildNode, SetNodeValue) and inspector_history.cc
//! (InspectorHistory, UndoableStateMark), revision tag 157.0.8103.78 (commit
//! 4b3d0dabb8250b6f152d2d85d79e7706e309d087).
//!     Copyright (C) 2012 Google Inc. All rights reserved. (both files)
//!     License: BSD-3-Clause, as each file's header states; the full text
//!     is THIRD_PARTY_NOTICES.md, text B.
//! Every edit is an action the history
//! performs and keeps, so DOM.undo and DOM.redo can take it back and do it
//! again; DOM.markUndoableState marks where an undo stops.
//!
//! An action changes the tree through the DOM's own algorithms - the IDL
//! operations Blink's actions call (insertBefore, removeChild, replaceChild,
//! setAttribute, removeAttribute, the nodeValue setter) - so mutation
//! observers, custom element reactions and the agent's own probes all run as
//! for any edit. An action HOLDS the nodes it names (dom.node_holds.RefHold,
//! Blink's Member<Node>): an undo can put back a node the page dropped. The
//! history lets every hold go when it is reset (a new document, getDocument,
//! the agent disabled or its session ended - Blink's DiscardFrontendBindings
//! and disable).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const RefHold = dom.node_holds.RefHold;

/// A DOM exception an action's DOM call threw: Blink's
/// InspectorDOMAgent::ToResponse message is the exception's name, a space,
/// and its message.
pub const Failure = struct {
    name: []const u8,
    message: []const u8 = "",
};

pub const Error = error{ DomException, OutOfMemory };

/// What the edits share: the allocator, and where a failure's text goes.
pub const Editor = struct {
    allocator: Allocator,
    history: *History,
    failure: Failure = .{ .name = "" },

    /// DOMEditor::InsertBefore.
    pub fn insertBefore(self: *Editor, parent: *runtime.Instance, node: *runtime.Instance, anchor: ?*runtime.Instance) Error!void {
        const action = try self.make(.{ .insert_before = .{} });
        action.kind.insert_before.parent.set(parent);
        action.kind.insert_before.node.set(node);
        if (anchor) |a| action.kind.insert_before.anchor.set(a);
        try self.history.perform(self, action);
    }

    /// DOMEditor::RemoveChild.
    pub fn removeChild(self: *Editor, parent: *runtime.Instance, node: *runtime.Instance) Error!void {
        const action = try self.make(.{ .remove_child = .{} });
        action.kind.remove_child.parent.set(parent);
        action.kind.remove_child.node.set(node);
        try self.history.perform(self, action);
    }

    /// DOMEditor::SetAttribute.
    pub fn setAttribute(self: *Editor, element: *runtime.Instance, name: []const u8, value: []const u8) Error!void {
        const action = try self.make(.{ .set_attribute = .{} });
        {
            errdefer action.destroy(self.allocator);
            action.kind.set_attribute.element.set(element);
            action.kind.set_attribute.name = try self.allocator.dupe(u8, name);
            action.kind.set_attribute.value = try self.allocator.dupe(u8, value);
        }
        try self.history.perform(self, action);
    }

    /// DOMEditor::RemoveAttribute.
    pub fn removeAttribute(self: *Editor, element: *runtime.Instance, name: []const u8) Error!void {
        const action = try self.make(.{ .remove_attribute = .{} });
        {
            errdefer action.destroy(self.allocator);
            action.kind.remove_attribute.element.set(element);
            action.kind.remove_attribute.name = try self.allocator.dupe(u8, name);
        }
        try self.history.perform(self, action);
    }

    /// DOMEditor::ReplaceChild.
    pub fn replaceChild(self: *Editor, parent: *runtime.Instance, new_node: *runtime.Instance, old_node: *runtime.Instance) Error!void {
        const action = try self.make(.{ .replace_child = .{} });
        action.kind.replace_child.parent.set(parent);
        action.kind.replace_child.new_node.set(new_node);
        action.kind.replace_child.old_node.set(old_node);
        try self.history.perform(self, action);
    }

    /// DOMEditor::SetNodeValue.
    pub fn setNodeValue(self: *Editor, node: *runtime.Instance, value: []const u8) Error!void {
        const action = try self.make(.{ .set_node_value = .{} });
        {
            errdefer action.destroy(self.allocator);
            action.kind.set_node_value.node.set(node);
            action.kind.set_node_value.value = try self.allocator.dupe(u8, value);
        }
        try self.history.perform(self, action);
    }

    /// DOMEditor::SetOuterHTML's action: the patch runs on a history of its
    /// own (dom_patch.zig), which this action's undo and redo replay whole.
    /// `patch` makes the change with the nested editor it is given and
    /// answers the node that took `node`'s place (null: none).
    pub fn setOuterHTML(self: *Editor, node: *runtime.Instance, context: anytype, comptime patch: fn (@TypeOf(context), *Editor, *runtime.Instance) Error!?*runtime.Instance) Error!?*runtime.Instance {
        const action = try self.make(.{ .set_outer_html = .{ .history = .{ .allocator = self.allocator } } });
        var nested: Editor = .{ .allocator = self.allocator, .history = &action.kind.set_outer_html.history };
        const new_node = patch(context, &nested, node) catch |err| {
            self.failure = nested.failure;
            action.destroy(self.allocator);
            return err;
        };
        // History::Perform's append (the action performed itself above).
        try self.history.append(action);
        return new_node;
    }

    fn make(self: *Editor, kind: Action.Kind) Allocator.Error!*Action {
        const action = try self.allocator.create(Action);
        action.* = .{ .kind = kind };
        return action;
    }

    /// Record the DOM exception `err` as Blink's ToResponse would word it.
    pub fn fail(self: *Editor, err: anyerror, operation: Operation) Error {
        self.failure = failureOf(err, operation);
        return error.DomException;
    }
};

/// The DOM call a failure came from (the message Blink's exception carries).
pub const Operation = enum { insert_before, remove_child, replace_child, set_attribute, remove_attribute, set_node_value };

fn failureOf(err: anyerror, operation: Operation) Failure {
    const name = @errorName(err);
    // Blink's messages for the common cases (container_node.cc,
    // element.cc); otherwise the name alone.
    const message: []const u8 = switch (err) {
        error.NotFoundError => switch (operation) {
            .remove_child => "The node to be removed is not a child of this node.",
            .replace_child => "The node to be replaced is not a child of this node.",
            .insert_before => "The node before which the new node is to be inserted is not a child of this node.",
            else => "",
        },
        error.InvalidCharacterError => "",
        else => "",
    };
    return .{ .name = name, .message = message };
}

/// One undoable edit (InspectorHistory::Action and DOMEditor's actions).
pub const Action = struct {
    kind: Kind,

    pub const Kind = union(enum) {
        remove_child: RemoveChild,
        insert_before: InsertBefore,
        remove_attribute: RemoveAttribute,
        set_attribute: SetAttribute,
        set_outer_html: SetOuterHTML,
        replace_child: ReplaceChild,
        set_node_value: SetNodeValue,
        /// UndoableStateMark: where an undo stops.
        mark,
    };

    pub const RemoveChild = struct {
        parent: RefHold = .{},
        node: RefHold = .{},
        anchor: RefHold = .{},
    };

    pub const InsertBefore = struct {
        parent: RefHold = .{},
        node: RefHold = .{},
        anchor: RefHold = .{},
        /// The removal from the node's old parent, when it had one.
        remove_child: ?*Action = null,
    };

    pub const RemoveAttribute = struct {
        element: RefHold = .{},
        name: []u8 = &.{},
        value: ?[]u8 = null,
    };

    pub const SetAttribute = struct {
        element: RefHold = .{},
        name: []u8 = &.{},
        value: []u8 = &.{},
        old_value: ?[]u8 = null,
    };

    pub const SetOuterHTML = struct {
        history: History,
    };

    pub const ReplaceChild = struct {
        parent: RefHold = .{},
        new_node: RefHold = .{},
        old_node: RefHold = .{},
    };

    pub const SetNodeValue = struct {
        node: RefHold = .{},
        value: []u8 = &.{},
        old_value: ?[]u8 = null,
    };

    /// Let go of every node held, and free what the action owns.
    pub fn destroy(self: *Action, allocator: Allocator) void {
        switch (self.kind) {
            .remove_child => |*a| {
                a.parent.release();
                a.node.release();
                a.anchor.release();
            },
            .insert_before => |*a| {
                a.parent.release();
                a.node.release();
                a.anchor.release();
                if (a.remove_child) |inner| inner.destroy(allocator);
            },
            .remove_attribute => |*a| {
                a.element.release();
                allocator.free(a.name);
                if (a.value) |v| allocator.free(v);
            },
            .set_attribute => |*a| {
                a.element.release();
                allocator.free(a.name);
                allocator.free(a.value);
                if (a.old_value) |v| allocator.free(v);
            },
            .set_outer_html => |*a| a.history.deinit(),
            .replace_child => |*a| {
                a.parent.release();
                a.new_node.release();
                a.old_node.release();
            },
            .set_node_value => |*a| {
                a.node.release();
                allocator.free(a.value);
                if (a.old_value) |v| allocator.free(v);
            },
            .mark => {},
        }
        allocator.destroy(self);
    }

    /// Action::Perform.
    fn perform(self: *Action, editor: *Editor) Error!void {
        switch (self.kind) {
            .remove_child => |*a| {
                // "anchor_node_ = node_->nextSibling(); return Redo()."
                const node = a.node.hold.get() orelse return editor.fail(error.NotFoundError, .remove_child);
                if (interfaces.Node.get_nextSibling(node) catch null) |next| a.anchor.set(next);
                try self.redo(editor);
            },
            .insert_before => |*a| {
                const node = a.node.hold.get() orelse return editor.fail(error.NotFoundError, .insert_before);
                // "if (node_->parentNode()) remove_child_action_ = ...Perform()".
                if (interfaces.Node.get_parentNode(node) catch null) |old_parent| {
                    const inner = try editor.make(.{ .remove_child = .{} });
                    inner.kind.remove_child.parent.set(old_parent);
                    inner.kind.remove_child.node.set(node);
                    inner.perform(editor) catch |err| {
                        inner.destroy(editor.allocator);
                        return err;
                    };
                    a.remove_child = inner;
                }
                try insertBefore(editor, a.parent.hold.get(), node, a.anchor.hold.get());
            },
            .remove_attribute => |*a| {
                // "value_ = element_->getAttribute(name_); return Redo()."
                const element = a.element.hold.get() orelse return;
                a.value = try getAttribute(editor.allocator, element, a.name);
                try self.redo(editor);
            },
            .set_attribute => |*a| {
                const element = a.element.hold.get() orelse return;
                a.old_value = try getAttribute(editor.allocator, element, a.name);
                try self.redo(editor);
            },
            .set_node_value => |*a| {
                const node = a.node.hold.get() orelse return;
                a.old_value = try nodeValue(editor.allocator, node);
                try self.redo(editor);
            },
            .replace_child => try self.redo(editor),
            .set_outer_html => {},
            .mark => {},
        }
    }

    /// Action::Undo.
    fn undo(self: *Action, editor: *Editor) Error!void {
        switch (self.kind) {
            .remove_child => |*a| try insertBefore(editor, a.parent.hold.get(), a.node.hold.get(), a.anchor.hold.get()),
            .insert_before => |*a| {
                try removeChild(editor, a.parent.hold.get(), a.node.hold.get());
                if (a.remove_child) |inner| try inner.undo(editor);
            },
            .remove_attribute => |*a| {
                const element = a.element.hold.get() orelse return;
                // Blink: setAttribute(name_, value_) - a null value_ (the
                // attribute was absent) sets it to "null"'s empty string.
                try setAttribute(editor, element, a.name, a.value orelse "");
            },
            .set_attribute => |*a| {
                const element = a.element.hold.get() orelse return;
                if (a.old_value) |old| try setAttribute(editor, element, a.name, old) else try removeAttribute(editor, element, a.name);
            },
            .set_outer_html => |*a| try a.history.undo(editor),
            .replace_child => |*a| try replaceChild(editor, a.parent.hold.get(), a.old_node.hold.get(), a.new_node.hold.get()),
            .set_node_value => |*a| {
                const node = a.node.hold.get() orelse return;
                try setNodeValue(editor, node, a.old_value);
            },
            .mark => {},
        }
    }

    /// Action::Redo.
    fn redo(self: *Action, editor: *Editor) Error!void {
        switch (self.kind) {
            .remove_child => |*a| try removeChild(editor, a.parent.hold.get(), a.node.hold.get()),
            .insert_before => |*a| {
                if (a.remove_child) |inner| try inner.redo(editor);
                try insertBefore(editor, a.parent.hold.get(), a.node.hold.get(), a.anchor.hold.get());
            },
            .remove_attribute => |*a| {
                const element = a.element.hold.get() orelse return;
                try removeAttribute(editor, element, a.name);
            },
            .set_attribute => |*a| {
                const element = a.element.hold.get() orelse return;
                try setAttribute(editor, element, a.name, a.value);
            },
            .set_outer_html => |*a| try a.history.redo(editor),
            .replace_child => |*a| try replaceChild(editor, a.parent.hold.get(), a.new_node.hold.get(), a.old_node.hold.get()),
            .set_node_value => |*a| {
                const node = a.node.hold.get() orelse return;
                try setNodeValue(editor, node, a.value);
            },
            .mark => {},
        }
    }
};

/// InspectorHistory: the performed actions, and how many of them are done.
pub const History = struct {
    allocator: Allocator,
    actions: std.ArrayListUnmanaged(*Action) = .empty,
    /// after_last_action_index_.
    after_last: usize = 0,

    pub fn deinit(self: *History) void {
        self.reset();
        self.actions.deinit(self.allocator);
    }

    /// InspectorHistory::Perform: the action performs itself, then is
    /// appended - dropping whatever was undone after the last done one.
    pub fn perform(self: *History, editor: *Editor, action: *Action) Error!void {
        action.perform(editor) catch |err| {
            action.destroy(self.allocator);
            return err;
        };
        try self.append(action);
    }

    /// AppendPerformedAction (no action merges: DOMEditor's have no MergeId).
    pub fn append(self: *History, action: *Action) Allocator.Error!void {
        for (self.actions.items[self.after_last..]) |undone| undone.destroy(self.allocator);
        self.actions.shrinkRetainingCapacity(self.after_last);
        self.actions.append(self.allocator, action) catch |err| {
            action.destroy(self.allocator);
            return err;
        };
        self.after_last += 1;
    }

    /// InspectorHistory::MarkUndoableState.
    pub fn markUndoableState(self: *History) Allocator.Error!void {
        const mark = try self.allocator.create(Action);
        mark.* = .{ .kind = .mark };
        try self.append(mark);
    }

    /// InspectorHistory::Undo: back past marks, then each action back to the
    /// previous mark (included). A failed undo resets the history.
    pub fn undo(self: *History, editor: *Editor) Error!void {
        while (self.after_last > 0 and self.actions.items[self.after_last - 1].kind == .mark) self.after_last -= 1;
        while (self.after_last > 0) {
            const action = self.actions.items[self.after_last - 1];
            action.undo(editor) catch |err| {
                self.reset();
                return err;
            };
            self.after_last -= 1;
            if (action.kind == .mark) break;
        }
    }

    /// InspectorHistory::Redo.
    pub fn redo(self: *History, editor: *Editor) Error!void {
        while (self.after_last < self.actions.items.len and self.actions.items[self.after_last].kind == .mark) self.after_last += 1;
        while (self.after_last < self.actions.items.len) {
            const action = self.actions.items[self.after_last];
            action.redo(editor) catch |err| {
                self.reset();
                return err;
            };
            self.after_last += 1;
            if (action.kind == .mark) break;
        }
    }

    /// InspectorHistory::Reset: every action - and every node it held - goes.
    pub fn reset(self: *History) void {
        for (self.actions.items) |action| action.destroy(self.allocator);
        self.actions.clearRetainingCapacity();
        self.after_last = 0;
    }
};

// ============================================================================
// The DOM calls (the IDL operations Blink's actions call)
// ============================================================================

fn insertBefore(editor: *Editor, parent: ?*runtime.Instance, node: ?*runtime.Instance, anchor: ?*runtime.Instance) Error!void {
    const p = parent orelse return editor.fail(error.NotFoundError, .insert_before);
    const n = node orelse return editor.fail(error.NotFoundError, .insert_before);
    _ = interfaces.Node.call_insertBefore(p, n, anchor) catch |err| return editor.fail(err, .insert_before);
}

fn removeChild(editor: *Editor, parent: ?*runtime.Instance, node: ?*runtime.Instance) Error!void {
    const p = parent orelse return editor.fail(error.NotFoundError, .remove_child);
    const n = node orelse return editor.fail(error.NotFoundError, .remove_child);
    _ = interfaces.Node.call_removeChild(p, n) catch |err| return editor.fail(err, .remove_child);
}

fn replaceChild(editor: *Editor, parent: ?*runtime.Instance, new_node: ?*runtime.Instance, old_node: ?*runtime.Instance) Error!void {
    const p = parent orelse return editor.fail(error.NotFoundError, .replace_child);
    const new = new_node orelse return editor.fail(error.NotFoundError, .replace_child);
    const old = old_node orelse return editor.fail(error.NotFoundError, .replace_child);
    _ = interfaces.Node.call_replaceChild(p, new, old) catch |err| return editor.fail(err, .replace_child);
}

fn setAttribute(editor: *Editor, element: *runtime.Instance, name: []const u8, value: []const u8) Error!void {
    var qualified = runtime.DOMString.initDupe(editor.allocator, name) catch return error.OutOfMemory;
    defer qualified.deinit(editor.allocator);
    var text = runtime.DOMString.initDupe(editor.allocator, value) catch return error.OutOfMemory;
    defer text.deinit(editor.allocator);
    interfaces.Element.call_setAttribute(element, qualified, .{ .domstring = text }) catch |err| return editor.fail(err, .set_attribute);
}

fn removeAttribute(editor: *Editor, element: *runtime.Instance, name: []const u8) Error!void {
    var qualified = runtime.DOMString.initDupe(editor.allocator, name) catch return error.OutOfMemory;
    defer qualified.deinit(editor.allocator);
    interfaces.Element.call_removeAttribute(element, qualified) catch |err| return editor.fail(err, .remove_attribute);
}

fn setNodeValue(editor: *Editor, node: *runtime.Instance, value: ?[]const u8) Error!void {
    var text: ?runtime.DOMString = if (value) |v| (runtime.DOMString.initDupe(editor.allocator, v) catch return error.OutOfMemory) else null;
    defer if (text) |*t| t.deinit(editor.allocator);
    interfaces.Node.set_nodeValue(node, text) catch |err| return editor.fail(err, .set_node_value);
}

/// Element.getAttribute(name), copied; null for none.
fn getAttribute(allocator: Allocator, element: *runtime.Instance, name: []const u8) Allocator.Error!?[]u8 {
    var qualified = runtime.DOMString.initDupe(allocator, name) catch return error.OutOfMemory;
    defer qualified.deinit(allocator);
    var value = (interfaces.Element.call_getAttribute(element, qualified) catch return null) orelse return null;
    defer value.deinit(element.ctx.allocator);
    return try allocator.dupe(u8, value.asSlice());
}

/// Node.nodeValue, copied; null for none.
fn nodeValue(allocator: Allocator, node: *runtime.Instance) Allocator.Error!?[]u8 {
    var value = (interfaces.Node.get_nodeValue(node) catch return null) orelse return null;
    defer value.deinit(node.ctx.allocator);
    return try allocator.dupe(u8, value.asSlice());
}
