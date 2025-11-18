//! Implementation for Permissions interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Permissions = @import("interfaces").Permissions;

pub const State = Permissions.State;

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

/// Operation: query
pub fn call_query(instance: *runtime.Instance, permissionDesc: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = permissionDesc;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: request
pub fn call_request(instance: *runtime.Instance, permissionDesc: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = permissionDesc;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: revoke
pub fn call_revoke(instance: *runtime.Instance, permissionDesc: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = permissionDesc;
    // TODO: Implement operation
    return error.NotImplemented;
}

