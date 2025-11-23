//! Implementation for GPUAdapter interface
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
const GPUAdapter = interfaces.GPUAdapter;

pub const State = GPUAdapter.State;

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

/// Getter for features
pub fn get_features(instance: *runtime.Instance) ImplError!interfaces.GPUSupportedFeatures {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for limits
pub fn get_limits(instance: *runtime.Instance) ImplError!interfaces.GPUSupportedLimits {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for info
pub fn get_info(instance: *runtime.Instance) ImplError!interfaces.GPUAdapterInfo {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: requestDevice
pub fn call_requestDevice(instance: *runtime.Instance, descriptor: dictionaries.GPUDeviceDescriptor) ImplError!*const anyopaque {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

