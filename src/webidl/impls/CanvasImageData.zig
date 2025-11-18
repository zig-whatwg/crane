//! Implementation for CanvasImageData interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasImageData = @import("interfaces").CanvasImageData;

pub const State = CanvasImageData.State;

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

/// Operation: createImageData
pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sw;
    _ = sh;
    _ = settings;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createImageData
pub fn call_createImageData(instance: *runtime.Instance, imageData: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = imageData;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getImageData
pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sx;
    _ = sy;
    _ = sw;
    _ = sh;
    _ = settings;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: putImageData
pub fn call_putImageData(instance: *runtime.Instance, imageData: anyopaque, dx: i32, dy: i32) ImplError!void {
    _ = instance;
    _ = imageData;
    _ = dx;
    _ = dy;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: putImageData
pub fn call_putImageData(instance: *runtime.Instance, imageData: anyopaque, dx: i32, dy: i32, dirtyX: i32, dirtyY: i32, dirtyWidth: i32, dirtyHeight: i32) ImplError!void {
    _ = instance;
    _ = imageData;
    _ = dx;
    _ = dy;
    _ = dirtyX;
    _ = dirtyY;
    _ = dirtyWidth;
    _ = dirtyHeight;
    // TODO: Implement operation
    return error.NotImplemented;
}

