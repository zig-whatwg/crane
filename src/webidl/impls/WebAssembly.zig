//! Implementation for WebAssembly interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebAssembly = @import("interfaces").WebAssembly;

pub const State = WebAssembly.State;

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

/// Getter for JSTag
pub fn get_JSTag(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: validate
pub fn call_validate(instance: *runtime.Instance, bytes: anyopaque, options: anyopaque) ImplError!bool {
    _ = instance;
    _ = bytes;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compile
pub fn call_compile(instance: *runtime.Instance, bytes: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = bytes;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: instantiate
pub fn call_instantiate(instance: *runtime.Instance, bytes: anyopaque, importObject: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = bytes;
    _ = importObject;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: instantiate
pub fn call_instantiate(instance: *runtime.Instance, moduleObject: anyopaque, importObject: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = moduleObject;
    _ = importObject;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compileStreaming
pub fn call_compileStreaming(instance: *runtime.Instance, source: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = source;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: instantiateStreaming
pub fn call_instantiateStreaming(instance: *runtime.Instance, source: anyopaque, importObject: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = source;
    _ = importObject;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

