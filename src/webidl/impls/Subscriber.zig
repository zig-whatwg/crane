//! Implementation for Subscriber interface

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
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

/// Getter for active
pub fn get_active(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for signal
pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: error
pub fn call_error(instance: *runtime.Instance, @"error": runtime.JSValue) anyerror!void {
    _ = instance;
    _ = @"error";
    return error.NotImplemented;
}

/// Operation: complete
pub fn call_complete(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: addTeardown
pub fn call_addTeardown(instance: *runtime.Instance, teardown: callbacks.VoidFunction) anyerror!void {
    _ = instance;
    _ = teardown;
    return error.NotImplemented;
}

/// Operation: next
pub fn call_next(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
