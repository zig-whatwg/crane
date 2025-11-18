//! Implementation for VideoFrame interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const VideoFrame = @import("interfaces").VideoFrame;

pub const State = VideoFrame.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance, image: anyopaque, init: anyopaque) !void {
    _ = instance;
    _ = image;
    _ = init;
    // TODO: Implement constructor logic
}

/// Getter for format
pub fn get_format(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for codedWidth
pub fn get_codedWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for codedHeight
pub fn get_codedHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for codedRect
pub fn get_codedRect(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for visibleRect
pub fn get_visibleRect(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for rotation
pub fn get_rotation(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for flip
pub fn get_flip(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for displayWidth
pub fn get_displayWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for displayHeight
pub fn get_displayHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for duration
pub fn get_duration(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for timestamp
pub fn get_timestamp(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for colorSpace
pub fn get_colorSpace(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: metadata
pub fn call_metadata(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: allocationSize
pub fn call_allocationSize(instance: *runtime.Instance, options: anyopaque) ImplError!u32 {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyTo
pub fn call_copyTo(instance: *runtime.Instance, destination: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = destination;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clone
pub fn call_clone(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

