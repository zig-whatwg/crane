//! Implementation for OES_vertex_array_object interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const OES_vertex_array_object = @import("interfaces").OES_vertex_array_object;

pub const State = OES_vertex_array_object.State;

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

/// Operation: createVertexArrayOES
pub fn call_createVertexArrayOES(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteVertexArrayOES
pub fn call_deleteVertexArrayOES(instance: *runtime.Instance, arrayObject: anyopaque) ImplError!void {
    _ = instance;
    _ = arrayObject;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isVertexArrayOES
pub fn call_isVertexArrayOES(instance: *runtime.Instance, arrayObject: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = arrayObject;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindVertexArrayOES
pub fn call_bindVertexArrayOES(instance: *runtime.Instance, arrayObject: anyopaque) ImplError!void {
    _ = instance;
    _ = arrayObject;
    // TODO: Implement operation
    return error.NotImplemented;
}

