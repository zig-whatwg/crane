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

