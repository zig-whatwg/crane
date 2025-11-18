//! Implementation for CanvasGradient interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasGradient = @import("interfaces").CanvasGradient;

pub const State = CanvasGradient.State;

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

/// Operation: addColorStop
pub fn call_addColorStop(instance: *runtime.Instance, offset: f64, color: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = offset;
    _ = color;
    // TODO: Implement operation
    return error.NotImplemented;
}

