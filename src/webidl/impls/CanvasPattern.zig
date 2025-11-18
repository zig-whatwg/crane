//! Implementation for CanvasPattern interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasPattern = @import("interfaces").CanvasPattern;

pub const State = CanvasPattern.State;

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

/// Operation: setTransform
pub fn call_setTransform(instance: *runtime.Instance, transform: anyopaque) ImplError!void {
    _ = instance;
    _ = transform;
    // TODO: Implement operation
    return error.NotImplemented;
}

