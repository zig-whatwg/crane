//! Implementation for MediaKeys interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeys = @import("interfaces").MediaKeys;

pub const State = MediaKeys.State;

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

/// Operation: createSession
pub fn call_createSession(instance: *runtime.Instance, sessionType: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sessionType;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getStatusForPolicy
pub fn call_getStatusForPolicy(instance: *runtime.Instance, policy: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = policy;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setServerCertificate
pub fn call_setServerCertificate(instance: *runtime.Instance, serverCertificate: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = serverCertificate;
    // TODO: Implement operation
    return error.NotImplemented;
}

