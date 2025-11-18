//! Implementation for MediaCapabilities interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const MediaCapabilities = @import("interfaces").MediaCapabilities;

pub const State = MediaCapabilities.State;

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

/// Operation: decodingInfo
pub fn call_decodingInfo(instance: *runtime.Instance, configuration: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = configuration;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: encodingInfo
pub fn call_encodingInfo(instance: *runtime.Instance, configuration: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = configuration;
    // TODO: Implement operation
    return error.NotImplemented;
}

