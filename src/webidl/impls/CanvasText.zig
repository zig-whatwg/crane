//! Implementation for CanvasText interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasText = @import("interfaces").CanvasText;

pub const State = CanvasText.State;

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

/// Operation: fillText
pub fn call_fillText(instance: *runtime.Instance, text: runtime.DOMString, x: f64, y: f64, maxWidth: f64) ImplError!void {
    _ = instance;
    _ = text;
    _ = x;
    _ = y;
    _ = maxWidth;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: strokeText
pub fn call_strokeText(instance: *runtime.Instance, text: runtime.DOMString, x: f64, y: f64, maxWidth: f64) ImplError!void {
    _ = instance;
    _ = text;
    _ = x;
    _ = y;
    _ = maxWidth;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: measureText
pub fn call_measureText(instance: *runtime.Instance, text: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = text;
    // TODO: Implement operation
    return error.NotImplemented;
}

