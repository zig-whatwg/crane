//! Implementation for NodeIterator interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

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
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for root
pub fn get_root(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for referenceNode
pub fn get_referenceNode(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pointerBeforeReferenceNode
pub fn get_pointerBeforeReferenceNode(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for whatToShow
pub fn get_whatToShow(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for filter
pub fn get_filter(instance: *runtime.Instance) ImplError!interfaces.NodeFilter {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: nextNode
pub fn call_nextNode(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: detach
pub fn call_detach(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: previousNode
pub fn call_previousNode(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

