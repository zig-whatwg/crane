//! Implementation for CanvasDrawPath interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasDrawPath = @import("interfaces").CanvasDrawPath;

pub const State = CanvasDrawPath.State;

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

/// Operation: beginPath
pub fn call_beginPath(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fill
pub fn call_fill(instance: *runtime.Instance, fillRule: anyopaque) ImplError!void {
    _ = instance;
    _ = fillRule;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fill
pub fn call_fill(instance: *runtime.Instance, path: anyopaque, fillRule: anyopaque) ImplError!void {
    _ = instance;
    _ = path;
    _ = fillRule;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stroke
pub fn call_stroke(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stroke
pub fn call_stroke(instance: *runtime.Instance, path: anyopaque) ImplError!void {
    _ = instance;
    _ = path;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clip
pub fn call_clip(instance: *runtime.Instance, fillRule: anyopaque) ImplError!void {
    _ = instance;
    _ = fillRule;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clip
pub fn call_clip(instance: *runtime.Instance, path: anyopaque, fillRule: anyopaque) ImplError!void {
    _ = instance;
    _ = path;
    _ = fillRule;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isPointInPath
pub fn call_isPointInPath(instance: *runtime.Instance, x: f64, y: f64, fillRule: anyopaque) ImplError!bool {
    _ = instance;
    _ = x;
    _ = y;
    _ = fillRule;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isPointInPath
pub fn call_isPointInPath(instance: *runtime.Instance, path: anyopaque, x: f64, y: f64, fillRule: anyopaque) ImplError!bool {
    _ = instance;
    _ = path;
    _ = x;
    _ = y;
    _ = fillRule;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isPointInStroke
pub fn call_isPointInStroke(instance: *runtime.Instance, x: f64, y: f64) ImplError!bool {
    _ = instance;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isPointInStroke
pub fn call_isPointInStroke(instance: *runtime.Instance, path: anyopaque, x: f64, y: f64) ImplError!bool {
    _ = instance;
    _ = path;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

