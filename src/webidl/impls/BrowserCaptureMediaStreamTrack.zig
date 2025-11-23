//! Implementation for BrowserCaptureMediaStreamTrack interface
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
const BrowserCaptureMediaStreamTrack = interfaces.BrowserCaptureMediaStreamTrack;

pub const State = BrowserCaptureMediaStreamTrack.State;

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

/// Operation: clone
pub fn call_clone(instance: *runtime.Instance) ImplError!interfaces.BrowserCaptureMediaStreamTrack {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: cropTo
pub fn call_cropTo(instance: *runtime.Instance, cropTarget: interfaces.CropTarget) ImplError!*const anyopaque {
    _ = instance;
    _ = cropTarget;
    return error.NotImplemented;
}

/// Operation: restrictTo
pub fn call_restrictTo(instance: *runtime.Instance, RestrictionTarget: interfaces.RestrictionTarget) ImplError!*const anyopaque {
    _ = instance;
    _ = RestrictionTarget;
    return error.NotImplemented;
}

