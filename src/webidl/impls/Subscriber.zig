//! Implementation for Subscriber interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Subscriber = @import("interfaces").Subscriber;

pub const State = Subscriber.State;

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

/// Getter for active
pub fn get_active(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for signal
pub fn get_signal(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: next
pub fn call_next(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: error
pub fn call_error(instance: *runtime.Instance, error: anyopaque) ImplError!void {
    _ = instance;
    _ = error;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: complete
pub fn call_complete(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: addTeardown
pub fn call_addTeardown(instance: *runtime.Instance, teardown: anyopaque) ImplError!void {
    _ = instance;
    _ = teardown;
    // TODO: Implement operation
    return error.NotImplemented;
}

