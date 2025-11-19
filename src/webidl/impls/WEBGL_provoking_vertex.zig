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

/// Initialize instance (delegates to runtime.Instance.init)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable);
    // TODO: Add custom initialization here if needed
    // const state = instance.getState(StateType);
    // state.* = .{}; // Initialize fields
    return instance;
}

/// Deinitialize instance (delegates to runtime.Instance.deinit)
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Add custom cleanup here if needed
    // const state = instance.getState(State);
    // Clean up fields...
    runtime.Instance.deinit(instance);
}

/// Operation: provokingVertexWEBGL
pub fn call_provokingVertexWEBGL(instance: *runtime.Instance, provokeMode: anyopaque) ImplError!void {
    _ = instance;
    _ = provokeMode;
    // TODO: Implement operation
    return error.NotImplemented;
}

