//! Implementation for ReadableByteStreamController interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ReadableByteStreamController = @import("interfaces").ReadableByteStreamController;

pub const State = ReadableByteStreamController.State;

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

/// Getter for byobRequest
pub fn get_byobRequest(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for desiredSize
pub fn get_desiredSize(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: enqueue
pub fn call_enqueue(instance: *runtime.Instance, chunk: anyopaque) ImplError!void {
    _ = instance;
    _ = chunk;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: error
pub fn call_error(instance: *runtime.Instance, e: anyopaque) ImplError!void {
    _ = instance;
    _ = e;
    // TODO: Implement operation
    return error.NotImplemented;
}

