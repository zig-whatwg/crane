//! ChildNode Mixin Implementation
//!
//! Spec: https://dom.spec.whatwg.org/#interface-childnode
//!
//! This mixin provides mutation methods for nodes that can be children.
//! Used by: DocumentType, Element, CharacterData
//!
//! The ChildNode mixin defines:
//! - before(...nodes) - Inserts nodes just before this node
//! - after(...nodes) - Inserts nodes just after this node
//! - replaceWith(...nodes) - Replaces this node with nodes
//! - remove() - Removes this node from its parent

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

// Import impl modules for accessing internal state
const impls = @import("impls");
const NodeImpl = impls.Node;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    HierarchyRequestError,
    OutOfMemory,
};

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
pub fn before(
    allocator: std.mem.Allocator,
    node: *runtime.Instance,
    nodes: []const NodeOrString,
) MixinError!void {
    _ = allocator;
    _ = nodes;

    // Step 1: Get parent
    const parent = NodeImpl.getParent(node) orelse return; // Step 2: If null, return

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
pub fn after(
    allocator: std.mem.Allocator,
    node: *runtime.Instance,
    nodes: []const NodeOrString,
) MixinError!void {
    _ = allocator;
    _ = nodes;

    // Step 1: Get parent
    const parent = NodeImpl.getParent(node) orelse return; // Step 2: If null, return

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
pub fn replaceWith(
    allocator: std.mem.Allocator,
    node: *runtime.Instance,
    nodes: []const NodeOrString,
) MixinError!void {
    _ = allocator;
    _ = nodes;

    // Step 1: Get parent
    const parent = NodeImpl.getParent(node) orelse return; // Step 2: If null, return

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
pub fn remove(node: *runtime.Instance) MixinError!void {
    // Step 1: Get parent, if null return
    const parent = NodeImpl.getParent(node) orelse return;

    // Step 2: Remove this node from parent
    // Use the Node's removeChild which handles all the tree mutation
    NodeImpl.removeChildInternal(parent, node) catch return error.HierarchyRequestError;
}

// =============================================================================
// Types
// =============================================================================

/// Union type for nodes or strings (used in variadic node methods)
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
pub const NodeOrString = union(enum) {
    node: *runtime.Instance,
    string: []const u8,
};

// =============================================================================
// Tests
// =============================================================================

test "ChildNode mixin - remove" {
    // Test would require setting up runtime instances
    // Placeholder for now
}
