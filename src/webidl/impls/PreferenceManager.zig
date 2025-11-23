//! Implementation for PreferenceManager interface
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
const PreferenceManager = interfaces.PreferenceManager;

pub const State = PreferenceManager.State;

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

/// Getter for colorScheme
pub fn get_colorScheme(instance: *runtime.Instance) ImplError!interfaces.PreferenceObject {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for contrast
pub fn get_contrast(instance: *runtime.Instance) ImplError!interfaces.PreferenceObject {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for reducedMotion
pub fn get_reducedMotion(instance: *runtime.Instance) ImplError!interfaces.PreferenceObject {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for reducedTransparency
pub fn get_reducedTransparency(instance: *runtime.Instance) ImplError!interfaces.PreferenceObject {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for reducedData
pub fn get_reducedData(instance: *runtime.Instance) ImplError!interfaces.PreferenceObject {
    _ = instance;
    return error.NotImplemented;
}

