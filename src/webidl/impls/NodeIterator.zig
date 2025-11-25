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

pub const State = NodeIterator.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// NodeFilter constants per DOM spec
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
    /// TODO: Proper WebIDL callback support - for now store as opaque pointer
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
fn getInternal(instance: *runtime.Instance) *InternalState {
    const state = instance.getState(State);
    return @ptrCast(@alignCast(state.own._internal));
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
    runtime.Instance.deinit(instance);
}

// ============================================================================
// Getters
// ============================================================================

/// DOM §6.2 - NodeIterator.root
/// Returns the root node
pub fn get_root(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.root orelse return error.NotImplemented;
}

/// DOM §6.2 - NodeIterator.referenceNode
/// Returns the current reference node
pub fn get_referenceNode(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.reference orelse return error.NotImplemented;
}

/// DOM §6.2 - NodeIterator.pointerBeforeReferenceNode
/// Returns true if pointer is before the reference node
pub fn get_pointerBeforeReferenceNode(instance: *runtime.Instance) ImplError!bool {
    const internal = getInternal(instance);
    return internal.pointer_before_reference;
}

/// DOM §6.2 - NodeIterator.whatToShow
/// Returns the whatToShow bitmask
pub fn get_whatToShow(instance: *runtime.Instance) ImplError!u32 {
    const internal = getInternal(instance);
    return internal.what_to_show;
}

/// DOM §6.2 - NodeIterator.filter
/// Returns the filter callback (may be null)
/// Note: Generated interface expects non-nullable but WebIDL says nullable
pub fn get_filter(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const internal = getInternal(instance);
    // TODO: Return proper NodeFilter interface
    // For now, filter is stored as opaque pointer
    _ = internal;
    return error.NotImplemented;
}

// ============================================================================
// Navigation methods
// ============================================================================

/// DOM §6.2 - NodeIterator.nextNode()
/// Returns the next node in the iteration, or null if none
/// Note: WebIDL says nullable, but generated interface expects non-null - we throw NotImplemented for null
pub fn call_nextNode(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return try traverse(instance, .next) orelse return error.NotImplemented;
}

/// DOM §6.2 - NodeIterator.previousNode()
/// Returns the previous node in the iteration, or null if none
/// Note: WebIDL says nullable, but generated interface expects non-null - we throw NotImplemented for null
pub fn call_previousNode(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return try traverse(instance, .previous) orelse return error.NotImplemented;
}

/// DOM §6.2 - NodeIterator.detach()
/// Legacy method - does nothing (functionality removed, kept for compatibility)
pub fn call_detach(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // Do nothing per spec
}

// ============================================================================
// Internal algorithms
// ============================================================================

/// DOM §6.2 - traverse algorithm
/// Given a direction, traverse the tree and return the next accepted node
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
fn filterNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!u16 {
    const internal = getInternal(instance);
    _ = node; // TODO: Use node to get nodeType once bridged

    // Step 1: If traverser's active flag is set, throw InvalidStateError
    if (internal.active_flag) {
        return error.InvalidStateError;
    }

    // Step 2: Let n be node's nodeType attribute value − 1
    // TODO: Get node_type from Node interface via NodeImpl
    // For now, assume all nodes pass type check
    const node_type: u8 = 1; // ELEMENT_NODE as default
    const n = node_type - 1;

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

    // Step 6: Call filter callback
    // TODO: Implement proper WebIDL callback invocation
    // For now, just accept all nodes when filter is set
    const result = NodeFilter.FILTER_ACCEPT;

    // Step 7: Unset traverser's active flag
    internal.active_flag = false;

    // Step 8: Return result
    return result;
}

// ============================================================================
// Tree traversal helpers (adapted for runtime.Instance)
// ============================================================================
// TODO: These should use DOM tree_helpers once Node bridging is complete

/// Get the next node in tree order, constrained within a root
fn getNextNodeInTree(node: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    // TODO: Implement using DOM tree_helpers once bridged
    // For now, return null to prevent infinite loops
    _ = node;
    _ = root;
    return null;
}

/// Get the previous node in tree order, constrained within a root
fn getPreviousNodeInTree(node: *runtime.Instance, root: ?*runtime.Instance) ?*runtime.Instance {
    // TODO: Implement using DOM tree_helpers once bridged
    _ = node;
    _ = root;
    return null;
}

// ============================================================================
// Pre-remove steps (called during node removal)
// ============================================================================

/// DOM §6.2 - NodeIterator pre-remove steps
/// Called when a node is about to be removed from the tree
/// Updates iterator state to handle the removal gracefully
pub fn preRemoveSteps(instance: *runtime.Instance, to_be_removed: *runtime.Instance) void {
    const internal = getInternal(instance);

    // Step 1: If toBeRemovedNode is not an inclusive ancestor of reference,
    // or toBeRemovedNode is root, then return
    if (internal.root) |root| {
        if (to_be_removed == root) return;
    }

    // TODO: Check inclusive ancestor once DOM tree operations are bridged
    // if (!isInclusiveAncestor(to_be_removed, internal.reference)) return;

    // TODO: Check inclusive ancestor once DOM tree operations are bridged
    // For now, use to_be_removed to silence unused parameter warning
    if (to_be_removed == internal.reference) {
        // Node being removed is the reference - need to update
    }

    // Step 2: If pointer before reference is true
    if (internal.pointer_before_reference) {
        // Step 2.1: Let next be toBeRemovedNode's first following node
        // TODO: Implement once tree operations are bridged

        // Step 2.3: Otherwise, set pointer before reference to false
        internal.pointer_before_reference = false;
    }

    // Step 3: Set reference appropriately
    // TODO: Implement once tree operations are bridged
}
