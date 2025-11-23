//! Implementation for ReadableByteStreamController interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ReadableByteStreamController = interfaces.ReadableByteStreamController;

pub const State = ReadableByteStreamController.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for byobRequest
pub fn get_byobRequest(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for desiredSize
pub fn get_desiredSize(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: error
pub fn call_error(instance: *runtime.Instance, e: *const anyopaque) ImplError!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: enqueue
pub fn call_enqueue(instance: *runtime.Instance, chunk: typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = chunk;
    return error.NotImplemented;
}

