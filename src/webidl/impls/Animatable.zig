//! Implementation for Animatable interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Animatable = interfaces.Animatable;

pub const State = Animatable.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Operation: animate
pub fn call_animate(instance: *runtime.Instance, keyframes: ?*const anyopaque, options: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
    _ = instance;
    _ = keyframes;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getAnimations
pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetAnimationsOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}
