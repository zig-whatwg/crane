//! The state DOM 4.2.2 gives slots and slottables, and the hook the slot
//! algorithms (shadow_dom_algorithms.zig) reach it through.
//!
//! A slottable (an Element or a Text node) has an assigned slot and a manual
//! slot assignment; a slot (an HTML `slot` element) has a name, its assigned
//! nodes and its manually assigned nodes. That state lives in the owning
//! impls' InternalState - Element and Text embed a `SlottableState`,
//! HTMLSlotElement a `SlotState` - and each owner installs a function here,
//! once, at process start, that hands the algorithms a pointer to it. The
//! algorithms never name an impl.
//!
//! Every pointer between nodes here is a `NodeRef`: the node, its owning
//! Instance and that Instance's slab generation when the reference was taken.
//! None of them keeps its target alive, and none is read once its target is
//! gone. The algorithms keep them true eagerly - a slottable's assigned slot
//! is cleared when it stops being assigned, a slot's assigned nodes are
//! recomputed when a node leaves its host (DOM remove step 8) or the slot
//! leaves its tree (remove step 10) - so a reference whose target was freed
//! is one that a teardown, not a DOM operation, ended: the generation check
//! makes it read as absent instead of as the next object at that address.
//! Blink keeps the same edges as traced Members (SlotAssignment,
//! HTMLSlotElement::assigned_nodes_, FlatTreeNodeData::assigned_slot_);
//! WebKit holds WeakPtrs (NamedSlotAssignment::Slot::assignedNodes,
//! HTMLSlotElement::m_manuallyAssignedNodes). The HTML standard notes that
//! the manually assigned nodes and the manual slot assignment "can be
//! implemented using weak references".
//!
//! lint-impls: hook for Element, Text, HTMLSlotElement

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NodeBase = @import("node_base.zig").NodeBase;

pub const ELEMENT_NODE: u16 = NodeBase.ELEMENT_NODE;
pub const TEXT_NODE: u16 = NodeBase.TEXT_NODE;
pub const DOCUMENT_FRAGMENT_NODE: u16 = NodeBase.DOCUMENT_FRAGMENT_NODE;

/// A reference to a node that does not keep it alive and reads as null once
/// its Instance is freed (or its slab slot reissued).
pub const NodeRef = struct {
    node: *NodeBase,
    instance: *runtime.Instance,
    generation: u64,

    /// A reference to `node`; null for a node no Instance owns.
    pub fn to(node: *NodeBase) ?NodeRef {
        const opaque_instance = node.owner_instance orelse return null;
        const instance: *runtime.Instance = @ptrCast(@alignCast(opaque_instance));
        return .{ .node = node, .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// The node, if it is still the one this reference was taken on.
    pub fn get(self: NodeRef) ?*NodeBase {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.node;
    }

    /// Whether this reference names `node`, which the caller knows is live.
    pub fn is(self: NodeRef, node: *NodeBase) bool {
        return self.node == node and self.get() != null;
    }

    pub fn eql(a: NodeRef, b: NodeRef) bool {
        return a.instance == b.instance and a.generation == b.generation;
    }
};

/// DOM 4.2.2.2: a slottable's assigned slot (null or a slot) and its manual
/// slot assignment (null or a slot).
pub const SlottableState = struct {
    assigned_slot: ?NodeRef = null,
    manual_slot_assignment: ?NodeRef = null,

    /// The assigned slot, if it is still alive.
    pub fn assignedSlot(self: *const SlottableState) ?*NodeBase {
        const ref = self.assigned_slot orelse return null;
        return ref.get();
    }

    /// The manual slot assignment, if it is still alive.
    pub fn manualSlotAssignment(self: *const SlottableState) ?*NodeBase {
        const ref = self.manual_slot_assignment orelse return null;
        return ref.get();
    }
};

/// DOM 4.2.2.1 and HTML 4.12.4: a slot's name, its assigned nodes and its
/// manually assigned nodes (an ordered set, set by `assign()`).
pub const SlotState = struct {
    /// What the name and both lists are allocated from.
    allocator: std.mem.Allocator,
    /// Owned when non-empty.
    name: []const u8 = "",
    assigned_nodes: std.ArrayListUnmanaged(NodeRef) = .empty,
    manually_assigned_nodes: std.ArrayListUnmanaged(NodeRef) = .empty,

    pub fn init(allocator: std.mem.Allocator) SlotState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SlotState) void {
        if (self.name.len > 0) self.allocator.free(self.name);
        self.name = "";
        self.assigned_nodes.deinit(self.allocator);
        self.manually_assigned_nodes.deinit(self.allocator);
    }

    /// Set the slot's name to a copy of `value`. On failure the name is
    /// left as it was.
    pub fn setName(self: *SlotState, value: []const u8) !void {
        const copy: []const u8 = if (value.len == 0) "" else try self.allocator.dupe(u8, value);
        if (self.name.len > 0) self.allocator.free(self.name);
        self.name = copy;
    }

    /// Replace the assigned nodes with `nodes`, reusing the list's memory.
    pub fn setAssignedNodes(self: *SlotState, nodes: []const NodeRef) !void {
        try self.assigned_nodes.ensureTotalCapacity(self.allocator, nodes.len);
        self.assigned_nodes.clearRetainingCapacity();
        self.assigned_nodes.appendSliceAssumeCapacity(nodes);
    }

    /// Whether the assigned nodes are empty, counting only live entries.
    pub fn hasAssignedNodes(self: *const SlotState) bool {
        for (self.assigned_nodes.items) |ref| {
            if (ref.get() != null) return true;
        }
        return false;
    }
};

/// A slottable's state and its name (DOM 4.2.2.2: an Element's is its `slot`
/// attribute's value; a Text node's is always the empty string).
pub const Slottable = struct {
    state: *SlottableState,
    name: []const u8,
};

/// What the owners supply. Each reads only the instance it is given.
pub const Implementation = struct {
    /// Element: its slottable state and its `slot` attribute value, null for
    /// an instance that is not an Element.
    element_slottable: ?*const fn (element: *runtime.Instance) ?Slottable = null,
    /// Text: its slottable state, null for an instance that is not a Text node.
    text_slottable: ?*const fn (text: *runtime.Instance) ?*SlottableState = null,
    /// HTMLSlotElement: its slot state, null for any other instance.
    slot_state: ?*const fn (slot: *runtime.Instance) ?*SlotState = null,
};

/// Process-wide, written once at start-up (process_start.zig).
// process-wide: function pointers Element, Text and HTMLSlotElement install once at process start (crane.Process); they read only the instance they are given, so every Browser and thread shares them
var implementation: ?Implementation = null;

/// Called by the owners' installHooks, once each, at process start
/// (process_start.zig). Each installs only its own members.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    var combined = implementation orelse Implementation{};
    if (impl.element_slottable) |f| combined.element_slottable = f;
    if (impl.text_slottable) |f| combined.text_slottable = f;
    if (impl.slot_state) |f| combined.slot_state = f;
    implementation = combined;
}

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    const opaque_instance = node.owner_instance orelse return null;
    return @ptrCast(@alignCast(opaque_instance));
}

/// Whether `node` is an Element.
pub fn isElement(node: *const NodeBase) bool {
    return node.node_type == ELEMENT_NODE;
}

/// DOM 4.2.2.2: "Element and Text nodes are slottables."
///
/// A CDATASection is a Text node too, but Crane's CDATASection has no Text
/// state to keep an assigned slot in; it occurs only in XML documents. TODO:
/// give CDATASection the slottable state when its impl chains through Text.
pub fn isSlottable(node: *const NodeBase) bool {
    return node.node_type == ELEMENT_NODE or node.node_type == TEXT_NODE;
}

/// DOM 4.2.2.1: whether `node` is a slot. "A slot can only be created
/// through HTML's slot element": an HTMLSlotElement, told by its vtable, so
/// the check reads no state.
pub fn isSlot(node: *NodeBase) bool {
    if (node.node_type != ELEMENT_NODE) return false;
    const instance = instanceOf(node) orelse return false;
    return instance.vtable == &interfaces.HTMLSlotElement.vtable;
}

/// `node`'s slottable state and name, or null when it is not a slottable.
pub fn slottable(node: *NodeBase) ?Slottable {
    const instance = instanceOf(node) orelse return null;
    switch (node.node_type) {
        ELEMENT_NODE => {
            const impl = implementation orelse return null;
            const f = impl.element_slottable orelse return null;
            return f(instance);
        },
        TEXT_NODE => {
            const impl = implementation orelse return null;
            const f = impl.text_slottable orelse return null;
            const state = f(instance) orelse return null;
            return .{ .state = state, .name = "" };
        },
        else => return null,
    }
}

/// `node`'s slot state, or null when it is not a slot.
pub fn slotState(node: *NodeBase) ?*SlotState {
    if (!isSlot(node)) return null;
    const impl = implementation orelse return null;
    const f = impl.slot_state orelse return null;
    const instance = instanceOf(node) orelse return null;
    return f(instance);
}

test "NodeRef equality compares instance and generation" {
    var a: NodeBase = undefined;
    var instance: runtime.Instance = undefined;
    const r1 = NodeRef{ .node = &a, .instance = &instance, .generation = 1 };
    const r2 = NodeRef{ .node = &a, .instance = &instance, .generation = 2 };
    try std.testing.expect(r1.eql(r1));
    try std.testing.expect(!r1.eql(r2));
}

test "slot state names are copied and freed" {
    var state = SlotState.init(std.testing.allocator);
    defer state.deinit();
    try state.setName("a");
    try state.setName("bb");
    try std.testing.expectEqualStrings("bb", state.name);
    try state.setName("");
    try std.testing.expectEqualStrings("", state.name);
}
