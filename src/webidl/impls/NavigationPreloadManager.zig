//! Implementation for NavigationPreloadManager interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const NavigationPreloadManager = @import("interfaces").NavigationPreloadManager;

pub const State = NavigationPreloadManager.State;

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

/// Operation: enable
pub fn call_enable(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disable
pub fn call_disable(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setHeaderValue
pub fn call_setHeaderValue(instance: *runtime.Instance, value: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getState
pub fn call_getState(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

