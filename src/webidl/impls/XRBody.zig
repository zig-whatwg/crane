//! Implementation for XRBody interface
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
const XRBody = interfaces.XRBody;

pub const State = XRBody.State;

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

/// Getter for size
pub fn get_size(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, key: enums.XRBodyJoint) ImplError!*runtime.Instance {
    _ = instance;
    _ = key;
    return error.NotImplemented;
}

/// Operation: forEach
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) ImplError!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

