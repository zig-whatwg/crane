//! Implementation for HighlightRegistry interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const HighlightRegistry = @import("interfaces").HighlightRegistry;

pub const State = HighlightRegistry.State;

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

/// Operation: highlightsFromPoint
pub fn call_highlightsFromPoint(instance: *runtime.Instance, x: f32, y: f32, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = x;
    _ = y;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

