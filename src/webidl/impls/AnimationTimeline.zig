//! Implementation for AnimationTimeline interface
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
const AnimationTimeline = interfaces.AnimationTimeline;

pub const State = AnimationTimeline.State;

pub const ImplError = error{
    NotImplemented,
};

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

/// Getter for currentTime
pub fn get_currentTime(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for duration
pub fn get_duration(instance: *runtime.Instance) ImplError!typedefs.CSSNumberish {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: play
pub fn call_play(instance: *runtime.Instance, effect: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    _ = effect;
    return error.NotImplemented;
}

