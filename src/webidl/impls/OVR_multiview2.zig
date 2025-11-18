//! Implementation for OVR_multiview2 interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const OVR_multiview2 = @import("interfaces").OVR_multiview2;

pub const State = OVR_multiview2.State;

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

/// Operation: framebufferTextureMultiviewOVR
pub fn call_framebufferTextureMultiviewOVR(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, texture: anyopaque, level: anyopaque, baseViewIndex: anyopaque, numViews: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = texture;
    _ = level;
    _ = baseViewIndex;
    _ = numViews;
    // TODO: Implement operation
    return error.NotImplemented;
}

