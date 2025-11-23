//! Implementation for PermissionsPolicy interface
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
const PermissionsPolicy = interfaces.PermissionsPolicy;

pub const State = PermissionsPolicy.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Operation: allowsFeature
pub fn call_allowsFeature(instance: *runtime.Instance, feature: runtime.DOMString, origin: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = feature;
    _ = origin;
    return error.NotImplemented;
}

/// Operation: allowedFeatures
pub fn call_allowedFeatures(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: features
pub fn call_features(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getAllowlistForFeature
pub fn call_getAllowlistForFeature(instance: *runtime.Instance, feature: runtime.DOMString) ImplError!*const anyopaque {
    _ = instance;
    _ = feature;
    return error.NotImplemented;
}

