//! Implementation for WEBGL_debug_shaders interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_debug_shaders = @import("interfaces").WEBGL_debug_shaders;

pub const State = WEBGL_debug_shaders.State;

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

/// Operation: getTranslatedShaderSource
pub fn call_getTranslatedShaderSource(instance: *runtime.Instance, shader: anyopaque) ImplError!runtime.DOMString {
    _ = instance;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

