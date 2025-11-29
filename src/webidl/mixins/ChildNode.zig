//! ChildNode Mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-childnode
//!
//! This mixin delegates to the ChildNode impl for all functionality.
//! The impl contains the actual logic for ChildNode methods.
//!
//! The ChildNode mixin defines:
//! - before(...nodes) - Inserts nodes just before this node
//! - after(...nodes) - Inserts nodes just after this node
//! - replaceWith(...nodes) - Replaces this node with nodes
//! - remove() - Removes this node from its parent

const std = @import("std");
const runtime = @import("runtime");

// Import the impl which contains all the actual logic
const ChildNodeImpl = @import("impls").ChildNode;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    HierarchyRequestError,
    OutOfMemory,
};

// Re-export NodeOrString from impl
pub const NodeOrString = ChildNodeImpl.NodeOrString;

// =============================================================================
// ChildNode Methods (delegate to impl)
// =============================================================================

/// before - Inserts nodes just before this node
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-before
pub fn before(
    allocator: std.mem.Allocator,
    node: *runtime.Instance,
    nodes: []const NodeOrString,
) MixinError!void {
    _ = allocator;
    return ChildNodeImpl.call_before(node, nodes) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.HierarchyRequestError => return error.HierarchyRequestError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// after - Inserts nodes just after this node
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-after
pub fn after(
    allocator: std.mem.Allocator,
    node: *runtime.Instance,
    nodes: []const NodeOrString,
) MixinError!void {
    _ = allocator;
    return ChildNodeImpl.call_after(node, nodes) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.HierarchyRequestError => return error.HierarchyRequestError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// replaceWith - Replaces this node with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-replacewith
pub fn replaceWith(
    allocator: std.mem.Allocator,
    node: *runtime.Instance,
    nodes: []const NodeOrString,
) MixinError!void {
    _ = allocator;
    return ChildNodeImpl.call_replaceWith(node, nodes) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.HierarchyRequestError => return error.HierarchyRequestError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// remove - Removes this node from its parent
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-remove
pub fn remove(node: *runtime.Instance) MixinError!void {
    return ChildNodeImpl.call_remove(node) catch |err| switch (err) {
        error.HierarchyRequestError => return error.HierarchyRequestError,
        else => return error.InvalidStateError,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "ChildNode mixin - delegation to impl" {
    // Test that mixin correctly delegates to impl
    // Full tests are in the impl file
}
