//! Implementation for XRWebGLSubImage interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLSubImage = @import("interfaces").XRWebGLSubImage;

pub const State = XRWebGLSubImage.State;

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

/// Getter for viewport
pub fn get_viewport(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for colorTexture
pub fn get_colorTexture(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for depthStencilTexture
pub fn get_depthStencilTexture(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for motionVectorTexture
pub fn get_motionVectorTexture(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for imageIndex
pub fn get_imageIndex(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for colorTextureWidth
pub fn get_colorTextureWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for colorTextureHeight
pub fn get_colorTextureHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for depthStencilTextureWidth
pub fn get_depthStencilTextureWidth(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for depthStencilTextureHeight
pub fn get_depthStencilTextureHeight(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for motionVectorTextureWidth
pub fn get_motionVectorTextureWidth(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for motionVectorTextureHeight
pub fn get_motionVectorTextureHeight(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

