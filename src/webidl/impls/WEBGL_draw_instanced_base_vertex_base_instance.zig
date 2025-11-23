//! Implementation for WEBGL_draw_instanced_base_vertex_base_instance interface
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
const WEBGL_draw_instanced_base_vertex_base_instance = interfaces.WEBGL_draw_instanced_base_vertex_base_instance;

pub const State = WEBGL_draw_instanced_base_vertex_base_instance.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Operation: drawArraysInstancedBaseInstanceWEBGL
pub fn call_drawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: typedefs.GLenum, first: typedefs.GLint, count: typedefs.GLsizei, instanceCount: typedefs.GLsizei, baseInstance: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    _ = instanceCount;
    _ = baseInstance;
    return error.NotImplemented;
}

/// Operation: drawElementsInstancedBaseVertexBaseInstanceWEBGL
pub fn call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: typedefs.GLenum, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr, instanceCount: typedefs.GLsizei, baseVertex: typedefs.GLint, baseInstance: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = @"type";
    _ = offset;
    _ = instanceCount;
    _ = baseVertex;
    _ = baseInstance;
    return error.NotImplemented;
}

