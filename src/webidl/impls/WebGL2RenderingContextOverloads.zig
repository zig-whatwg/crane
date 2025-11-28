//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for WebGL2RenderingContextOverloads interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Remove this header comment block
//!   3. Add your implementation logic
//!   4. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const WebGL2RenderingContextOverloads = interfaces.WebGL2RenderingContextOverloads;

pub const State = WebGL2RenderingContextOverloads.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
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
pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, imageSize: typedefs.GLsizei, offset: typedefs.GLintptr) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = imageSize;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: texSubImage2D
pub fn call_texSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, @"type": typedefs.GLenum, pixels: ?typedefs.ArrayBufferView) ImplError!void {
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

/// Operation: uniformMatrix2fv
pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: readPixels
pub fn call_readPixels(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, @"type": typedefs.GLenum, dstData: ?typedefs.ArrayBufferView) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = format;
    _ = @"type";
    _ = dstData;
    return error.NotImplemented;
}

/// Operation: uniform4fv
pub fn call_uniform4fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniform2fv
pub fn call_uniform2fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: bufferSubData
pub fn call_bufferSubData(instance: *runtime.Instance, target: typedefs.GLenum, dstByteOffset: typedefs.GLintptr, srcData: typedefs.AllowSharedBufferSource) ImplError!void {
    _ = instance;
    _ = target;
    _ = dstByteOffset;
    _ = srcData;
    return error.NotImplemented;
}

/// Operation: uniform4iv
pub fn call_uniform4iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniformMatrix4fv
pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: texImage2D
pub fn call_texImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint, format: typedefs.GLenum, @"type": typedefs.GLenum, pixels: ?typedefs.ArrayBufferView) ImplError!void {
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
pub fn call_uniform1fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: compressedTexImage2D
pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint, imageSize: typedefs.GLsizei, offset: typedefs.GLintptr) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = imageSize;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: uniform1iv
pub fn call_uniform1iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniform2iv
pub fn call_uniform2iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniformMatrix3fv
pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniform3iv
pub fn call_uniform3iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniform3fv
pub fn call_uniform3fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

