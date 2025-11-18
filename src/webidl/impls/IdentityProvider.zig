//! Implementation for IdentityProvider interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const IdentityProvider = @import("interfaces").IdentityProvider;

pub const State = IdentityProvider.State;

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

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: resolve
pub fn call_resolve(instance: *runtime.Instance, token: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = token;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getUserInfo
pub fn call_getUserInfo(instance: *runtime.Instance, config: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = config;
    // TODO: Implement operation
    return error.NotImplemented;
}

