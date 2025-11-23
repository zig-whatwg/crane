//! Implementation for XRWebGLSubImage interface
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
const XRWebGLSubImage = interfaces.XRWebGLSubImage;

pub const State = XRWebGLSubImage.State;

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

/// Getter for colorTexture
pub fn get_colorTexture(instance: *runtime.Instance) ImplError!interfaces.WebGLTexture {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for depthStencilTexture
pub fn get_depthStencilTexture(instance: *runtime.Instance) ImplError!interfaces.WebGLTexture {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for motionVectorTexture
pub fn get_motionVectorTexture(instance: *runtime.Instance) ImplError!interfaces.WebGLTexture {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for imageIndex
pub fn get_imageIndex(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for colorTextureWidth
pub fn get_colorTextureWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for colorTextureHeight
pub fn get_colorTextureHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for depthStencilTextureWidth
pub fn get_depthStencilTextureWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for depthStencilTextureHeight
pub fn get_depthStencilTextureHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for motionVectorTextureWidth
pub fn get_motionVectorTextureWidth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for motionVectorTextureHeight
pub fn get_motionVectorTextureHeight(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

