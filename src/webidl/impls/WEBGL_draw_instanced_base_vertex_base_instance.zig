//! Implementation for WEBGL_draw_instanced_base_vertex_base_instance interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_draw_instanced_base_vertex_base_instance = @import("interfaces").WEBGL_draw_instanced_base_vertex_base_instance;

pub const State = WEBGL_draw_instanced_base_vertex_base_instance.State;

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

/// Operation: drawArraysInstancedBaseInstanceWEBGL
pub fn call_drawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque, instanceCount: anyopaque, baseInstance: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    _ = instanceCount;
    _ = baseInstance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawElementsInstancedBaseVertexBaseInstanceWEBGL
pub fn call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type: anyopaque, offset: anyopaque, instanceCount: anyopaque, baseVertex: anyopaque, baseInstance: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = type;
    _ = offset;
    _ = instanceCount;
    _ = baseVertex;
    _ = baseInstance;
    // TODO: Implement operation
    return error.NotImplemented;
}

