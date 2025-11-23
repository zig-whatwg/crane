//! Implementation for XRSystem interface
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
const XRSystem = interfaces.XRSystem;

pub const State = XRSystem.State;

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

/// Getter for ondevicechange
pub fn get_ondevicechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for ondevicechange
pub fn set_ondevicechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: requestSession
pub fn call_requestSession(instance: *runtime.Instance, mode: enums.XRSessionMode, options: dictionaries.XRSessionInit) ImplError!*const anyopaque {
    _ = instance;
    _ = mode;
    _ = options;
    return error.NotImplemented;
}

/// Operation: isSessionSupported
pub fn call_isSessionSupported(instance: *runtime.Instance, mode: enums.XRSessionMode) ImplError!*const anyopaque {
    _ = instance;
    _ = mode;
    return error.NotImplemented;
}

