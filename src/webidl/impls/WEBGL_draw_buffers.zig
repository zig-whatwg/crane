//! Implementation for WEBGL_draw_buffers interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_draw_buffers = @import("interfaces").WEBGL_draw_buffers;

pub const State = WEBGL_draw_buffers.State;

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

/// Operation: drawBuffersWEBGL
pub fn call_drawBuffersWEBGL(instance: *runtime.Instance, buffers: anyopaque) ImplError!void {
    _ = instance;
    _ = buffers;
    // TODO: Implement operation
    return error.NotImplemented;
}

