//! Implementation for VideoFrame interface
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
const VideoFrame = interfaces.VideoFrame;

pub const State = VideoFrame.State;

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

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, image: typedefs.CanvasImageSource, init_data: dictionaries.VideoFrameInit) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &VideoFrame.vtable, ctx);
    errdefer deinit(instance);

    _ = image;
    _ = init_data;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for format
pub fn get_format(instance: *runtime.Instance) ImplError!enums.VideoPixelFormat {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for codedWidth
pub fn get_codedWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for codedHeight
pub fn get_codedHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for codedRect
pub fn get_codedRect(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for visibleRect
pub fn get_visibleRect(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rotation
pub fn get_rotation(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for flip
pub fn get_flip(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for displayWidth
pub fn get_displayWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for displayHeight
pub fn get_displayHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for duration
pub fn get_duration(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for timestamp
pub fn get_timestamp(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for colorSpace
pub fn get_colorSpace(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: allocationSize
pub fn call_allocationSize(instance: *runtime.Instance, options: dictionaries.VideoFrameCopyToOptions) ImplError!u32 {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: copyTo
pub fn call_copyTo(instance: *runtime.Instance, destination: typedefs.AllowSharedBufferSource, options: dictionaries.VideoFrameCopyToOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = destination;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clone
pub fn call_clone(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: metadata
pub fn call_metadata(instance: *runtime.Instance) ImplError!dictionaries.VideoFrameMetadata {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

