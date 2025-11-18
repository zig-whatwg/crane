//! Implementation for CanvasPathDrawingStyles interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasPathDrawingStyles = @import("interfaces").CanvasPathDrawingStyles;

pub const State = CanvasPathDrawingStyles.State;

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

/// Getter for lineWidth
pub fn get_lineWidth(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lineCap
pub fn get_lineCap(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lineJoin
pub fn get_lineJoin(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for miterLimit
pub fn get_miterLimit(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lineDashOffset
pub fn get_lineDashOffset(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for lineWidth
pub fn set_lineWidth(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for lineCap
pub fn set_lineCap(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for lineJoin
pub fn set_lineJoin(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for miterLimit
pub fn set_miterLimit(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for lineDashOffset
pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: setLineDash
pub fn call_setLineDash(instance: *runtime.Instance, segments: anyopaque) ImplError!void {
    _ = instance;
    _ = segments;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getLineDash
pub fn call_getLineDash(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

