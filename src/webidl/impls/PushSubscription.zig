//! Implementation for PushSubscription interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const PushSubscription = @import("interfaces").PushSubscription;

pub const State = PushSubscription.State;

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

/// Getter for endpoint
pub fn get_endpoint(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for expirationTime
pub fn get_expirationTime(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for options
pub fn get_options(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: getKey
pub fn call_getKey(instance: *runtime.Instance, name: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unsubscribe
pub fn call_unsubscribe(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

