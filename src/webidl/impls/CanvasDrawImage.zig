//! Implementation for CanvasDrawImage interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasDrawImage = @import("interfaces").CanvasDrawImage;

pub const State = CanvasDrawImage.State;

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

/// Operation: drawImage
pub fn call_drawImage(instance: *runtime.Instance, image: anyopaque, dx: f64, dy: f64) ImplError!void {
    _ = instance;
    _ = image;
    _ = dx;
    _ = dy;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawImage
pub fn call_drawImage(instance: *runtime.Instance, image: anyopaque, dx: f64, dy: f64, dw: f64, dh: f64) ImplError!void {
    _ = instance;
    _ = image;
    _ = dx;
    _ = dy;
    _ = dw;
    _ = dh;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawImage
pub fn call_drawImage(instance: *runtime.Instance, image: anyopaque, sx: f64, sy: f64, sw: f64, sh: f64, dx: f64, dy: f64, dw: f64, dh: f64) ImplError!void {
    _ = instance;
    _ = image;
    _ = sx;
    _ = sy;
    _ = sw;
    _ = sh;
    _ = dx;
    _ = dy;
    _ = dw;
    _ = dh;
    // TODO: Implement operation
    return error.NotImplemented;
}

