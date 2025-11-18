//! Implementation for HandwritingDrawing interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingDrawing = @import("interfaces").HandwritingDrawing;

pub const State = HandwritingDrawing.State;

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

/// Operation: addStroke
pub fn call_addStroke(instance: *runtime.Instance, stroke: anyopaque) ImplError!void {
    _ = instance;
    _ = stroke;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeStroke
pub fn call_removeStroke(instance: *runtime.Instance, stroke: anyopaque) ImplError!void {
    _ = instance;
    _ = stroke;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getStrokes
pub fn call_getStrokes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPrediction
pub fn call_getPrediction(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

