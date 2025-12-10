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
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NodeIterator = interfaces.NodeIterator;

// Import related impls
const NodeImpl = @import("Node.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = NodeIterator.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
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

    /// Bitmask indicating which node types to show
    what_to_show: u32,

    /// Optional filter callback
    /// Stored as opaque to support WebIDL callback interface
    filter: ?*anyopaque,

    /// Active flag to prevent recursive invocations
    active_flag: bool,

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

/// Helper to get NodeImpl internal state from a node instance
fn getNodeInternal(node: *runtime.Instance) ?*NodeImpl.InternalState {
    const state = node.getState(interfaces.Node.State);
    return state.own._internal;
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
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Initialize a NodeIterator with given parameters
/// Called by Document.createNodeIterator
pub fn initWithParams(
    instance: *runtime.Instance,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*anyopaque,
) void {
    const internal = getInternal(instance);
    internal.root = root;
    internal.reference = root; // Start at root
    internal.pointer_before_reference = true; // Start before root
    internal.what_to_show = what_to_show;
    internal.filter = filter;
    internal.active_flag = false;
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
/// Returns the filter callback (may be null)
/// Note: WebIDL says nullable NodeFilter, returns null if no filter
pub fn get_filter(instance: *runtime.Instance) anyerror!??*runtime.CallbackWrapper {
    const internal = getInternal(instance);
    // If filter is null, return null (outer optional)
    if (internal.filter) |filter_ptr| {
        // Cast opaque pointer back to CallbackWrapper
        const callback: *runtime.CallbackWrapper = @ptrCast(@alignCast(filter_ptr));
        return callback; // ??*CallbackWrapper - inner optional with value
    }
    return null; // null for outer optional
}

// ============================================================================
// Navigation methods
// ============================================================================

/// DOM §6.2 - NodeIterator.nextNode()
/// Returns the next node in the iteration, or null if none
/// Spec: https://dom.spec.whatwg.org/#dom-nodeiterator-nextnode
pub fn call_nextNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try traverse(instance, .next) orelse return error.NotImplemented; // null
}

/// DOM §6.2 - NodeIterator.previousNode()
/// Returns the previous node in the iteration, or null if none
/// Spec: https://dom.spec.whatwg.org/#dom-nodeiterator-previousnode
pub fn call_previousNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try traverse(instance, .previous) orelse return error.NotImplemented; // null
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

    // Step 1: Let node be iterator's reference
    var node = internal.reference orelse return null;

    // Step 2: Let beforeNode be iterator's pointer before reference
    var before_node = internal.pointer_before_reference;

    // Step 3: While true
    while (true) {
        // Step 3.1: Branch on direction
        switch (direction) {
            .next => {
                if (!before_node) {
                    // Find first node following node in iterator collection
                    const next_node = getNextNodeInTree(node, internal.root);
                    if (next_node == null) return null;
                    node = next_node.?;
                } else {
                    // Set beforeNode to false
                    before_node = false;
                }
            },
            .previous => {
                if (before_node) {
                    // Find first node preceding node in iterator collection
                    const prev_node = getPreviousNodeInTree(node, internal.root);
                    if (prev_node == null) return null;
                    node = prev_node.?;
                } else {
                    // Set beforeNode to true
                    before_node = true;
                }
            },
        }

        // Step 3.2: Let result be the result of filtering node within iterator
        const result = try filterNode(instance, node);

        // Step 3.3: If result is FILTER_ACCEPT, then break
        if (result == NodeFilter.FILTER_ACCEPT) {
            break;
        }
    }

    // Step 4: Set iterator's reference to node
    internal.reference = node;

    // Step 5: Set iterator's pointer before reference to beforeNode
    internal.pointer_before_reference = before_node;

    // Step 6: Return node
    return node;
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

    // Step 2: Let n be node's nodeType attribute value − 1
    const node_internal = getNodeInternal(node) orelse return NodeFilter.FILTER_ACCEPT;
    const node_type = node_internal.node_type;
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

    // Step 6: Let result be the return value of call a user object's operation
    // with filter's callback, "acceptNode", and « node »
    // TODO: Implement proper WebIDL callback invocation
    // For now, accept all nodes when filter is present
    const result = NodeFilter.FILTER_ACCEPT;

    // Step 7: Unset traverser's active flag
    internal.active_flag = false;

    // Step 8: If an exception was thrown, rethrow it
    // (handled by error union in real callback)

    // Step 9: Return result
    return result;
}

// ============================================================================
// Tree traversal helpers
// ============================================================================

/// Get the next node in tree order (preorder depth-first), constrained within root
/// Returns null if no next node exists within root
fn getNextNodeInTree(node: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    const node_internal = getNodeInternal(node) orelse return null;

    // If node has children, return first child
    if (node_internal.first_child) |child| {
        return child;
    }

    // Otherwise, find next sibling (or ancestor's next sibling)
    var current = node;
    var current_internal = node_internal;

    while (true) {
        // Don't go past root
        if (root) |r| {
            if (current == r) return null;
        }

        // Try next sibling
        if (current_internal.next_sibling) |sibling| {
            return sibling;
        }

        // Move up to parent
        const parent = current_internal.parent orelse return null;

        // Check if parent is root
        if (root) |r| {
            if (parent == r) return null;
        }

        current = parent;
        current_internal = getNodeInternal(current) orelse return null;
    }
}

/// Get the previous node in tree order, constrained within root
/// Returns null if no previous node exists within root
fn getPreviousNodeInTree(node: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    // Don't go before root
    if (root) |r| {
        if (node == r) return null;
    }

    const node_internal = getNodeInternal(node) orelse return null;

    // If node has previous sibling, return its last descendant
    if (node_internal.previous_sibling) |sibling| {
        return getLastInclusiveDescendant(sibling);
    }

    // Otherwise return parent (if not root)
    const parent = node_internal.parent orelse return null;

    if (root) |r| {
        if (parent == r) return null;
    }

    return parent;
}

/// Get the last inclusive descendant of a node
/// (the node that appears last in tree order within its subtree)
fn getLastInclusiveDescendant(node: *runtime.Instance) *runtime.Instance {
    var current = node;

    while (true) {
        const current_internal = getNodeInternal(current) orelse return current;
        const last_child = current_internal.last_child orelse return current;
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

    // Step 1: If toBeRemovedNode is not an inclusive ancestor of reference,
    // or toBeRemovedNode is root, then return
    if (internal.root) |root| {
        if (to_be_removed == root) return;
    }

    // Check if to_be_removed is an inclusive ancestor of reference
    const reference = internal.reference orelse return;
    if (!isInclusiveAncestor(to_be_removed, reference)) return;

    // Step 2: If pointer before reference is true
    if (internal.pointer_before_reference) {
        // Step 2.1: Let next be toBeRemovedNode's first following node that is
        // an inclusive descendant of root and is not an inclusive descendant of toBeRemovedNode
        const next = getNextNodeNotInSubtree(to_be_removed, internal.root);

        // Step 2.2: If next is non-null, set reference to next and return
        if (next) |next_node| {
            internal.reference = next_node;
            return;
        }

        // Step 2.3: Otherwise, set pointer before reference to false
        internal.pointer_before_reference = false;
    }

    // Step 3: Set reference to the first preceding node of toBeRemovedNode
    // that is an inclusive descendant of root and is not an inclusive descendant of toBeRemovedNode,
    // or null if there is no such node
    const to_be_removed_internal = getNodeInternal(to_be_removed) orelse return;

    // Find previous sibling's last descendant, or parent
    if (to_be_removed_internal.previous_sibling) |prev_sibling| {
        internal.reference = getLastInclusiveDescendant(prev_sibling);
    } else {
        // Use parent if no previous sibling
        internal.reference = to_be_removed_internal.parent;
    }
}

/// Check if potential_ancestor is an inclusive ancestor of node
fn isInclusiveAncestor(potential_ancestor: *runtime.Instance, node: *runtime.Instance) bool {
    if (potential_ancestor == node) return true;

    var current: ?*runtime.Instance = node;
    while (current) |curr| {
        if (curr == potential_ancestor) return true;
        const curr_internal = getNodeInternal(curr) orelse break;
        current = curr_internal.parent;
    }

    return false;
}

/// Check if node is an inclusive descendant of potential_ancestor
fn isInclusiveDescendant(node: *runtime.Instance, potential_ancestor: *runtime.Instance) bool {
    return isInclusiveAncestor(potential_ancestor, node);
}

/// Get the next node after to_be_removed that is an inclusive descendant of root
/// but NOT an inclusive descendant of to_be_removed
fn getNextNodeNotInSubtree(to_be_removed: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    var current: ?*runtime.Instance = to_be_removed;

    // Skip the entire subtree of to_be_removed
    while (current) |node| {
        const node_internal = getNodeInternal(node) orelse return null;

        // Try next sibling
        if (node_internal.next_sibling) |sibling| {
            // Check if sibling is within root
            if (root) |r| {
                if (!isInclusiveDescendant(sibling, r)) return null;
            }
            return sibling;
        }

        // Move up to parent
        const parent = node_internal.parent orelse return null;

        // Check if parent is root - if so, no more nodes
        if (root) |r| {
            if (parent == r) return null;
        }

        current = parent;
    }

    return null;
}
