//! Implementation for WebGL2RenderingContextBase interface
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
const WebGL2RenderingContextBase = interfaces.WebGL2RenderingContextBase;

pub const State = WebGL2RenderingContextBase.State;

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

/// Operation: resumeTransformFeedback
pub fn call_resumeTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: uniform4ui
pub fn call_uniform4ui(instance: *runtime.Instance, location: *runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint, v2: typedefs.GLuint, v3: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    _ = v2;
    _ = v3;
    return error.NotImplemented;
}

/// Operation: texStorage3D
pub fn call_texStorage3D(instance: *runtime.Instance, target: typedefs.GLenum, levels: typedefs.GLsizei, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei, depth: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = target;
    _ = levels;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    return error.NotImplemented;
}

/// Operation: vertexAttribDivisor
pub fn call_vertexAttribDivisor(instance: *runtime.Instance, index: typedefs.GLuint, divisor: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = index;
    _ = divisor;
    return error.NotImplemented;
}

/// Operation: uniformBlockBinding
pub fn call_uniformBlockBinding(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: typedefs.GLuint, uniformBlockBinding: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = program;
    _ = uniformBlockIndex;
    _ = uniformBlockBinding;
    return error.NotImplemented;
}

/// Operation: createTransformFeedback
pub fn call_createTransformFeedback(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getQuery
pub fn call_getQuery(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) ImplError!*runtime.Instance {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: createVertexArray
pub fn call_createVertexArray(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: readBuffer
pub fn call_readBuffer(instance: *runtime.Instance, src: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = src;
    return error.NotImplemented;
}

/// Operation: endTransformFeedback
pub fn call_endTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: clearBufferuiv
pub fn call_clearBufferuiv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Uint32List, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
    return error.NotImplemented;
}

/// Operation: getUniformIndices
pub fn call_getUniformIndices(instance: *runtime.Instance, program: *runtime.Instance, uniformNames: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = program;
    _ = uniformNames;
    return error.NotImplemented;
}

/// Operation: renderbufferStorageMultisample
pub fn call_renderbufferStorageMultisample(instance: *runtime.Instance, target: typedefs.GLenum, samples: typedefs.GLsizei, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = target;
    _ = samples;
    _ = internalformat;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: clearBufferfv
pub fn call_clearBufferfv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Float32List, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
    return error.NotImplemented;
}

/// Operation: clearBufferfi
pub fn call_clearBufferfi(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, depth: typedefs.GLfloat, stencil: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = depth;
    _ = stencil;
    return error.NotImplemented;
}

/// Operation: texImage3D
pub fn call_texImage3D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, depth: typedefs.GLsizei, border: typedefs.GLint, format: typedefs.GLenum, @"type": typedefs.GLenum, pboOffset: typedefs.GLintptr) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = depth;
    _ = border;
    _ = format;
    _ = @"type";
    _ = pboOffset;
    return error.NotImplemented;
}

/// Operation: texStorage2D
pub fn call_texStorage2D(instance: *runtime.Instance, target: typedefs.GLenum, levels: typedefs.GLsizei, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = target;
    _ = levels;
    _ = internalformat;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: clientWaitSync
pub fn call_clientWaitSync(instance: *runtime.Instance, sync: *runtime.Instance, flags: typedefs.GLbitfield, timeout: typedefs.GLuint64) ImplError!typedefs.GLenum {
    _ = instance;
    _ = sync;
    _ = flags;
    _ = timeout;
    return error.NotImplemented;
}

/// Operation: transformFeedbackVaryings
pub fn call_transformFeedbackVaryings(instance: *runtime.Instance, program: *runtime.Instance, varyings: *const anyopaque, bufferMode: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = program;
    _ = varyings;
    _ = bufferMode;
    return error.NotImplemented;
}

/// Operation: invalidateSubFramebuffer
pub fn call_invalidateSubFramebuffer(instance: *runtime.Instance, target: typedefs.GLenum, attachments: *const anyopaque, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachments;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: fenceSync
pub fn call_fenceSync(instance: *runtime.Instance, condition: typedefs.GLenum, flags: typedefs.GLbitfield) ImplError!*runtime.Instance {
    _ = instance;
    _ = condition;
    _ = flags;
    return error.NotImplemented;
}

/// Operation: deleteSampler
pub fn call_deleteSampler(instance: *runtime.Instance, sampler: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = sampler;
    return error.NotImplemented;
}

/// Operation: uniformMatrix2x3fv
pub fn call_uniformMatrix2x3fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniformMatrix4x3fv
pub fn call_uniformMatrix4x3fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniform2ui
pub fn call_uniform2ui(instance: *runtime.Instance, location: *runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    return error.NotImplemented;
}

/// Operation: getSyncParameter
pub fn call_getSyncParameter(instance: *runtime.Instance, sync: *runtime.Instance, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = sync;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: getUniformBlockIndex
pub fn call_getUniformBlockIndex(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockName: runtime.DOMString) ImplError!typedefs.GLuint {
    _ = instance;
    _ = program;
    _ = uniformBlockName;
    return error.NotImplemented;
}

/// Operation: copyTexSubImage3D
pub fn call_copyTexSubImage3D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, zoffset: typedefs.GLint, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
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
    return error.NotImplemented;
}

/// Operation: texSubImage3D
pub fn call_texSubImage3D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, zoffset: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, depth: typedefs.GLsizei, format: typedefs.GLenum, @"type": typedefs.GLenum, pboOffset: typedefs.GLintptr) ImplError!void {
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
    _ = @"type";
    _ = pboOffset;
    return error.NotImplemented;
}

/// Operation: clearBufferiv
pub fn call_clearBufferiv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Int32List, srcOffset: u64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
    return error.NotImplemented;
}

/// Operation: drawRangeElements
pub fn call_drawRangeElements(instance: *runtime.Instance, mode: typedefs.GLenum, start: typedefs.GLuint, end: typedefs.GLuint, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr) ImplError!void {
    _ = instance;
    _ = mode;
    _ = start;
    _ = end;
    _ = count;
    _ = @"type";
    _ = offset;
    return error.NotImplemented;
}

/// Operation: endQuery
pub fn call_endQuery(instance: *runtime.Instance, target: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = target;
    return error.NotImplemented;
}

/// Operation: framebufferTextureLayer
pub fn call_framebufferTextureLayer(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, texture: *runtime.Instance, level: typedefs.GLint, layer: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = texture;
    _ = level;
    _ = layer;
    return error.NotImplemented;
}

/// Operation: blitFramebuffer
pub fn call_blitFramebuffer(instance: *runtime.Instance, srcX0: typedefs.GLint, srcY0: typedefs.GLint, srcX1: typedefs.GLint, srcY1: typedefs.GLint, dstX0: typedefs.GLint, dstY0: typedefs.GLint, dstX1: typedefs.GLint, dstY1: typedefs.GLint, mask: typedefs.GLbitfield, filter: typedefs.GLenum) ImplError!void {
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
    return error.NotImplemented;
}

/// Operation: vertexAttribI4i
pub fn call_vertexAttribI4i(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint, w: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: drawElementsInstanced
pub fn call_drawElementsInstanced(instance: *runtime.Instance, mode: typedefs.GLenum, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr, instanceCount: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = @"type";
    _ = offset;
    _ = instanceCount;
    return error.NotImplemented;
}

/// Operation: vertexAttribI4uiv
pub fn call_vertexAttribI4uiv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Uint32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: isSampler
pub fn call_isSampler(instance: *runtime.Instance, sampler: *runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = sampler;
    return error.NotImplemented;
}

/// Operation: bindSampler
pub fn call_bindSampler(instance: *runtime.Instance, unit: typedefs.GLuint, sampler: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = unit;
    _ = sampler;
    return error.NotImplemented;
}

/// Operation: getSamplerParameter
pub fn call_getSamplerParameter(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = sampler;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: beginTransformFeedback
pub fn call_beginTransformFeedback(instance: *runtime.Instance, primitiveMode: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = primitiveMode;
    return error.NotImplemented;
}

/// Operation: isQuery
pub fn call_isQuery(instance: *runtime.Instance, query: *runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: pauseTransformFeedback
pub fn call_pauseTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: bindBufferBase
pub fn call_bindBufferBase(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint, buffer: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: uniform3uiv
pub fn call_uniform3uiv(instance: *runtime.Instance, location: *runtime.Instance, data: typedefs.Uint32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniformMatrix4x2fv
pub fn call_uniformMatrix4x2fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: getInternalformatParameter
pub fn call_getInternalformatParameter(instance: *runtime.Instance, target: typedefs.GLenum, internalformat: typedefs.GLenum, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = target;
    _ = internalformat;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: uniform4uiv
pub fn call_uniform4uiv(instance: *runtime.Instance, location: *runtime.Instance, data: typedefs.Uint32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: drawArraysInstanced
pub fn call_drawArraysInstanced(instance: *runtime.Instance, mode: typedefs.GLenum, first: typedefs.GLint, count: typedefs.GLsizei, instanceCount: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    _ = instanceCount;
    return error.NotImplemented;
}

/// Operation: vertexAttribI4ui
pub fn call_vertexAttribI4ui(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLuint, y: typedefs.GLuint, z: typedefs.GLuint, w: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: createQuery
pub fn call_createQuery(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getActiveUniformBlockName
pub fn call_getActiveUniformBlockName(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: typedefs.GLuint) ImplError!runtime.DOMString {
    _ = instance;
    _ = program;
    _ = uniformBlockIndex;
    return error.NotImplemented;
}

/// Operation: drawBuffers
pub fn call_drawBuffers(instance: *runtime.Instance, buffers: *const anyopaque) ImplError!void {
    _ = instance;
    _ = buffers;
    return error.NotImplemented;
}

/// Operation: isVertexArray
pub fn call_isVertexArray(instance: *runtime.Instance, vertexArray: *runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = vertexArray;
    return error.NotImplemented;
}

/// Operation: bindVertexArray
pub fn call_bindVertexArray(instance: *runtime.Instance, array: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = array;
    return error.NotImplemented;
}

/// Operation: deleteSync
pub fn call_deleteSync(instance: *runtime.Instance, sync: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = sync;
    return error.NotImplemented;
}

/// Operation: getBufferSubData
pub fn call_getBufferSubData(instance: *runtime.Instance, target: typedefs.GLenum, srcByteOffset: typedefs.GLintptr, dstBuffer: typedefs.ArrayBufferView, dstOffset: u64, length: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = target;
    _ = srcByteOffset;
    _ = dstBuffer;
    _ = dstOffset;
    _ = length;
    return error.NotImplemented;
}

/// Operation: getFragDataLocation
pub fn call_getFragDataLocation(instance: *runtime.Instance, program: *runtime.Instance, name: runtime.DOMString) ImplError!typedefs.GLint {
    _ = instance;
    _ = program;
    _ = name;
    return error.NotImplemented;
}

/// Operation: getQueryParameter
pub fn call_getQueryParameter(instance: *runtime.Instance, query: *runtime.Instance, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = query;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: uniformMatrix3x2fv
pub fn call_uniformMatrix3x2fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: vertexAttribI4iv
pub fn call_vertexAttribI4iv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Int32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: deleteQuery
pub fn call_deleteQuery(instance: *runtime.Instance, query: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage3D
pub fn call_compressedTexSubImage3D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, zoffset: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, depth: typedefs.GLsizei, format: typedefs.GLenum, imageSize: typedefs.GLsizei, offset: typedefs.GLintptr) ImplError!void {
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
    return error.NotImplemented;
}

/// Operation: isSync
pub fn call_isSync(instance: *runtime.Instance, sync: *runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = sync;
    return error.NotImplemented;
}

/// Operation: getActiveUniforms
pub fn call_getActiveUniforms(instance: *runtime.Instance, program: *runtime.Instance, uniformIndices: *const anyopaque, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = program;
    _ = uniformIndices;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: bindTransformFeedback
pub fn call_bindTransformFeedback(instance: *runtime.Instance, target: typedefs.GLenum, tf: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = tf;
    return error.NotImplemented;
}

/// Operation: uniformMatrix3x4fv
pub fn call_uniformMatrix3x4fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: vertexAttribIPointer
pub fn call_vertexAttribIPointer(instance: *runtime.Instance, index: typedefs.GLuint, size: typedefs.GLint, @"type": typedefs.GLenum, stride: typedefs.GLsizei, offset: typedefs.GLintptr) ImplError!void {
    _ = instance;
    _ = index;
    _ = size;
    _ = @"type";
    _ = stride;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: getTransformFeedbackVarying
pub fn call_getTransformFeedbackVarying(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) ImplError!*runtime.Instance {
    _ = instance;
    _ = program;
    _ = index;
    return error.NotImplemented;
}

/// Operation: samplerParameteri
pub fn call_samplerParameteri(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = sampler;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: isTransformFeedback
pub fn call_isTransformFeedback(instance: *runtime.Instance, tf: *runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = tf;
    return error.NotImplemented;
}

/// Operation: beginQuery
pub fn call_beginQuery(instance: *runtime.Instance, target: typedefs.GLenum, query: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = query;
    return error.NotImplemented;
}

/// Operation: createSampler
pub fn call_createSampler(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: deleteTransformFeedback
pub fn call_deleteTransformFeedback(instance: *runtime.Instance, tf: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = tf;
    return error.NotImplemented;
}

/// Operation: uniform1ui
pub fn call_uniform1ui(instance: *runtime.Instance, location: *runtime.Instance, v0: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    return error.NotImplemented;
}

/// Operation: getActiveUniformBlockParameter
pub fn call_getActiveUniformBlockParameter(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: typedefs.GLuint, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = program;
    _ = uniformBlockIndex;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: invalidateFramebuffer
pub fn call_invalidateFramebuffer(instance: *runtime.Instance, target: typedefs.GLenum, attachments: *const anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachments;
    return error.NotImplemented;
}

/// Operation: getIndexedParameter
pub fn call_getIndexedParameter(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint) ImplError!*const anyopaque {
    _ = instance;
    _ = target;
    _ = index;
    return error.NotImplemented;
}

/// Operation: compressedTexImage3D
pub fn call_compressedTexImage3D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei, depth: typedefs.GLsizei, border: typedefs.GLint, imageSize: typedefs.GLsizei, offset: typedefs.GLintptr) ImplError!void {
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
    return error.NotImplemented;
}

/// Operation: copyBufferSubData
pub fn call_copyBufferSubData(instance: *runtime.Instance, readTarget: typedefs.GLenum, writeTarget: typedefs.GLenum, readOffset: typedefs.GLintptr, writeOffset: typedefs.GLintptr, size: typedefs.GLsizeiptr) ImplError!void {
    _ = instance;
    _ = readTarget;
    _ = writeTarget;
    _ = readOffset;
    _ = writeOffset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: uniform2uiv
pub fn call_uniform2uiv(instance: *runtime.Instance, location: *runtime.Instance, data: typedefs.Uint32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniformMatrix2x4fv
pub fn call_uniformMatrix2x4fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: samplerParameterf
pub fn call_samplerParameterf(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = sampler;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: deleteVertexArray
pub fn call_deleteVertexArray(instance: *runtime.Instance, vertexArray: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = vertexArray;
    return error.NotImplemented;
}

/// Operation: uniform3ui
pub fn call_uniform3ui(instance: *runtime.Instance, location: *runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint, v2: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    _ = v2;
    return error.NotImplemented;
}

/// Operation: waitSync
pub fn call_waitSync(instance: *runtime.Instance, sync: *runtime.Instance, flags: typedefs.GLbitfield, timeout: typedefs.GLint64) ImplError!void {
    _ = instance;
    _ = sync;
    _ = flags;
    _ = timeout;
    return error.NotImplemented;
}

/// Operation: uniform1uiv
pub fn call_uniform1uiv(instance: *runtime.Instance, location: *runtime.Instance, data: typedefs.Uint32List, srcOffset: u64, srcLength: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: bindBufferRange
pub fn call_bindBufferRange(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint, buffer: *runtime.Instance, offset: typedefs.GLintptr, size: typedefs.GLsizeiptr) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    _ = buffer;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

