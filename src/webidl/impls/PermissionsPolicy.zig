//! Implementation for PermissionsPolicy interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsPolicy = @import("interfaces").PermissionsPolicy;

pub const State = PermissionsPolicy.State;

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

/// Operation: allowsFeature
pub fn call_allowsFeature(instance: *runtime.Instance, feature: runtime.DOMString, origin: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = feature;
    _ = origin;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: features
pub fn call_features(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: allowedFeatures
pub fn call_allowedFeatures(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAllowlistForFeature
pub fn call_getAllowlistForFeature(instance: *runtime.Instance, feature: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = feature;
    // TODO: Implement operation
    return error.NotImplemented;
}

