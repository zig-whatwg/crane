//! Implementation for GPUCanvasContext interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPUCanvasContext = @import("interfaces").GPUCanvasContext;

pub const State = GPUCanvasContext.State;

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

/// Getter for canvas
pub fn get_canvas(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: configure
pub fn call_configure(instance: *runtime.Instance, configuration: anyopaque) ImplError!void {
    _ = instance;
    _ = configuration;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unconfigure
pub fn call_unconfigure(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getConfiguration
pub fn call_getConfiguration(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getCurrentTexture
pub fn call_getCurrentTexture(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

