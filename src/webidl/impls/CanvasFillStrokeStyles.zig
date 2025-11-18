//! Implementation for CanvasFillStrokeStyles interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasFillStrokeStyles = @import("interfaces").CanvasFillStrokeStyles;

pub const State = CanvasFillStrokeStyles.State;

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

/// Getter for strokeStyle
pub fn get_strokeStyle(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for fillStyle
pub fn get_fillStyle(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for strokeStyle
pub fn set_strokeStyle(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for fillStyle
pub fn set_fillStyle(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: createLinearGradient
pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) ImplError!anyopaque {
    _ = instance;
    _ = x0;
    _ = y0;
    _ = x1;
    _ = y1;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createRadialGradient
pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) ImplError!anyopaque {
    _ = instance;
    _ = x0;
    _ = y0;
    _ = r0;
    _ = x1;
    _ = y1;
    _ = r1;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createConicGradient
pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) ImplError!anyopaque {
    _ = instance;
    _ = startAngle;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createPattern
pub fn call_createPattern(instance: *runtime.Instance, image: anyopaque, repetition: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = image;
    _ = repetition;
    // TODO: Implement operation
    return error.NotImplemented;
}

