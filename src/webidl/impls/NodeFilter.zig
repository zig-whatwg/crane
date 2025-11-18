//! Implementation for NodeFilter interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const NodeFilter = @import("interfaces").NodeFilter;

pub const State = NodeFilter.State;

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

/// Operation: acceptNode
pub fn call_acceptNode(instance: *runtime.Instance, node: anyopaque) ImplError!u16 {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

