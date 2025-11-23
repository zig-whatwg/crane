//! Implementation for Subscriber interface
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
const Subscriber = interfaces.Subscriber;

pub const State = Subscriber.State;

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

/// Getter for active
pub fn get_active(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for signal
pub fn get_signal(instance: *runtime.Instance) ImplError!interfaces.AbortSignal {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: error
pub fn call_error(instance: *runtime.Instance, @"error": *const anyopaque) ImplError!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}

/// Operation: complete
pub fn call_complete(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: addTeardown
pub fn call_addTeardown(instance: *runtime.Instance, teardown: callbacks.VoidFunction) ImplError!void {
    _ = instance;
    _ = teardown;
    return error.NotImplemented;
}

/// Operation: next
pub fn call_next(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

