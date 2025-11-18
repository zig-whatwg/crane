//! Implementation for LayoutChild interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const LayoutChild = @import("interfaces").LayoutChild;

pub const State = LayoutChild.State;

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

/// Getter for styleMap
pub fn get_styleMap(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: intrinsicSizes
pub fn call_intrinsicSizes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: layoutNextFragment
pub fn call_layoutNextFragment(instance: *runtime.Instance, constraints: anyopaque, breakToken: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = constraints;
    _ = breakToken;
    // TODO: Implement operation
    return error.NotImplemented;
}

