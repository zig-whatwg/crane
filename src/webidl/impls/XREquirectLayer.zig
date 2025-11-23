//! Implementation for XREquirectLayer interface
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
const XREquirectLayer = interfaces.XREquirectLayer;

pub const State = XREquirectLayer.State;

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

/// Getter for space
pub fn get_space(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for transform
pub fn get_transform(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for radius
pub fn get_radius(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for centralHorizontalAngle
pub fn get_centralHorizontalAngle(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for upperVerticalAngle
pub fn get_upperVerticalAngle(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lowerVerticalAngle
pub fn get_lowerVerticalAngle(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onredraw
pub fn get_onredraw(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for space
pub fn set_space(instance: *runtime.Instance, value: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for transform
pub fn set_transform(instance: *runtime.Instance, value: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for radius
pub fn set_radius(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for centralHorizontalAngle
pub fn set_centralHorizontalAngle(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for upperVerticalAngle
pub fn set_upperVerticalAngle(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lowerVerticalAngle
pub fn set_lowerVerticalAngle(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onredraw
pub fn set_onredraw(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

