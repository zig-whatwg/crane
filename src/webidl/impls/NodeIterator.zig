//! Implementation for NodeIterator interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nodeiterator
//! WHATWG DOM Standard §6.2
//!
//! NodeIterator objects can be used to filter and traverse node trees.
//! They maintain a reference pointer that moves through the tree as you
//! call nextNode() and previousNode().
//!
//! Migrated from: webidl/src/dom/NodeIterator.zig

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NodeIterator = interfaces.NodeIterator;

const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

// Import DOM module for tree navigation via NodeBase
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.tree_helpers.NodeBase;
const document_internals = dom_module.document_internals;
const node_filter = @import("node_filter.zig");
const traversal = dom_module.traversal;

pub const State = NodeIterator.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
    /// The filter threw, and its exception has been rethrown (filter step 8).
    ExceptionPending,
};

/// NodeFilter constants per DOM spec
/// https://dom.spec.whatwg.org/#interface-nodefilter
pub const NodeFilter = struct {
    // Filter return values
    pub const FILTER_ACCEPT: u16 = 1;
    pub const FILTER_REJECT: u16 = 2;
    pub const FILTER_SKIP: u16 = 3;

    // whatToShow bitmask constants
    pub const SHOW_ALL: u32 = 0xFFFFFFFF;
    pub const SHOW_ELEMENT: u32 = 0x1;
    pub const SHOW_ATTRIBUTE: u32 = 0x2;
    pub const SHOW_TEXT: u32 = 0x4;
    pub const SHOW_CDATA_SECTION: u32 = 0x8;
    pub const SHOW_ENTITY_REFERENCE: u32 = 0x10; // Historical
    pub const SHOW_ENTITY: u32 = 0x20; // Historical
    pub const SHOW_PROCESSING_INSTRUCTION: u32 = 0x40;
    pub const SHOW_COMMENT: u32 = 0x80;
    pub const SHOW_DOCUMENT: u32 = 0x100;
    pub const SHOW_DOCUMENT_TYPE: u32 = 0x200;
    pub const SHOW_DOCUMENT_FRAGMENT: u32 = 0x400;
    pub const SHOW_NOTATION: u32 = 0x800; // Historical

    /// Check if a node type is shown according to whatToShow bitmask
    /// node_type_minus_one is (nodeType - 1) to get the bit position
    pub fn isNodeTypeShown(what_to_show: u32, node_type_minus_one: u8) bool {
        const bit: u32 = @as(u32, 1) << @intCast(node_type_minus_one);
        return (what_to_show & bit) != 0;
    }
};

/// Direction for traverse algorithm
pub const Direction = enum { next, previous };

/// Internal state for NodeIterator
/// Spec: https://dom.spec.whatwg.org/#concept-nodeiterator-state
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The root node of the iterator (never changes)
    root: ?*runtime.Instance,

    /// The reference node (current position in iteration)
    reference: ?*runtime.Instance,

    /// Whether the pointer is before the reference node
    pointer_before_reference: bool,
    candidate: ?*runtime.Instance = null,
    pointer_before_candidate: bool = false,
    traced_candidate: ?*runtime.Instance = null,

    /// Bitmask indicating which node types to show
    what_to_show: u32,

    /// Optional filter callback
    /// Stored as opaque to support WebIDL callback interface
    filter: ?*anyopaque,

    /// Active flag to prevent recursive invocations
    active_flag: bool,

    /// The document whose iterator list holds this iterator, and its slab
    /// generation when it joined. The list is walked by every node removal
    /// (the NodeIterator pre-removing steps), so a freed iterator must leave
    /// it - but only if that document is still the object at that address.
    document: ?*runtime.Instance = null,
    document_generation: u64 = 0,

    /// Whether the root edge was drawn, and the reference node the reference
    /// edge holds (null while the reference is the root, which the root's
    /// edge keeps): see `keepRoot` and `setReference`.
    root_traced: bool = false,
    traced_reference: ?*runtime.Instance = null,

    /// One counted reference each on the root, the reference and the
    /// candidate (refcount step 5f): WebKit's NodeIteratorBase holds `const
    /// Ref<Node> m_root` (Source/WebCore/dom/Traversal.h) and NodeIterator's
    /// two NodePointers `RefPtr<Node> node` (dom/NodeIterator.h). Set with
    /// the edges, in setUp, `setReference` and `setCandidate`. SHADOW MODE:
    /// the edges keep the nodes until refcount step 9b.
    root_hold: dom_module.node_holds.RefHold = .{},
    reference_hold: dom_module.node_holds.RefHold = .{},
    candidate_hold: dom_module.node_holds.RefHold = .{},

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .root = null,
            .reference = null,
            .pointer_before_reference = true,
            .what_to_show = NodeFilter.SHOW_ALL,
            .filter = null,
            .active_flag = false,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // No cleanup needed - we don't own the nodes
        _ = self;
    }
};

/// Helper to access internal state from instance
/// Get internal state from instance using shared accessor (pointer cast variant)
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) *InternalState {
    return Accessor.getCast(instance);
}

/// The members an iterator keeps its nodes in (engine.traceChild): its root,
/// and its reference while that is another node. An iterator script holds
/// keeps them - and through them their tree and document - for as long as it
/// lives. Blink: NodeIteratorBase::Trace visits root_, NodeIterator::Trace
/// visits reference_ (core/dom/node_iterator.cc). They were bare pointers,
/// and `root` read a freed node once its tree was collected (lane ownerdoc,
/// crane/od-node-iterator-keeps-its-nodes.html).
///
/// Reference and candidate are separate node pointers. The pre-removing
/// steps adjust both, and leave both untouched when an inclusive ancestor
/// of root is removed. A temporary Owned root keeps the original filtered
/// node across script even when the candidate is adjusted to another node.
///
/// An iterator is made only by createNodeIterator(), which the binding wraps
/// as it returns: until then traceChild holds the nodes strongly for the
/// wrapper it waits for, and `deinit` lets that hold go if the iterator is
/// freed unwrapped (an error inside createNodeIterator).
const root_slot: engine.TracedSlot = .{ .name = "root" };
const reference_slot: engine.TracedSlot = .{ .name = "reference" };
const candidate_slot: engine.TracedSlot = .{ .name = "candidate" };

/// Set `instance`'s reference to `node`, keeping it (`reference_slot`) when it
/// is not the root.
fn setReference(instance: *runtime.Instance, internal: *InternalState, node: ?*runtime.Instance) void {
    internal.reference = node;
    internal.reference_hold.set(node);
    const kept: ?*runtime.Instance = if (node == internal.root) null else node;
    if (kept == internal.traced_reference) return;
    internal.traced_reference = kept;
    if (kept) |n| engine.traceChild(instance, n, reference_slot) else engine.forgetTracedChild(instance, reference_slot);
}

/// The in-flight node pointer has the same traced ownership as reference.
/// Removals may move it while a filter runs; clear it on every traverse exit.
fn setCandidate(instance: *runtime.Instance, internal: *InternalState, node: ?*runtime.Instance) void {
    internal.candidate = node;
    internal.candidate_hold.set(node);
    const kept: ?*runtime.Instance = if (node == internal.root) null else node;
    if (kept == internal.traced_candidate) return;
    internal.traced_candidate = kept;
    if (kept) |n| engine.traceChild(instance, n, candidate_slot) else engine.forgetTracedChild(instance, candidate_slot);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Document sets a new iterator up through dom.traversal.
    traversal.installNodeIterator(.{ .set_up = &setUp, .pre_remove = &preRemoveSteps });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        if (internal.document) |doc| {
            if (internal.document_generation != 0 and
                runtime.SlabAllocator.generationOf(doc) == internal.document_generation)
            {
                document_internals.unregisterNodeIterator(doc, instance);
            }
        }
        // An iterator its wrapper's collection frees has no edges left to
        // end; one freed unwrapped lets go of what waits for its wrapper.
        if (internal.root_traced) engine.forgetTracedChild(instance, root_slot);
        if (internal.traced_reference != null) engine.forgetTracedChild(instance, reference_slot);
        if (internal.traced_candidate != null) engine.forgetTracedChild(instance, candidate_slot);
        internal.root_hold.release();
        internal.reference_hold.release();
        internal.candidate_hold.release();
        node_filter.release(internal.filter);
        internal.filter = null;
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// `dom.traversal`'s NodeIterator set-up: createNodeIterator() steps 2-5, and
/// the document whose iterator list this iterator is joining.
fn setUp(
    instance: *runtime.Instance,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*runtime.CallbackWrapper,
    document: *runtime.Instance,
) anyerror!void {
    const internal = getInternal(instance);
    // Step 2: Set iterator's root and iterator's reference to root.
    internal.root = root;
    internal.root_hold.set(root);
    setReference(instance, internal, root);
    engine.traceChild(instance, root, root_slot);
    internal.root_traced = true;
    // Step 3: Set iterator's pointer before reference to true.
    internal.pointer_before_reference = true;
    // Step 4: Set iterator's whatToShow to whatToShow.
    internal.what_to_show = what_to_show;
    // Step 5: Set iterator's filter to filter.
    node_filter.release(internal.filter);
    internal.filter = null;
    internal.filter = try node_filter.store(internal.allocator, filter);
    internal.active_flag = false;
    // Recorded so the iterator can leave the document's list when freed.
    internal.document = document;
    internal.document_generation = runtime.SlabAllocator.generationOf(document);
}

// ============================================================================
// Getters
// ============================================================================

/// DOM §6.2 - NodeIterator.root
/// Returns the root node
pub fn get_root(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.root orelse return error.InvalidStateError;
}

/// DOM §6.2 - NodeIterator.referenceNode
/// Returns the current reference node
pub fn get_referenceNode(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.reference orelse return error.InvalidStateError;
}

/// DOM §6.2 - NodeIterator.pointerBeforeReferenceNode
/// Returns true if pointer is before the reference node
pub fn get_pointerBeforeReferenceNode(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance);
    return internal.pointer_before_reference;
}

/// DOM §6.2 - NodeIterator.whatToShow
/// Returns the whatToShow bitmask
pub fn get_whatToShow(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance);
    return internal.what_to_show;
}

/// DOM §6.2 - NodeIterator.filter
/// The filter: the object createNodeIterator() was given, or null for none.
pub fn get_filter(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const internal = getInternal(instance);
    return node_filter.fromStored(instance.ctx, internal.filter);
}

// ============================================================================
// Navigation methods
// ============================================================================

/// DOM §6.2 - NodeIterator.nextNode()
/// Returns the next node in the iteration, or null if none
/// Spec: https://dom.spec.whatwg.org/#dom-nodeiterator-nextnode
pub fn call_nextNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // Returns the result of traversing: a node, or null when the iterator
    // has run off the end of its root.
    return try traverse(instance, .next);
}

/// DOM §6.2 - NodeIterator.previousNode()
/// Returns the previous node in the iteration, or null if none
/// Spec: https://dom.spec.whatwg.org/#dom-nodeiterator-previousnode
pub fn call_previousNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    // Returns the result of traversing: a node, or null when the iterator
    // has run off the end of its root.
    return try traverse(instance, .previous);
}

/// DOM §6.2 - NodeIterator.detach()
/// Legacy method - does nothing (functionality removed, kept for compatibility)
/// Spec: https://dom.spec.whatwg.org/#dom-nodeiterator-detach
pub fn call_detach(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    // Do nothing per spec - method is a no-op for compatibility
}

// ============================================================================
// Internal algorithms
// ============================================================================

/// DOM §6.2 - traverse algorithm
/// Given a direction, traverse the tree and return the next accepted node
/// Spec: https://dom.spec.whatwg.org/#nodeiterator-traverse
fn traverse(instance: *runtime.Instance, direction: Direction) ImplError!?*runtime.Instance {
    const internal = getInternal(instance);

    // A nested traversal must throw without overwriting the outer candidate.
    // Gecko NodeIterator::NextOrPrevNode checks the active filter first too.
    if (internal.active_flag) return error.InvalidStateError;

    // Rule 2: newer spec, one shipping browser (Firefox 157); Chrome/Safari
    // lag whatwg/dom 71372741d0's candidate-reference removal adjustment.
    // Step 1: initialize candidate from the externally visible reference.
    setCandidate(instance, internal, internal.reference);
    internal.pointer_before_candidate = internal.pointer_before_reference;
    // Step 4, including the step 3.4 throwing path.
    defer setCandidate(instance, internal, null);

    // Steps 2-3: null at the end of the collection; otherwise find an accept.
    while (internal.candidate) |candidate| {
        switch (direction) {
            .next => {
                if (!internal.pointer_before_candidate) {
                    const following = getNextNodeInTree(candidate, internal.root) orelse return null;
                    setCandidate(instance, internal, following);
                }
                internal.pointer_before_candidate = false;
            },
            .previous => {
                if (internal.pointer_before_candidate) {
                    const preceding = getPreviousNodeInTree(candidate, internal.root) orelse return null;
                    setCandidate(instance, internal, preceding);
                }
                internal.pointer_before_candidate = true;
            },
        }
        // Step 3.3's node is the original candidate, even if removal retargets
        // the candidate tuple. Gecko holds its testNode across filtering too.
        const node = internal.candidate orelse return null;
        const held: ?engine.Owned = if (internal.filter != null)
            engine.retainValue(node.ctx, .{ .instance = node }) catch |err| return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                error.ExceptionPending => error.ExceptionPending,
                else => error.InvalidStateError,
            }
        else
            null;
        // Covers callback AND return-value conversion, which can run JS/GC.
        defer if (held) |value| value.release();
        // Step 3.4: filter. The candidate edge is cleared even when it throws.
        const result = try filterNode(instance, node);
        if (result == NodeFilter.FILTER_ACCEPT) {
            // Step 3.5: publish the adjusted tuple but return the filtered node.
            setReference(instance, internal, internal.candidate);
            internal.pointer_before_reference = internal.pointer_before_candidate;
            return node;
        }
    }
    return null;
}

/// DOM §6 - filter algorithm
/// Filter a node within this iterator
/// Spec: https://dom.spec.whatwg.org/#concept-node-filter
fn filterNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!u16 {
    const internal = getInternal(instance);

    // Step 1: If traverser's active flag is set, throw InvalidStateError
    if (internal.active_flag) {
        return error.InvalidStateError;
    }

    // Step 2: Let n be node's nodeType attribute value − 1 - read through the
    // Node interface. A raw getState read of Node's state answered null for
    // node types whose Node state does not sit at offset 0, and those were
    // accepted without consulting whatToShow at all.
    const node_type = interfaces.Node.get_nodeType(node) catch return NodeFilter.FILTER_SKIP;
    const n: u8 = @intCast(node_type - 1);

    // Step 3: If the nth bit of whatToShow is not set, return FILTER_SKIP
    if (!NodeFilter.isNodeTypeShown(internal.what_to_show, n)) {
        return NodeFilter.FILTER_SKIP;
    }

    // Step 4: If filter is null, return FILTER_ACCEPT
    if (internal.filter == null) {
        return NodeFilter.FILTER_ACCEPT;
    }

    // Step 5: Set traverser's active flag
    internal.active_flag = true;

    // The traversal holds `node` across the call, which runs script (refcount
    // design 1.2: a stack frame across a step that can run script; WebKit's
    // traversals keep `RefPtr<Node>` locals). SHADOW MODE: counted only.
    var held: dom_module.node_holds.RefHold = .{};
    held.set(node);
    defer held.release();

    // Step 6: Let result be the return value of call a user object's operation
    // with filter's callback, "acceptNode", and « node ».
    // Step 7: Unset traverser's active flag - on the throwing path too.
    // Step 8: If an exception was thrown, re-throw it (node_filter.call has).
    const result = node_filter.call(internal.filter.?, node) catch |err| {
        internal.active_flag = false;
        return err;
    };
    internal.active_flag = false;

    // Step 9: Return result
    return result;
}

// ============================================================================
// Tree traversal helpers
// ============================================================================

/// Get the next node in tree order (preorder depth-first), constrained within root
/// Returns null if no next node exists within root
fn getNextNodeInTree(node: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    // If node has children, return first child
    if (interfaces.Node.get_firstChild(node) catch null) |child| {
        return child;
    }

    // Otherwise, find next sibling (or ancestor's next sibling)
    var current = node;

    while (true) {
        // Don't go past root
        if (root) |r| {
            if (current == r) return null;
        }

        // Try next sibling
        if (interfaces.Node.get_nextSibling(current) catch null) |sibling| {
            return sibling;
        }

        // Move up to parent
        const parent = (interfaces.Node.get_parentNode(current) catch null) orelse return null;

        // Check if parent is root
        if (root) |r| {
            if (parent == r) return null;
        }

        current = parent;
    }
}

/// Get the previous node in tree order, constrained within root
/// Returns null if no previous node exists within root
fn getPreviousNodeInTree(node: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    // Don't go before root
    if (root) |r| {
        if (node == r) return null;
    }

    // If node has previous sibling, return its last descendant
    if (interfaces.Node.get_previousSibling(node) catch null) |sibling| {
        return getLastInclusiveDescendant(sibling);
    }

    // Otherwise the parent - which may be the root itself: the iterator
    // collection is the root's INCLUSIVE descendants.
    return interfaces.Node.get_parentNode(node) catch null;
}

/// Get the last inclusive descendant of a node
/// (the node that appears last in tree order within its subtree)
fn getLastInclusiveDescendant(node: *runtime.Instance) *runtime.Instance {
    var current = node;

    while (true) {
        const last_child = (interfaces.Node.get_lastChild(current) catch null) orelse return current;
        current = last_child;
    }
}

// ============================================================================
// Pre-remove steps (called during node removal)
// ============================================================================

/// DOM §6.2 - NodeIterator pre-remove steps
/// Called when a node is about to be removed from the tree
/// Updates iterator state to handle the removal gracefully
/// Spec: https://dom.spec.whatwg.org/#nodeiterator-pre-removing-steps
pub fn preRemoveSteps(instance: *runtime.Instance, to_be_removed: *runtime.Instance) void {
    const internal = getInternal(instance);

    // Pre-remove steps 1-2: adjust both node pointers independently.
    if (internal.reference) |reference| {
        const adjusted = adjustNodePointer(.{ .node = reference, .before = internal.pointer_before_reference }, internal.root, to_be_removed);
        setReference(instance, internal, adjusted.node);
        internal.pointer_before_reference = adjusted.before;
    }
    if (internal.candidate) |candidate| {
        const adjusted = adjustNodePointer(.{ .node = candidate, .before = internal.pointer_before_candidate }, internal.root, to_be_removed);
        setCandidate(instance, internal, adjusted.node);
        internal.pointer_before_candidate = adjusted.before;
    }
}

const NodePointer = struct { node: *runtime.Instance, before: bool };

/// DOM adjust a node pointer, steps 1-4.
fn adjustNodePointer(pointer: NodePointer, root: ?*runtime.Instance, removed: *runtime.Instance) NodePointer {
    // Step 1: removing any inclusive ancestor of root leaves the pointer.
    if (!isInclusiveAncestor(removed, pointer.node)) return pointer;
    if (root) |r| if (isInclusiveAncestor(removed, r)) return pointer;
    // Step 2: when before, prefer the first following node outside the subtree.
    if (pointer.before) {
        if (getNextNodeNotInSubtree(removed, root)) |next| return .{ .node = next, .before = true };
    }
    // Steps 3-4: previous sibling's last descendant, or parent, then after.
    if (interfaces.Node.get_previousSibling(removed) catch null) |previous|
        return .{ .node = getLastInclusiveDescendant(previous), .before = false };
    const parent = (interfaces.Node.get_parentNode(removed) catch null) orelse return pointer;
    return .{ .node = parent, .before = false };
}

/// Check if potential_ancestor is an inclusive ancestor of node
fn isInclusiveAncestor(potential_ancestor: *runtime.Instance, node: *runtime.Instance) bool {
    if (potential_ancestor == node) return true;

    // Use instance_bridge to get NodeBase for tree navigation
    const node_base = instance_bridge.getNodeBase(node) orelse return false;
    const ancestor_base = instance_bridge.getNodeBase(potential_ancestor) orelse return false;

    var current: ?*NodeBase = node_base.parent_node;
    while (current) |curr| {
        if (curr == ancestor_base) return true;
        current = curr.parent_node;
    }

    return false;
}

/// Get the next node after to_be_removed that is an inclusive descendant of root
/// but NOT an inclusive descendant of to_be_removed
fn getNextNodeNotInSubtree(to_be_removed: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    // Use instance_bridge to get NodeBase for tree navigation
    const to_be_removed_base = instance_bridge.getNodeBase(to_be_removed) orelse return null;
    const root_base: ?*NodeBase = if (root) |r| instance_bridge.getNodeBase(r) else null;

    var current: ?*NodeBase = to_be_removed_base;

    // Skip the entire subtree of to_be_removed
    while (current) |node| {
        // Try next sibling
        if (node.next_sibling) |sibling| {
            // Check if sibling is within root
            if (root_base) |r| {
                if (!isInclusiveDescendantBase(sibling, r)) return null;
            }
            return instance_bridge.getInstanceTyped(runtime.Instance, sibling);
        }

        // Move up to parent
        const parent = node.parent_node orelse return null;

        // Check if parent is root - if so, no more nodes
        if (root_base) |r| {
            if (parent == r) return null;
        }

        current = parent;
    }

    return null;
}

/// Check if node is an inclusive descendant of potential_ancestor (NodeBase version)
fn isInclusiveDescendantBase(node: *NodeBase, potential_ancestor: *NodeBase) bool {
    if (node == potential_ancestor) return true;

    var current: ?*NodeBase = node.parent_node;
    while (current) |curr| {
        if (curr == potential_ancestor) return true;
        current = curr.parent_node;
    }

    return false;
}
