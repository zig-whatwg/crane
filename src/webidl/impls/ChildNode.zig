//! Implementation for ChildNode mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-childnode
//!
//! This impl contains the actual logic for ChildNode methods. The mixin file
//! delegates to these functions.
//!
//! The ChildNode mixin defines:
//! - before(...nodes) - Inserts nodes just before this node
//! - after(...nodes) - Inserts nodes just after this node
//! - replaceWith(...nodes) - Replaces this node with nodes
//! - remove() - Removes this node from its parent

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");

// Import impl modules for accessing internal state
const NodeImpl = @import("Node.zig");

pub const State = interfaces.ChildNode.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    HierarchyRequestError,
    OutOfMemory,
};

/// Union type for nodes or strings (used in variadic node methods)
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
pub const NodeOrString = union(enum) {
    node: *runtime.Instance,
    string: []const u8,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    runtime.Instance.deinit(instance);
}

// =============================================================================
// ChildNode Methods
// =============================================================================

/// before - Inserts nodes just before this node
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-before
///
/// Steps:
/// 1. Let parent be this's parent
/// 2. If parent is null, return
/// 3. Let viablePreviousSibling be this's first preceding sibling not in nodes
/// 4. Let node be the result of converting nodes into a node
/// 5. If viablePreviousSibling is null, set it to parent's first child
/// 6. Otherwise, set it to viablePreviousSibling's next sibling
/// 7. Pre-insert node into parent before viablePreviousSibling
pub fn call_before(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    _ = nodes;

    // Step 1: Get parent
    const parent = NodeImpl.getParent(instance) orelse return; // Step 2: If null, return

    // TODO: Implement full algorithm with node conversion and pre-insert
    // For now, this is a stub that requires mutation algorithm implementation
    _ = parent;
    return error.NotImplemented;
}

/// after - Inserts nodes just after this node
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-after
///
/// Steps:
/// 1. Let parent be this's parent
/// 2. If parent is null, return
/// 3. Let viableNextSibling be this's first following sibling not in nodes
/// 4. Let node be the result of converting nodes into a node
/// 5. Pre-insert node into parent before viableNextSibling
pub fn call_after(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    _ = nodes;

    // Step 1: Get parent
    const parent = NodeImpl.getParent(instance) orelse return; // Step 2: If null, return

    // TODO: Implement full algorithm with node conversion and pre-insert
    _ = parent;
    return error.NotImplemented;
}

/// replaceWith - Replaces this node with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-replacewith
///
/// Steps:
/// 1. Let parent be this's parent
/// 2. If parent is null, return
/// 3. Let viableNextSibling be this's first following sibling not in nodes
/// 4. Let node be the result of converting nodes into a node
/// 5. If this's parent is parent, replace this with node within parent
/// 6. Otherwise, pre-insert node into parent before viableNextSibling
pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    _ = nodes;

    // Step 1: Get parent
    const parent = NodeImpl.getParent(instance) orelse return; // Step 2: If null, return

    // TODO: Implement full algorithm with node conversion and replace
    _ = parent;
    return error.NotImplemented;
}

/// remove - Removes this node from its parent
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-remove
///
/// Steps:
/// 1. If this's parent is null, return
/// 2. Remove this
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    // Step 1: Get parent, if null return
    const parent = NodeImpl.getParent(instance) orelse return;

    // Step 2: Remove this node from parent
    // Use the Node's removeNodeFromParent which handles all the tree mutation
    NodeImpl.removeNodeFromParent(instance, parent) catch return error.HierarchyRequestError;
}
