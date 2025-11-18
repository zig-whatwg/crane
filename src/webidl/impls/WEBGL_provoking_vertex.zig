//! Implementation for WEBGL_provoking_vertex interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_provoking_vertex = @import("interfaces").WEBGL_provoking_vertex;

pub const State = WEBGL_provoking_vertex.State;

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

/// Operation: provokingVertexWEBGL
pub fn call_provokingVertexWEBGL(instance: *runtime.Instance, provokeMode: anyopaque) ImplError!void {
    _ = instance;
    _ = provokeMode;
    // TODO: Implement operation
    return error.NotImplemented;
}

