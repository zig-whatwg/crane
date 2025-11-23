//! Implementation for CanvasImageSmoothing interface
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
const CanvasImageSmoothing = interfaces.CanvasImageSmoothing;

pub const State = CanvasImageSmoothing.State;

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

/// Getter for imageSmoothingEnabled
pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for imageSmoothingQuality
pub fn get_imageSmoothingQuality(instance: *runtime.Instance) ImplError!enums.ImageSmoothingQuality {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for imageSmoothingEnabled
pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for imageSmoothingQuality
pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: enums.ImageSmoothingQuality) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

