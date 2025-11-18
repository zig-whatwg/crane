//! Implementation for AnimationFrameProvider interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AnimationFrameProvider = @import("interfaces").AnimationFrameProvider;

pub const State = AnimationFrameProvider.State;

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

/// Operation: requestAnimationFrame
pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: anyopaque) ImplError!u32 {
    _ = instance;
    _ = callback;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cancelAnimationFrame
pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) ImplError!void {
    _ = instance;
    _ = handle;
    // TODO: Implement operation
    return error.NotImplemented;
}

