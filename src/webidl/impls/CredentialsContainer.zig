//! Implementation for CredentialsContainer interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CredentialsContainer = interfaces.CredentialsContainer;

pub const State = CredentialsContainer.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Operation: store
pub fn call_store(instance: *runtime.Instance, credential: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    _ = credential;
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, options: dictionaries.CredentialRequestOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: preventSilentAccess
pub fn call_preventSilentAccess(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: create
pub fn call_create(instance: *runtime.Instance, options: dictionaries.CredentialCreationOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

