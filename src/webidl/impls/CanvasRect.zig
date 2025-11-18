//! Implementation for CanvasRect interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasRect = @import("interfaces").CanvasRect;

pub const State = CanvasRect.State;

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

/// Operation: clearRect
pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fillRect
pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: strokeRect
pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    // TODO: Implement operation
    return error.NotImplemented;
}

