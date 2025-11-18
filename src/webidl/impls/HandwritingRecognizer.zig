//! Implementation for HandwritingRecognizer interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingRecognizer = @import("interfaces").HandwritingRecognizer;

pub const State = HandwritingRecognizer.State;

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

/// Operation: startDrawing
pub fn call_startDrawing(instance: *runtime.Instance, hints: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = hints;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: finish
pub fn call_finish(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

