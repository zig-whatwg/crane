//! Implementation for CanvasUserInterface interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasUserInterface = @import("interfaces").CanvasUserInterface;

pub const State = CanvasUserInterface.State;

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

/// Operation: drawFocusIfNeeded
pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, element: anyopaque) ImplError!void {
    _ = instance;
    _ = element;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawFocusIfNeeded
pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, path: anyopaque, element: anyopaque) ImplError!void {
    _ = instance;
    _ = path;
    _ = element;
    // TODO: Implement operation
    return error.NotImplemented;
}

