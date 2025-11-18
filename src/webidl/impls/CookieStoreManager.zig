//! Implementation for CookieStoreManager interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CookieStoreManager = @import("interfaces").CookieStoreManager;

pub const State = CookieStoreManager.State;

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

/// Operation: subscribe
pub fn call_subscribe(instance: *runtime.Instance, subscriptions: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = subscriptions;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getSubscriptions
pub fn call_getSubscriptions(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unsubscribe
pub fn call_unsubscribe(instance: *runtime.Instance, subscriptions: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = subscriptions;
    // TODO: Implement operation
    return error.NotImplemented;
}

