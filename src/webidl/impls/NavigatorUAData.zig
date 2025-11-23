//! Implementation for NavigatorUAData interface
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
const NavigatorUAData = interfaces.NavigatorUAData;

pub const State = NavigatorUAData.State;

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

/// Getter for brands
pub fn get_brands(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mobile
pub fn get_mobile(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for platform
pub fn get_platform(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getHighEntropyValues
pub fn call_getHighEntropyValues(instance: *runtime.Instance, hints: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = hints;
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!dictionaries.UALowEntropyJSON {
    _ = instance;
    return error.NotImplemented;
}

