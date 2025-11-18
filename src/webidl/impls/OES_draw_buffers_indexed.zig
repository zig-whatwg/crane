//! Implementation for OES_draw_buffers_indexed interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const OES_draw_buffers_indexed = @import("interfaces").OES_draw_buffers_indexed;

pub const State = OES_draw_buffers_indexed.State;

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

/// Operation: enableiOES
pub fn call_enableiOES(instance: *runtime.Instance, target: anyopaque, index: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disableiOES
pub fn call_disableiOES(instance: *runtime.Instance, target: anyopaque, index: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendEquationiOES
pub fn call_blendEquationiOES(instance: *runtime.Instance, buf: anyopaque, mode: anyopaque) ImplError!void {
    _ = instance;
    _ = buf;
    _ = mode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendEquationSeparateiOES
pub fn call_blendEquationSeparateiOES(instance: *runtime.Instance, buf: anyopaque, modeRGB: anyopaque, modeAlpha: anyopaque) ImplError!void {
    _ = instance;
    _ = buf;
    _ = modeRGB;
    _ = modeAlpha;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendFunciOES
pub fn call_blendFunciOES(instance: *runtime.Instance, buf: anyopaque, src: anyopaque, dst: anyopaque) ImplError!void {
    _ = instance;
    _ = buf;
    _ = src;
    _ = dst;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendFuncSeparateiOES
pub fn call_blendFuncSeparateiOES(instance: *runtime.Instance, buf: anyopaque, srcRGB: anyopaque, dstRGB: anyopaque, srcAlpha: anyopaque, dstAlpha: anyopaque) ImplError!void {
    _ = instance;
    _ = buf;
    _ = srcRGB;
    _ = dstRGB;
    _ = srcAlpha;
    _ = dstAlpha;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: colorMaskiOES
pub fn call_colorMaskiOES(instance: *runtime.Instance, buf: anyopaque, r: anyopaque, g: anyopaque, b: anyopaque, a: anyopaque) ImplError!void {
    _ = instance;
    _ = buf;
    _ = r;
    _ = g;
    _ = b;
    _ = a;
    // TODO: Implement operation
    return error.NotImplemented;
}

