//! Implementation for WebGL2RenderingContextOverloads interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebGL2RenderingContextOverloads = @import("interfaces").WebGL2RenderingContextOverloads;

pub const State = WebGL2RenderingContextOverloads.State;

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
pub fn call_bufferData(instance: *runtime.Instance, target: anyopaque, srcData: anyopaque, usage: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = srcData;
    _ = usage;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bufferSubData
pub fn call_bufferSubData(instance: *runtime.Instance, target: anyopaque, dstByteOffset: anyopaque, srcData: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = dstByteOffset;
    _ = srcData;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bufferData
pub fn call_bufferData(instance: *runtime.Instance, target: anyopaque, srcData: anyopaque, usage: anyopaque, srcOffset: u64, length: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = srcData;
    _ = usage;
    _ = srcOffset;
    _ = length;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bufferSubData
pub fn call_bufferSubData(instance: *runtime.Instance, target: anyopaque, dstByteOffset: anyopaque, srcData: anyopaque, srcOffset: u64, length: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = dstByteOffset;
    _ = srcData;
    _ = srcOffset;
    _ = length;
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

/// Operation: texImage2D
pub fn call_texImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, pboOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = format;
    _ = type;
    _ = pboOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage2D
pub fn call_texImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, source: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = format;
    _ = type;
    _ = source;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage2D
pub fn call_texImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, srcData: anyopaque, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = format;
    _ = type;
    _ = srcData;
    _ = srcOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage2D
pub fn call_texSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, pboOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = pboOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage2D
pub fn call_texSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, source: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = source;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage2D
pub fn call_texSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, srcData: anyopaque, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = srcData;
    _ = srcOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexImage2D
pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, imageSize: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = imageSize;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexImage2D
pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, srcData: anyopaque, srcOffset: u64, srcLengthOverride: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = srcData;
    _ = srcOffset;
    _ = srcLengthOverride;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage2D
pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, imageSize: anyopaque, offset: anyopaque) ImplError!void {
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
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage2D
pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, srcData: anyopaque, srcOffset: u64, srcLengthOverride: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = srcData;
    _ = srcOffset;
    _ = srcLengthOverride;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1fv
pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2fv
pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3fv
pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4fv
pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1iv
pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2iv
pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3iv
pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4iv
pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix2fv
pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix3fv
pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix4fv
pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readPixels
pub fn call_readPixels(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, dstData: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = dstData;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readPixels
pub fn call_readPixels(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readPixels
pub fn call_readPixels(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, dstData: anyopaque, dstOffset: u64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = dstData;
    _ = dstOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

