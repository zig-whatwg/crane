//! Implementation for XRProjectionLayer interface
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
const XRProjectionLayer = interfaces.XRProjectionLayer;

pub const State = XRProjectionLayer.State;

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

/// Getter for textureWidth
pub fn get_textureWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textureHeight
pub fn get_textureHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textureArrayLength
pub fn get_textureArrayLength(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ignoreDepthValues
pub fn get_ignoreDepthValues(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fixedFoveation
pub fn get_fixedFoveation(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deltaPose
pub fn get_deltaPose(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for fixedFoveation
pub fn set_fixedFoveation(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for deltaPose
pub fn set_deltaPose(instance: *runtime.Instance, value: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

