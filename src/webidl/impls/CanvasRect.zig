//! Implementation for CanvasRect interface
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
const CanvasRect = interfaces.CanvasRect;

pub const State = CanvasRect.State;

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

/// Operation: clearRect
pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    return error.NotImplemented;
}

/// Operation: fillRect
pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    return error.NotImplemented;
}

/// Operation: strokeRect
pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    return error.NotImplemented;
}

