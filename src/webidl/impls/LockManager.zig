//! Implementation for LockManager interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const LockManager = @import("interfaces").LockManager;

pub const State = LockManager.State;

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

/// Operation: request
pub fn call_request(instance: *runtime.Instance, name: runtime.DOMString, callback: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = name;
    _ = callback;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: request
pub fn call_request(instance: *runtime.Instance, name: runtime.DOMString, options: anyopaque, callback: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = name;
    _ = options;
    _ = callback;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: query
pub fn call_query(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

