//! Implementation for ML interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ML = @import("interfaces").ML;

pub const State = ML.State;

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

/// Operation: createContext
pub fn call_createContext(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createContext
pub fn call_createContext(instance: *runtime.Instance, gpuDevice: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = gpuDevice;
    // TODO: Implement operation
    return error.NotImplemented;
}

