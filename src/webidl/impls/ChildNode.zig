//! Implementation for ChildNode interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ChildNode = @import("interfaces").ChildNode;

pub const State = ChildNode.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Operation: before
pub fn call_before(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: after
pub fn call_after(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceWith
pub fn call_replaceWith(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

