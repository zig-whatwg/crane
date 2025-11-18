//! Implementation for ANGLE_instanced_arrays interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ANGLE_instanced_arrays = @import("interfaces").ANGLE_instanced_arrays;

pub const State = ANGLE_instanced_arrays.State;

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

/// Operation: drawArraysInstancedANGLE
pub fn call_drawArraysInstancedANGLE(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque, primcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    _ = primcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawElementsInstancedANGLE
pub fn call_drawElementsInstancedANGLE(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type: anyopaque, offset: anyopaque, primcount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = type;
    _ = offset;
    _ = primcount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribDivisorANGLE
pub fn call_vertexAttribDivisorANGLE(instance: *runtime.Instance, index: anyopaque, divisor: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = divisor;
    // TODO: Implement operation
    return error.NotImplemented;
}

