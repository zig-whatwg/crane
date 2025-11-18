//! Implementation for WebGLRenderingContextOverloads interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebGLRenderingContextOverloads = @import("interfaces").WebGLRenderingContextOverloads;

pub const State = WebGLRenderingContextOverloads.State;

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

/// Operation: bufferData
pub fn call_bufferData(instance: *runtime.Instance, target: anyopaque, size: anyopaque, usage: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = size;
    _ = usage;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bufferData
pub fn call_bufferData(instance: *runtime.Instance, target: anyopaque, data: anyopaque, usage: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = data;
    _ = usage;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bufferSubData
pub fn call_bufferSubData(instance: *runtime.Instance, target: anyopaque, offset: anyopaque, data: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = offset;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexImage2D
pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, data: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage2D
pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, data: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readPixels
pub fn call_readPixels(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, pixels: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = pixels;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage2D
pub fn call_texImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, pixels: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = format;
    _ = type;
    _ = pixels;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage2D
pub fn call_texImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, format: anyopaque, type: anyopaque, source: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = format;
    _ = type;
    _ = source;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage2D
pub fn call_texSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, pixels: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = pixels;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage2D
pub fn call_texSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, format: anyopaque, type: anyopaque, source: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = format;
    _ = type;
    _ = source;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1fv
pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2fv
pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3fv
pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4fv
pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1iv
pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2iv
pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3iv
pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4iv
pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix2fv
pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix3fv
pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix4fv
pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

