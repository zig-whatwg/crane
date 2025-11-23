//! Implementation for CanvasImageData interface
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
const CanvasImageData = interfaces.CanvasImageData;

pub const State = CanvasImageData.State;

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

/// Operation: getImageData
pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: dictionaries.ImageDataSettings) ImplError!interfaces.ImageData {
    _ = instance;
    _ = sx;
    _ = sy;
    _ = sw;
    _ = sh;
    _ = settings;
    return error.NotImplemented;
}

/// Operation: createImageData
pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: dictionaries.ImageDataSettings) ImplError!interfaces.ImageData {
    _ = instance;
    _ = sw;
    _ = sh;
    _ = settings;
    return error.NotImplemented;
}

/// Operation: putImageData
pub fn call_putImageData(instance: *runtime.Instance, imageData: interfaces.ImageData, dx: i32, dy: i32) ImplError!void {
    _ = instance;
    _ = imageData;
    _ = dx;
    _ = dy;
    return error.NotImplemented;
}

