//! Implementation for WEBGL_multi_draw_instanced_base_vertex_base_instance interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_multi_draw_instanced_base_vertex_base_instance = @import("interfaces").WEBGL_multi_draw_instanced_base_vertex_base_instance;

pub const State = WEBGL_multi_draw_instanced_base_vertex_base_instance.State;

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

/// Operation: multiDrawArraysInstancedBaseInstanceWEBGL
pub fn call_multiDrawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: anyopaque, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, baseInstancesList: anyopaque, baseInstancesOffset: u64, drawcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = firstsList;
    _ = firstsOffset;
    _ = countsList;
    _ = countsOffset;
    _ = instanceCountsList;
    _ = instanceCountsOffset;
    _ = baseInstancesList;
    _ = baseInstancesOffset;
    _ = drawcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL
pub fn call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: anyopaque, countsList: anyopaque, countsOffset: u64, type: anyopaque, offsetsList: anyopaque, offsetsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, baseVerticesList: anyopaque, baseVerticesOffset: u64, baseInstancesList: anyopaque, baseInstancesOffset: u64, drawcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = countsList;
    _ = countsOffset;
    _ = type;
    _ = offsetsList;
    _ = offsetsOffset;
    _ = instanceCountsList;
    _ = instanceCountsOffset;
    _ = baseVerticesList;
    _ = baseVerticesOffset;
    _ = baseInstancesList;
    _ = baseInstancesOffset;
    _ = drawcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

