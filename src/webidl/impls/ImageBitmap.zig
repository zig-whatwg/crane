//! Implementation for ImageBitmap interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const State = ImageBitmap.State;

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

/// Getter for width
pub fn get_width(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

