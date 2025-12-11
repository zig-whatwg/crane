//! Implementation for DocumentFragment interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-documentfragment
//! WHATWG DOM Standard §4.8
//!
//! DocumentFragment is a lightweight container for DOM nodes.
//! It's commonly used to build up DOM structures before inserting them.
//!
//! Migrated from: webidl/src/dom/DocumentFragment.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DocumentFragment = interfaces.DocumentFragment;

// Import related impls
const NodeImpl = @import("Node.zig");

// Import mixins for shared interface methods
const mixins = @import("mixins");
const ParentNode = mixins.ParentNode;
const NonElementParentNode = mixins.NonElementParentNode;

pub const State = DocumentFragment.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
    SyntaxError,
};

/// Internal state for DocumentFragment implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Host element for shadow roots (null for regular document fragments)
    /// Per DOM spec: A shadow root's host is always non-null
    host: ?*runtime.Instance,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .host = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Get the internal state from an instance using registry
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Public function to get internal state (for other impls that need it)
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Initialize instance (creates the instance)
/// Chains to NodeImpl.init() to properly initialize the inheritance chain.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to Node's init which chains to EventTarget
    // This properly initializes the entire inheritance chain
    const instance = try NodeImpl.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const ArenaAllocator = @import("runtime").ArenaAllocator;

    // Set the node type for this DocumentFragment
    if (NodeImpl.getInternalState(instance)) |node_internal| {
        node_internal.node_type = NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE;
    }

    // Initialize DocumentFragment's own internal state and register it
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try Registry.set(instance, internal);

    return instance;
}

/// Get the Node internal state from a DocumentFragment instance
pub fn getNodeInternal(instance: *runtime.Instance) ?*NodeImpl.InternalState {
    return NodeImpl.getInternalState(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Get internal state from registry (where it was stored in init)
    if (Registry.get(instance)) |internal| {
        internal.deinit();
        // Remove from registry to prevent double-free
        Registry.remove(instance);
    }
    // Node cleanup happens via inheritance chain
    NodeImpl.deinit(instance);
}

/// Constructor implementation
/// DOM §4.8 - DocumentFragment()
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &DocumentFragment.vtable, ctx);
    errdefer deinit(instance);

    // Set node type to DOCUMENT_FRAGMENT_NODE (11)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE);

    return instance;
}

// =============================================================================
// ParentNode Mixin Getters
// =============================================================================

/// Getter for children (from ParentNode mixin)
/// Returns a live HTMLCollection of element children
pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return ParentNode.children(internal.allocator, instance, instance.ctx) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Getter for firstElementChild (from ParentNode mixin)
/// Returns the first child that is an element, or null if none.
pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return ParentNode.firstElementChild(instance);
}

/// Getter for lastElementChild (from ParentNode mixin)
/// Returns the last child that is an element, or null if none.
pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return ParentNode.lastElementChild(instance);
}

/// Getter for childElementCount (from ParentNode mixin)
/// Returns the number of child elements
pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    return ParentNode.childElementCount(instance);
}

// =============================================================================
// ParentNode Mixin Operations
// =============================================================================

/// Operation: prepend (from ParentNode mixin)
/// Inserts nodes before the first child of this document fragment
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = nodes;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = internal;

    // Get first child as reference point
    const firstChild = NodeImpl.getFirstChild(instance);

    // TODO: Convert nodes (which may include strings) into actual nodes
    // For now, this is a simplified implementation that only handles single node
    // Full implementation would use the "converting nodes into a node" algorithm

    if (firstChild == null) {
        // No children - nothing to prepend before
        // In full implementation, we'd still insert the converted nodes
        return;
    }

    // Full implementation would insert converted node before firstChild
    // using pre-insert algorithm from DOM spec
}

/// Operation: append (from ParentNode mixin)
/// Inserts nodes after the last child of this document fragment
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = nodes;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = internal;

    // TODO: Convert nodes (which may include strings) into actual nodes
    // For now, this is a simplified implementation
    // Full implementation would use the "converting nodes into a node" algorithm
    // and then append using pre-insert algorithm
}

/// Operation: replaceChildren (from ParentNode mixin)
/// Replaces all children of this document fragment with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    _ = nodes;
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Convert nodes into a node (or null if empty)
    // TODO: Implement conversion algorithm

    // Step 2: Replace all children using replaceAll algorithm
    // For now, just remove all existing children
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        try NodeImpl.removeNodeFromParent(c, instance);
        child = next;
    }

    // Step 3: Insert the converted node (if any)
    // TODO: Insert converted nodes
    _ = internal;
}

/// Operation: moveBefore (from ParentNode mixin)
/// Moves node to before child within this document fragment
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = internal;

    // Step 1: If child's parent is not this, throw NotFoundError
    if (child) |c| {
        if (NodeImpl.getParent(c) != instance) {
            return error.InvalidStateError; // NotFoundError
        }

        // Step 2: If node is the same as child, return
        if (node == c) return;
    }

    // Step 3: Remove node from its current position (if it has a parent)
    if (NodeImpl.getParent(node)) |oldParent| {
        try NodeImpl.removeNodeFromParent(node, oldParent);
    }

    // Step 4: Insert node before child (use interface per Golden Rule #13)
    _ = try interfaces.Node.call_insertBefore(instance, node, child);
}

/// Operation: querySelector (from ParentNode mixin)
/// Returns the first element matching the selector, or null if not found.
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Delegate to ParentNode mixin
    const result = ParentNode.querySelector(internal.allocator, instance, selectors_str) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };

    return result;
}

/// Operation: querySelectorAll (from ParentNode mixin)
/// Returns all elements matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const selectors_str = selectors.asSlice();

    // Delegate to ParentNode mixin
    return ParentNode.querySelectorAll(internal.allocator, instance, selectors_str, instance.ctx) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

// =============================================================================
// NonElementParentNode Mixin Operations
// =============================================================================

/// Operation: getElementById (from NonElementParentNode mixin)
/// Returns the element with the given ID, or null if not found.
/// Spec: https://dom.spec.whatwg.org/#dom-nonelementparentnode-getelementbyid
pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) anyerror!?*runtime.Instance {
    const element_id = elementId.asSlice();

    // Delegate to NonElementParentNode mixin
    return NonElementParentNode.getElementById(instance, element_id);
}

/// Clean up ALL remaining internal states.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}

