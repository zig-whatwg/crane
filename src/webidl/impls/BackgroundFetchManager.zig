//! Implementation for BackgroundFetchManager interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchManager = @import("interfaces").BackgroundFetchManager;

pub const State = BackgroundFetchManager.State;

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

/// Operation: fetch
pub fn call_fetch(instance: *runtime.Instance, id: runtime.DOMString, requests: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = id;
    _ = requests;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, id: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = id;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getIds
pub fn call_getIds(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

