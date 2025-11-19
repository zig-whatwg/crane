//! Implementation for CanvasRect interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CanvasRect = @import("interfaces").CanvasRect;

pub const State = CanvasRect.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (delegates to runtime.Instance.init)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable);
    // TODO: Add custom initialization here if needed
    // const state = instance.getState(StateType);
    // state.* = .{}; // Initialize fields
    return instance;
}

/// Deinitialize instance (delegates to runtime.Instance.deinit)
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Add custom cleanup here if needed
    // const state = instance.getState(State);
    // Clean up fields...
    runtime.Instance.deinit(instance);
}

/// Operation: clearRect
pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fillRect
pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: strokeRect
pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    // TODO: Implement operation
    return error.NotImplemented;
}

