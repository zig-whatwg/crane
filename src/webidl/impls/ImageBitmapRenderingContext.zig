//! Implementation for ImageBitmapRenderingContext interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ImageBitmapRenderingContext = @import("interfaces").ImageBitmapRenderingContext;

pub const State = ImageBitmapRenderingContext.State;

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

/// Getter for canvas
pub fn get_canvas(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: transferFromImageBitmap
pub fn call_transferFromImageBitmap(instance: *runtime.Instance, bitmap: anyopaque) ImplError!void {
    _ = instance;
    _ = bitmap;
    // TODO: Implement operation
    return error.NotImplemented;
}

