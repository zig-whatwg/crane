//! Implementation for WebGLRenderingContextOverloads interface
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
const WebGLRenderingContextOverloads = interfaces.WebGLRenderingContextOverloads;

pub const State = WebGLRenderingContextOverloads.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Operation: bufferData
pub fn call_bufferData(instance: *runtime.Instance, target: typedefs.GLenum, size: typedefs.GLsizeiptr, usage: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = target;
    _ = size;
    _ = usage;
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage2D
pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, data: typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = data;
    return error.NotImplemented;
}

/// Operation: texSubImage2D
pub fn call_texSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, @"type": typedefs.GLenum, pixels: typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = @"type";
    _ = pixels;
    return error.NotImplemented;
}

/// Operation: readPixels
pub fn call_readPixels(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, @"type": typedefs.GLenum, pixels: typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = format;
    _ = @"type";
    _ = pixels;
    return error.NotImplemented;
}

/// Operation: uniformMatrix2fv
pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, transpose: typedefs.GLboolean, value: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    return error.NotImplemented;
}

/// Operation: uniform4fv
pub fn call_uniform4fv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

/// Operation: uniform2fv
pub fn call_uniform2fv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

/// Operation: bufferSubData
pub fn call_bufferSubData(instance: *runtime.Instance, target: typedefs.GLenum, offset: typedefs.GLintptr, data: typedefs.AllowSharedBufferSource) ImplError!void {
    _ = instance;
    _ = target;
    _ = offset;
    _ = data;
    return error.NotImplemented;
}

/// Operation: uniform4iv
pub fn call_uniform4iv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Int32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

/// Operation: uniformMatrix4fv
pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, transpose: typedefs.GLboolean, value: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    return error.NotImplemented;
}

/// Operation: texImage2D
pub fn call_texImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint, format: typedefs.GLenum, @"type": typedefs.GLenum, pixels: typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = format;
    _ = @"type";
    _ = pixels;
    return error.NotImplemented;
}

/// Operation: uniform1fv
pub fn call_uniform1fv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

/// Operation: compressedTexImage2D
pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint, data: typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = data;
    return error.NotImplemented;
}

/// Operation: uniform1iv
pub fn call_uniform1iv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Int32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

/// Operation: uniform2iv
pub fn call_uniform2iv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Int32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

/// Operation: uniformMatrix3fv
pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, transpose: typedefs.GLboolean, value: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    return error.NotImplemented;
}

/// Operation: uniform3iv
pub fn call_uniform3iv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Int32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

/// Operation: uniform3fv
pub fn call_uniform3fv(instance: *runtime.Instance, location: interfaces.WebGLUniformLocation, v: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    return error.NotImplemented;
}

