//! ParentNode Mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-parentnode
//!
//! This mixin delegates to the ParentNode impl for all functionality.
//! The impl contains the actual logic for ParentNode methods.
//!
//! The ParentNode mixin defines:
//! - children (HTMLCollection of child elements)
//! - firstElementChild
//! - lastElementChild
//! - childElementCount
//! - prepend(nodes...)
//! - append(nodes...)
//! - replaceChildren(nodes...)
//! - querySelector(selectors)
//! - querySelectorAll(selectors)

const std = @import("std");
const runtime = @import("runtime");

// Import the impl which contains all the actual logic
const ParentNodeImpl = @import("impls").ParentNode;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    SyntaxError,
    OutOfMemory,
    HierarchyRequestError,
    NotFoundError,
};

// Re-export NodeOrString from impl
pub const NodeOrString = ParentNodeImpl.NodeOrString;

// =============================================================================
// ParentNode Attribute Getters (delegate to impl)
// =============================================================================

/// Get the first child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
pub fn firstElementChild(node: *runtime.Instance) ?*runtime.Instance {
    return ParentNodeImpl.get_firstElementChild(node) catch null;
}

/// Get the last child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
pub fn lastElementChild(node: *runtime.Instance) ?*runtime.Instance {
    return ParentNodeImpl.get_lastElementChild(node) catch null;
}

/// Get the number of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn childElementCount(node: *runtime.Instance) u32 {
    return ParentNodeImpl.get_childElementCount(node) catch 0;
}

/// Create an HTMLCollection of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn children(allocator: std.mem.Allocator, node: *runtime.Instance, ctx: runtime.Context) MixinError!*runtime.Instance {
    _ = allocator;
    _ = ctx;
    return ParentNodeImpl.get_children(node) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

// =============================================================================
// Selector Matching (delegate to impl)
// =============================================================================

/// querySelector - Returns the first element matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselector
pub fn querySelector(
    allocator: std.mem.Allocator,
    scoping_root: *runtime.Instance,
    selectors: []const u8,
) MixinError!?*runtime.Instance {
    _ = allocator;
    const dom_string = runtime.DOMString.initInterned(selectors);
    return ParentNodeImpl.call_querySelector(scoping_root, dom_string) catch |err| switch (err) {
        error.SyntaxError => return error.SyntaxError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// querySelectorAll - Returns all elements matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn querySelectorAll(
    allocator: std.mem.Allocator,
    scoping_root: *runtime.Instance,
    selectors: []const u8,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    _ = allocator;
    _ = ctx;
    const dom_string = runtime.DOMString.initInterned(selectors);
    return ParentNodeImpl.call_querySelectorAll(scoping_root, dom_string) catch |err| switch (err) {
        error.SyntaxError => return error.SyntaxError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

// =============================================================================
// Public Selector Matching API (for Element.matches and Element.closest)
// =============================================================================

/// Check if an element matches a selector string
/// Spec: https://dom.spec.whatwg.org/#dom-element-matches
pub fn matches(
    allocator: std.mem.Allocator,
    element: *runtime.Instance,
    selectors: []const u8,
) MixinError!bool {
    _ = allocator;
    const dom_string = runtime.DOMString.initInterned(selectors);
    return ParentNodeImpl.matches(element, dom_string) catch |err| switch (err) {
        error.SyntaxError => return error.SyntaxError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// Find closest ancestor (or self) matching a selector string
/// Spec: https://dom.spec.whatwg.org/#dom-element-closest
pub fn closest(
    allocator: std.mem.Allocator,
    element: *runtime.Instance,
    selectors: []const u8,
) MixinError!?*runtime.Instance {
    _ = allocator;
    const dom_string = runtime.DOMString.initInterned(selectors);
    return ParentNodeImpl.closest(element, dom_string) catch |err| switch (err) {
        error.SyntaxError => return error.SyntaxError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

// =============================================================================
// ParentNode Mutation Methods (delegate to impl)
// =============================================================================

/// prepend - Inserts nodes before the first child
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
pub fn prepend(
    allocator: std.mem.Allocator,
    parent: *runtime.Instance,
    nodes: []const NodeOrString,
    ctx: runtime.Context,
) MixinError!void {
    _ = allocator;
    _ = ctx;
    return ParentNodeImpl.call_prepend(parent, nodes) catch |err| switch (err) {
        error.HierarchyRequestError => return error.HierarchyRequestError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// append - Inserts nodes after the last child
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
pub fn append(
    allocator: std.mem.Allocator,
    parent: *runtime.Instance,
    nodes: []const NodeOrString,
    ctx: runtime.Context,
) MixinError!void {
    _ = allocator;
    _ = ctx;
    return ParentNodeImpl.call_append(parent, nodes) catch |err| switch (err) {
        error.HierarchyRequestError => return error.HierarchyRequestError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// replaceChildren - Replaces all children with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
pub fn replaceChildren(
    allocator: std.mem.Allocator,
    parent: *runtime.Instance,
    nodes: []const NodeOrString,
    ctx: runtime.Context,
) MixinError!void {
    _ = allocator;
    _ = ctx;
    return ParentNodeImpl.call_replaceChildren(parent, nodes) catch |err| switch (err) {
        error.HierarchyRequestError => return error.HierarchyRequestError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// moveBefore - Moves a node into this parent before child, preserving state
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
pub fn moveBefore(
    parent: *runtime.Instance,
    node: *runtime.Instance,
    child: ?*runtime.Instance,
) MixinError!void {
    return ParentNodeImpl.call_moveBefore(parent, node, child) catch |err| switch (err) {
        error.HierarchyRequestError => return error.HierarchyRequestError,
        error.NotFoundError => return error.NotFoundError,
        else => return error.InvalidStateError,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "ParentNode mixin - delegation to impl" {
    // Test that mixin correctly delegates to impl
    // Full tests are in the impl file
}
