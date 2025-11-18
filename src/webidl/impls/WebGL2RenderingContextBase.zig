//! Implementation for WebGL2RenderingContextBase interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebGL2RenderingContextBase = @import("interfaces").WebGL2RenderingContextBase;

pub const State = WebGL2RenderingContextBase.State;

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

/// Operation: copyBufferSubData
pub fn call_copyBufferSubData(instance: *runtime.Instance, readTarget: anyopaque, writeTarget: anyopaque, readOffset: anyopaque, writeOffset: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = readTarget;
    _ = writeTarget;
    _ = readOffset;
    _ = writeOffset;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getBufferSubData
pub fn call_getBufferSubData(instance: *runtime.Instance, target: anyopaque, srcByteOffset: anyopaque, dstBuffer: anyopaque, dstOffset: u64, length: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = srcByteOffset;
    _ = dstBuffer;
    _ = dstOffset;
    _ = length;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blitFramebuffer
pub fn call_blitFramebuffer(instance: *runtime.Instance, srcX0: anyopaque, srcY0: anyopaque, srcX1: anyopaque, srcY1: anyopaque, dstX0: anyopaque, dstY0: anyopaque, dstX1: anyopaque, dstY1: anyopaque, mask: anyopaque, filter: anyopaque) ImplError!void {
    _ = instance;
    _ = srcX0;
    _ = srcY0;
    _ = srcX1;
    _ = srcY1;
    _ = dstX0;
    _ = dstY0;
    _ = dstX1;
    _ = dstY1;
    _ = mask;
    _ = filter;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: framebufferTextureLayer
pub fn call_framebufferTextureLayer(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, texture: anyopaque, level: anyopaque, layer: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = texture;
    _ = level;
    _ = layer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: invalidateFramebuffer
pub fn call_invalidateFramebuffer(instance: *runtime.Instance, target: anyopaque, attachments: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachments;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: invalidateSubFramebuffer
pub fn call_invalidateSubFramebuffer(instance: *runtime.Instance, target: anyopaque, attachments: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachments;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readBuffer
pub fn call_readBuffer(instance: *runtime.Instance, src: anyopaque) ImplError!void {
    _ = instance;
    _ = src;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getInternalformatParameter
pub fn call_getInternalformatParameter(instance: *runtime.Instance, target: anyopaque, internalformat: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = internalformat;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: renderbufferStorageMultisample
pub fn call_renderbufferStorageMultisample(instance: *runtime.Instance, target: anyopaque, samples: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = samples;
    _ = internalformat;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texStorage2D
pub fn call_texStorage2D(instance: *runtime.Instance, target: anyopaque, levels: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = levels;
    _ = internalformat;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texStorage3D
pub fn call_texStorage3D(instance: *runtime.Instance, target: anyopaque, levels: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = levels;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage3D
pub fn call_texImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, pboOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    _ = border;
    _ = format;
    _ = type;
    _ = pboOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage3D
pub fn call_texImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, source: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    _ = border;
    _ = format;
    _ = type;
    _ = source;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage3D
pub fn call_texImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, srcData: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    _ = border;
    _ = format;
    _ = type;
    _ = srcData;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texImage3D
pub fn call_texImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, border: anyopaque, format: anyopaque, type: anyopaque, srcData: anyopaque, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    _ = border;
    _ = format;
    _ = type;
    _ = srcData;
    _ = srcOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage3D
pub fn call_texSubImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, zoffset: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, format: anyopaque, type: anyopaque, pboOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = zoffset;
    _ = width;
    _ = height;
    _ = depth;
    _ = format;
    _ = type;
    _ = pboOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage3D
pub fn call_texSubImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, zoffset: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, format: anyopaque, type: anyopaque, source: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = zoffset;
    _ = width;
    _ = height;
    _ = depth;
    _ = format;
    _ = type;
    _ = source;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texSubImage3D
pub fn call_texSubImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, zoffset: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, format: anyopaque, type: anyopaque, srcData: anyopaque, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = zoffset;
    _ = width;
    _ = height;
    _ = depth;
    _ = format;
    _ = type;
    _ = srcData;
    _ = srcOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyTexSubImage3D
pub fn call_copyTexSubImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, zoffset: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = zoffset;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexImage3D
pub fn call_compressedTexImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, border: anyopaque, imageSize: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    _ = border;
    _ = imageSize;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexImage3D
pub fn call_compressedTexImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, border: anyopaque, srcData: anyopaque, srcOffset: u64, srcLengthOverride: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    _ = border;
    _ = srcData;
    _ = srcOffset;
    _ = srcLengthOverride;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage3D
pub fn call_compressedTexSubImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, zoffset: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, format: anyopaque, imageSize: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = zoffset;
    _ = width;
    _ = height;
    _ = depth;
    _ = format;
    _ = imageSize;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage3D
pub fn call_compressedTexSubImage3D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, zoffset: anyopaque, width: anyopaque, height: anyopaque, depth: anyopaque, format: anyopaque, srcData: anyopaque, srcOffset: u64, srcLengthOverride: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = zoffset;
    _ = width;
    _ = height;
    _ = depth;
    _ = format;
    _ = srcData;
    _ = srcOffset;
    _ = srcLengthOverride;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getFragDataLocation
pub fn call_getFragDataLocation(instance: *runtime.Instance, program: anyopaque, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1ui
pub fn call_uniform1ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2ui
pub fn call_uniform2ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque, v1: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3ui
pub fn call_uniform3ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque, v1: anyopaque, v2: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    _ = v2;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4ui
pub fn call_uniform4ui(instance: *runtime.Instance, location: anyopaque, v0: anyopaque, v1: anyopaque, v2: anyopaque, v3: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    _ = v2;
    _ = v3;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1uiv
pub fn call_uniform1uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2uiv
pub fn call_uniform2uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3uiv
pub fn call_uniform3uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4uiv
pub fn call_uniform4uiv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix3x2fv
pub fn call_uniformMatrix3x2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix4x2fv
pub fn call_uniformMatrix4x2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix2x3fv
pub fn call_uniformMatrix2x3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix4x3fv
pub fn call_uniformMatrix4x3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix2x4fv
pub fn call_uniformMatrix2x4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix3x4fv
pub fn call_uniformMatrix3x4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribI4i
pub fn call_vertexAttribI4i(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribI4iv
pub fn call_vertexAttribI4iv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribI4ui
pub fn call_vertexAttribI4ui(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribI4uiv
pub fn call_vertexAttribI4uiv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribIPointer
pub fn call_vertexAttribIPointer(instance: *runtime.Instance, index: anyopaque, size: anyopaque, type: anyopaque, stride: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = size;
    _ = type;
    _ = stride;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribDivisor
pub fn call_vertexAttribDivisor(instance: *runtime.Instance, index: anyopaque, divisor: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = divisor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawArraysInstanced
pub fn call_drawArraysInstanced(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque, instanceCount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    _ = instanceCount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawElementsInstanced
pub fn call_drawElementsInstanced(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type: anyopaque, offset: anyopaque, instanceCount: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = type;
    _ = offset;
    _ = instanceCount;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawRangeElements
pub fn call_drawRangeElements(instance: *runtime.Instance, mode: anyopaque, start: anyopaque, end: anyopaque, count: anyopaque, type: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = start;
    _ = end;
    _ = count;
    _ = type;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawBuffers
pub fn call_drawBuffers(instance: *runtime.Instance, buffers: anyopaque) ImplError!void {
    _ = instance;
    _ = buffers;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearBufferfv
pub fn call_clearBufferfv(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, values: anyopaque, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearBufferiv
pub fn call_clearBufferiv(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, values: anyopaque, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearBufferuiv
pub fn call_clearBufferuiv(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, values: anyopaque, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearBufferfi
pub fn call_clearBufferfi(instance: *runtime.Instance, buffer: anyopaque, drawbuffer: anyopaque, depth: anyopaque, stencil: anyopaque) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = depth;
    _ = stencil;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createQuery
pub fn call_createQuery(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteQuery
pub fn call_deleteQuery(instance: *runtime.Instance, query: anyopaque) ImplError!void {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isQuery
pub fn call_isQuery(instance: *runtime.Instance, query: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: beginQuery
pub fn call_beginQuery(instance: *runtime.Instance, target: anyopaque, query: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: endQuery
pub fn call_endQuery(instance: *runtime.Instance, target: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getQuery
pub fn call_getQuery(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getQueryParameter
pub fn call_getQueryParameter(instance: *runtime.Instance, query: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createSampler
pub fn call_createSampler(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteSampler
pub fn call_deleteSampler(instance: *runtime.Instance, sampler: anyopaque) ImplError!void {
    _ = instance;
    _ = sampler;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isSampler
pub fn call_isSampler(instance: *runtime.Instance, sampler: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sampler;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindSampler
pub fn call_bindSampler(instance: *runtime.Instance, unit: anyopaque, sampler: anyopaque) ImplError!void {
    _ = instance;
    _ = unit;
    _ = sampler;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: samplerParameteri
pub fn call_samplerParameteri(instance: *runtime.Instance, sampler: anyopaque, pname: anyopaque, param: anyopaque) ImplError!void {
    _ = instance;
    _ = sampler;
    _ = pname;
    _ = param;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: samplerParameterf
pub fn call_samplerParameterf(instance: *runtime.Instance, sampler: anyopaque, pname: anyopaque, param: anyopaque) ImplError!void {
    _ = instance;
    _ = sampler;
    _ = pname;
    _ = param;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getSamplerParameter
pub fn call_getSamplerParameter(instance: *runtime.Instance, sampler: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sampler;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: fenceSync
pub fn call_fenceSync(instance: *runtime.Instance, condition: anyopaque, flags: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = condition;
    _ = flags;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isSync
pub fn call_isSync(instance: *runtime.Instance, sync: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sync;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteSync
pub fn call_deleteSync(instance: *runtime.Instance, sync: anyopaque) ImplError!void {
    _ = instance;
    _ = sync;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clientWaitSync
pub fn call_clientWaitSync(instance: *runtime.Instance, sync: anyopaque, flags: anyopaque, timeout: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sync;
    _ = flags;
    _ = timeout;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: waitSync
pub fn call_waitSync(instance: *runtime.Instance, sync: anyopaque, flags: anyopaque, timeout: anyopaque) ImplError!void {
    _ = instance;
    _ = sync;
    _ = flags;
    _ = timeout;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getSyncParameter
pub fn call_getSyncParameter(instance: *runtime.Instance, sync: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sync;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createTransformFeedback
pub fn call_createTransformFeedback(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteTransformFeedback
pub fn call_deleteTransformFeedback(instance: *runtime.Instance, tf: anyopaque) ImplError!void {
    _ = instance;
    _ = tf;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isTransformFeedback
pub fn call_isTransformFeedback(instance: *runtime.Instance, tf: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = tf;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindTransformFeedback
pub fn call_bindTransformFeedback(instance: *runtime.Instance, target: anyopaque, tf: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = tf;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: beginTransformFeedback
pub fn call_beginTransformFeedback(instance: *runtime.Instance, primitiveMode: anyopaque) ImplError!void {
    _ = instance;
    _ = primitiveMode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: endTransformFeedback
pub fn call_endTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: transformFeedbackVaryings
pub fn call_transformFeedbackVaryings(instance: *runtime.Instance, program: anyopaque, varyings: anyopaque, bufferMode: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    _ = varyings;
    _ = bufferMode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getTransformFeedbackVarying
pub fn call_getTransformFeedbackVarying(instance: *runtime.Instance, program: anyopaque, index: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pauseTransformFeedback
pub fn call_pauseTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: resumeTransformFeedback
pub fn call_resumeTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindBufferBase
pub fn call_bindBufferBase(instance: *runtime.Instance, target: anyopaque, index: anyopaque, buffer: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    _ = buffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindBufferRange
pub fn call_bindBufferRange(instance: *runtime.Instance, target: anyopaque, index: anyopaque, buffer: anyopaque, offset: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    _ = buffer;
    _ = offset;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getIndexedParameter
pub fn call_getIndexedParameter(instance: *runtime.Instance, target: anyopaque, index: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getUniformIndices
pub fn call_getUniformIndices(instance: *runtime.Instance, program: anyopaque, uniformNames: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = uniformNames;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getActiveUniforms
pub fn call_getActiveUniforms(instance: *runtime.Instance, program: anyopaque, uniformIndices: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = uniformIndices;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getUniformBlockIndex
pub fn call_getUniformBlockIndex(instance: *runtime.Instance, program: anyopaque, uniformBlockName: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = uniformBlockName;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getActiveUniformBlockParameter
pub fn call_getActiveUniformBlockParameter(instance: *runtime.Instance, program: anyopaque, uniformBlockIndex: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = uniformBlockIndex;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getActiveUniformBlockName
pub fn call_getActiveUniformBlockName(instance: *runtime.Instance, program: anyopaque, uniformBlockIndex: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = uniformBlockIndex;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformBlockBinding
pub fn call_uniformBlockBinding(instance: *runtime.Instance, program: anyopaque, uniformBlockIndex: anyopaque, uniformBlockBinding: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    _ = uniformBlockIndex;
    _ = uniformBlockBinding;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createVertexArray
pub fn call_createVertexArray(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteVertexArray
pub fn call_deleteVertexArray(instance: *runtime.Instance, vertexArray: anyopaque) ImplError!void {
    _ = instance;
    _ = vertexArray;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isVertexArray
pub fn call_isVertexArray(instance: *runtime.Instance, vertexArray: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = vertexArray;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindVertexArray
pub fn call_bindVertexArray(instance: *runtime.Instance, array: anyopaque) ImplError!void {
    _ = instance;
    _ = array;
    // TODO: Implement operation
    return error.NotImplemented;
}

