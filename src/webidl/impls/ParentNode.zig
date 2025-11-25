//! Implementation for ParentNode interface mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-parentnode
//!
//! ParentNode is a mixin, not a standalone interface.
//! This file delegates to src/webidl/mixins/ParentNode.zig which contains
//! the actual implementation shared by Document, Element, and DocumentFragment.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ParentNode = interfaces.ParentNode;

// Import the ParentNode mixin implementation
const mixins = @import("mixins");
const ParentNodeMixin = mixins.ParentNode;

pub const State = ParentNode.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SyntaxError,
    HierarchyRequestError,
    NotFoundError,
    OutOfMemory,
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
// Getters - Delegate to ParentNode mixin
// =============================================================================

/// Getter for children - Returns HTMLCollection of child elements
pub fn get_children(instance: *runtime.Instance) ImplError!*runtime.Instance {
    return ParentNodeMixin.children(
        std.heap.page_allocator,
        instance,
        instance.ctx,
    ) catch |err| {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Getter for firstElementChild
pub fn get_firstElementChild(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    return ParentNodeMixin.firstElementChild(instance);
}

/// Getter for lastElementChild
pub fn get_lastElementChild(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    return ParentNodeMixin.lastElementChild(instance);
}

/// Getter for childElementCount
pub fn get_childElementCount(instance: *runtime.Instance) ImplError!u32 {
    return ParentNodeMixin.childElementCount(instance);
}

// =============================================================================
// Operations - Delegate to ParentNode mixin
// =============================================================================

/// Operation: querySelector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!?*runtime.Instance {
    const selectors_str = selectors.asSlice();
    return ParentNodeMixin.querySelector(
        std.heap.page_allocator,
        instance,
        selectors_str,
    ) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Operation: querySelectorAll
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!*runtime.Instance {
    const selectors_str = selectors.asSlice();
    return ParentNodeMixin.querySelectorAll(
        std.heap.page_allocator,
        instance,
        selectors_str,
        instance.ctx,
    ) catch |err| {
        return switch (err) {
            error.SyntaxError => error.SyntaxError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.NotImplemented,
        };
    };
}

/// Operation: prepend
/// TODO: Implement variadic parameter conversion from anyopaque to []NodeOrString
pub fn call_prepend(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // When variadic support is added:
    // const node_slice = convertVariadicNodes(nodes);
    // ParentNodeMixin.prepend(allocator, instance, node_slice, ctx);
    return error.NotImplemented;
}

/// Operation: append
/// TODO: Implement variadic parameter conversion from anyopaque to []NodeOrString
pub fn call_append(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // When variadic support is added:
    // const node_slice = convertVariadicNodes(nodes);
    // ParentNodeMixin.append(allocator, instance, node_slice, ctx);
    return error.NotImplemented;
}

/// Operation: replaceChildren
/// TODO: Implement variadic parameter conversion from anyopaque to []NodeOrString
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: *const anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // When variadic support is added:
    // const node_slice = convertVariadicNodes(nodes);
    // ParentNodeMixin.replaceChildren(allocator, instance, node_slice, ctx);
    return error.NotImplemented;
}

/// Operation: moveBefore
/// NOTE: Signature should be `child: ?*runtime.Instance` per spec - codegen needs fixing
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: *runtime.Instance) ImplError!void {
    ParentNodeMixin.moveBefore(instance, node, child) catch |err| {
        return switch (err) {
            error.HierarchyRequestError => error.HierarchyRequestError,
            error.NotFoundError => error.NotFoundError,
            else => error.NotImplemented,
        };
    };
}
