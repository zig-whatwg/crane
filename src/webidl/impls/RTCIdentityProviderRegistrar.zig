//! Implementation for RTCIdentityProviderRegistrar interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const RTCIdentityProviderRegistrar = @import("interfaces").RTCIdentityProviderRegistrar;

pub const State = RTCIdentityProviderRegistrar.State;

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

/// Operation: register
pub fn call_register(instance: *runtime.Instance, idp: anyopaque) ImplError!void {
    _ = instance;
    _ = idp;
    // TODO: Implement operation
    return error.NotImplemented;
}

