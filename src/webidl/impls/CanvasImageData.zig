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

/// Operation: createImageData
pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sw;
    _ = sh;
    _ = settings;
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

