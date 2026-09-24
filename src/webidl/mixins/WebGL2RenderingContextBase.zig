//! Auto-generated mixin: WebGL2RenderingContextBase
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebGL2RenderingContextBaseImpl = @import("impls").WebGL2RenderingContextBase;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WebGLActiveInfo = @import("interfaces").WebGLActiveInfo;
const GLboolean = @import("typedefs").GLboolean;
const WebGLSampler = @import("interfaces").WebGLSampler;
const WebGLVertexArrayObject = @import("interfaces").WebGLVertexArrayObject;
const GLint = @import("typedefs").GLint;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const WebGLTransformFeedback = @import("interfaces").WebGLTransformFeedback;
const WebGLSync = @import("interfaces").WebGLSync;
const GLenum = @import("typedefs").GLenum;
const GLsizeiptr = @import("typedefs").GLsizeiptr;
const GLintptr = @import("typedefs").GLintptr;
const WebGLProgram = @import("interfaces").WebGLProgram;
const WebGLBuffer = @import("interfaces").WebGLBuffer;
const WebGLTexture = @import("interfaces").WebGLTexture;
const Int32List = @import("typedefs").Int32List;
const GLfloat = @import("typedefs").GLfloat;
const GLint64 = @import("typedefs").GLint64;
const GLuint64 = @import("typedefs").GLuint64;
const GLbitfield = @import("typedefs").GLbitfield;
const Float32List = @import("typedefs").Float32List;
const TexImageSource = @import("typedefs").TexImageSource;
const GLuint = @import("typedefs").GLuint;
const GLsizei = @import("typedefs").GLsizei;
const WebGLUniformLocation = @import("interfaces").WebGLUniformLocation;
const Uint32List = @import("typedefs").Uint32List;
const WebGLQuery = @import("interfaces").WebGLQuery;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").WebGL2RenderingContextBase;

pub fn call_vertexAttribIPointer(instance: *runtime.Instance, index: GLuint, size: GLint, @"type": GLenum, stride: GLsizei, offset: GLintptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_vertexAttribIPointer(instance, index, size, @"type", stride, offset);
}

pub fn call_bindBufferBase(instance: *runtime.Instance, target: GLenum, index: GLuint, buffer: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_bindBufferBase(instance, target, index, buffer);
}

pub fn call_uniform2uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform2uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_uniformMatrix4x3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniformMatrix4x3fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_invalidateFramebuffer(instance: *runtime.Instance, target: GLenum, attachments: runtime.JSValue) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_invalidateFramebuffer(instance, target, attachments);
}

pub fn call_transformFeedbackVaryings(instance: *runtime.Instance, program: *runtime.Instance, varyings: runtime.JSValue, bufferMode: GLenum) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_transformFeedbackVaryings(instance, program, varyings, bufferMode);
}

pub fn call_getSyncParameter(instance: *runtime.Instance, sync: *runtime.Instance, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getSyncParameter(instance, sync, pname);
}

pub fn call_clearBufferfi(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, depth: GLfloat, stencil: GLint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_clearBufferfi(instance, buffer, drawbuffer, depth, stencil);
}

pub fn call_deleteQuery(instance: *runtime.Instance, query: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_deleteQuery(instance, query);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_getFragDataLocation(instance: *runtime.Instance, program: *runtime.Instance, name: DOMString) anyerror!GLint {
    return try WebGL2RenderingContextBaseImpl.call_getFragDataLocation(instance, program, name);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isQuery(instance: *runtime.Instance, query: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGL2RenderingContextBaseImpl.call_isQuery(instance, query);
}

pub fn call_getQuery(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!?*runtime.Instance {
    return try WebGL2RenderingContextBaseImpl.call_getQuery(instance, target, pname);
}

pub fn call_bindSampler(instance: *runtime.Instance, unit: GLuint, sampler: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_bindSampler(instance, unit, sampler);
}

pub fn call_bindBufferRange(instance: *runtime.Instance, target: GLenum, index: GLuint, buffer: ?*runtime.Instance, offset: GLintptr, size: GLsizeiptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_bindBufferRange(instance, target, index, buffer, offset, size);
}

pub fn call_bindTransformFeedback(instance: *runtime.Instance, target: GLenum, tf: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_bindTransformFeedback(instance, target, tf);
}

pub fn call_uniformBlockBinding(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: GLuint, uniformBlockBinding: GLuint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniformBlockBinding(instance, program, uniformBlockIndex, uniformBlockBinding);
}

pub fn call_beginQuery(instance: *runtime.Instance, target: GLenum, query: *runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_beginQuery(instance, target, query);
}

pub fn call_copyBufferSubData(instance: *runtime.Instance, readTarget: GLenum, writeTarget: GLenum, readOffset: GLintptr, writeOffset: GLintptr, size: GLsizeiptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_copyBufferSubData(instance, readTarget, writeTarget, readOffset, writeOffset, size);
}

pub fn call_resumeTransformFeedback(instance: *runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_resumeTransformFeedback(instance);
}

pub fn call_drawArraysInstanced(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei, instanceCount: GLsizei) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_drawArraysInstanced(instance, mode, first, count, instanceCount);
}

pub fn call_renderbufferStorageMultisample(instance: *runtime.Instance, target: GLenum, samples: GLsizei, internalformat: GLenum, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_renderbufferStorageMultisample(instance, target, samples, internalformat, width, height);
}

pub fn call_getUniformBlockIndex(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockName: DOMString) anyerror!GLuint {
    return try WebGL2RenderingContextBaseImpl.call_getUniformBlockIndex(instance, program, uniformBlockName);
}

pub fn call_createVertexArray(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGL2RenderingContextBaseImpl.call_createVertexArray(instance);
}

pub fn call_createTransformFeedback(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGL2RenderingContextBaseImpl.call_createTransformFeedback(instance);
}

pub fn call_framebufferTextureLayer(instance: *runtime.Instance, target: GLenum, attachment: GLenum, texture: ?*runtime.Instance, level: GLint, layer: GLint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_framebufferTextureLayer(instance, target, attachment, texture, level, layer);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isSync(instance: *runtime.Instance, sync: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGL2RenderingContextBaseImpl.call_isSync(instance, sync);
}

pub fn call_clientWaitSync(instance: *runtime.Instance, sync: *runtime.Instance, flags: GLbitfield, timeout: GLuint64) anyerror!GLenum {
    return try WebGL2RenderingContextBaseImpl.call_clientWaitSync(instance, sync, flags, timeout);
}

pub fn call_compressedTexSubImage3D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, format: GLenum, imageSize: GLsizei, offset: GLintptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_compressedTexSubImage3D(instance, target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, offset);
}

pub fn call_getBufferSubData(instance: *runtime.Instance, target: GLenum, srcByteOffset: GLintptr, dstBuffer: ArrayBufferView, dstOffset: webidl.Opt(u64), length: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_getBufferSubData(instance, target, srcByteOffset, dstBuffer, dstOffset, length);
}

pub fn call_getInternalformatParameter(instance: *runtime.Instance, target: GLenum, internalformat: GLenum, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getInternalformatParameter(instance, target, internalformat, pname);
}

pub fn call_uniform4ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: GLuint, v1: GLuint, v2: GLuint, v3: GLuint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform4ui(instance, location, v0, v1, v2, v3);
}

pub fn call_vertexAttribDivisor(instance: *runtime.Instance, index: GLuint, divisor: GLuint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_vertexAttribDivisor(instance, index, divisor);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isVertexArray(instance: *runtime.Instance, vertexArray: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGL2RenderingContextBaseImpl.call_isVertexArray(instance, vertexArray);
}

pub fn call_texStorage3D(instance: *runtime.Instance, target: GLenum, levels: GLsizei, internalformat: GLenum, width: GLsizei, height: GLsizei, depth: GLsizei) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_texStorage3D(instance, target, levels, internalformat, width, height, depth);
}

pub fn call_fenceSync(instance: *runtime.Instance, condition: GLenum, flags: GLbitfield) anyerror!?*runtime.Instance {
    return try WebGL2RenderingContextBaseImpl.call_fenceSync(instance, condition, flags);
}

pub fn call_getActiveUniforms(instance: *runtime.Instance, program: *runtime.Instance, uniformIndices: runtime.JSValue, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getActiveUniforms(instance, program, uniformIndices, pname);
}

pub fn call_deleteVertexArray(instance: *runtime.Instance, vertexArray: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_deleteVertexArray(instance, vertexArray);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isSampler(instance: *runtime.Instance, sampler: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGL2RenderingContextBaseImpl.call_isSampler(instance, sampler);
}

pub fn call_getActiveUniformBlockParameter(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: GLuint, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getActiveUniformBlockParameter(instance, program, uniformBlockIndex, pname);
}

pub fn call_uniform1uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform1uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_clearBufferiv(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, values: Int32List, srcOffset: webidl.Opt(u64)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_clearBufferiv(instance, buffer, drawbuffer, values, srcOffset);
}

pub fn call_getQueryParameter(instance: *runtime.Instance, query: *runtime.Instance, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getQueryParameter(instance, query, pname);
}

pub fn call_vertexAttribI4iv(instance: *runtime.Instance, index: GLuint, values: Int32List) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4iv(instance, index, values);
}

pub fn call_texImage3D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, format: GLenum, @"type": GLenum, pboOffset: GLintptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_texImage3D(instance, target, level, internalformat, width, height, depth, border, format, @"type", pboOffset);
}

pub fn call_drawElementsInstanced(instance: *runtime.Instance, mode: GLenum, count: GLsizei, @"type": GLenum, offset: GLintptr, instanceCount: GLsizei) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_drawElementsInstanced(instance, mode, count, @"type", offset, instanceCount);
}

pub fn call_deleteSync(instance: *runtime.Instance, sync: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_deleteSync(instance, sync);
}

pub fn call_vertexAttribI4uiv(instance: *runtime.Instance, index: GLuint, values: Uint32List) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4uiv(instance, index, values);
}

pub fn call_endTransformFeedback(instance: *runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_endTransformFeedback(instance);
}

pub fn call_uniformMatrix3x4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniformMatrix3x4fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_endQuery(instance: *runtime.Instance, target: GLenum) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_endQuery(instance, target);
}

pub fn call_invalidateSubFramebuffer(instance: *runtime.Instance, target: GLenum, attachments: runtime.JSValue, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_invalidateSubFramebuffer(instance, target, attachments, x, y, width, height);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isTransformFeedback(instance: *runtime.Instance, tf: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGL2RenderingContextBaseImpl.call_isTransformFeedback(instance, tf);
}

pub fn call_compressedTexImage3D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, imageSize: GLsizei, offset: GLintptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_compressedTexImage3D(instance, target, level, internalformat, width, height, depth, border, imageSize, offset);
}

pub fn call_uniform1ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: GLuint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform1ui(instance, location, v0);
}

pub fn call_pauseTransformFeedback(instance: *runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_pauseTransformFeedback(instance);
}

pub fn call_samplerParameteri(instance: *runtime.Instance, sampler: *runtime.Instance, pname: GLenum, param: GLint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_samplerParameteri(instance, sampler, pname, param);
}

pub fn call_blitFramebuffer(instance: *runtime.Instance, srcX0: GLint, srcY0: GLint, srcX1: GLint, srcY1: GLint, dstX0: GLint, dstY0: GLint, dstX1: GLint, dstY1: GLint, mask: GLbitfield, filter: GLenum) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_blitFramebuffer(instance, srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter);
}

pub fn call_clearBufferfv(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, values: Float32List, srcOffset: webidl.Opt(u64)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_clearBufferfv(instance, buffer, drawbuffer, values, srcOffset);
}

pub fn call_texSubImage3D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, format: GLenum, @"type": GLenum, pboOffset: GLintptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_texSubImage3D(instance, target, level, xoffset, yoffset, zoffset, width, height, depth, format, @"type", pboOffset);
}

pub fn call_uniformMatrix2x4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniformMatrix2x4fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_readBuffer(instance: *runtime.Instance, src: GLenum) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_readBuffer(instance, src);
}

pub fn call_deleteSampler(instance: *runtime.Instance, sampler: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_deleteSampler(instance, sampler);
}

pub fn call_getSamplerParameter(instance: *runtime.Instance, sampler: *runtime.Instance, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getSamplerParameter(instance, sampler, pname);
}

pub fn call_drawBuffers(instance: *runtime.Instance, buffers: runtime.JSValue) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_drawBuffers(instance, buffers);
}

pub fn call_uniform2ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: GLuint, v1: GLuint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform2ui(instance, location, v0, v1);
}

pub fn call_getTransformFeedbackVarying(instance: *runtime.Instance, program: *runtime.Instance, index: GLuint) anyerror!?*runtime.Instance {
    return try WebGL2RenderingContextBaseImpl.call_getTransformFeedbackVarying(instance, program, index);
}

pub fn call_getUniformIndices(instance: *runtime.Instance, program: *runtime.Instance, uniformNames: runtime.JSValue) anyerror!?runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getUniformIndices(instance, program, uniformNames);
}

pub fn call_uniformMatrix2x3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniformMatrix2x3fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_vertexAttribI4i(instance: *runtime.Instance, index: GLuint, x: GLint, y: GLint, z: GLint, w: GLint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4i(instance, index, x, y, z, w);
}

pub fn call_uniformMatrix3x2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniformMatrix3x2fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_samplerParameterf(instance: *runtime.Instance, sampler: *runtime.Instance, pname: GLenum, param: GLfloat) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_samplerParameterf(instance, sampler, pname, param);
}

pub fn call_drawRangeElements(instance: *runtime.Instance, mode: GLenum, start: GLuint, end: GLuint, count: GLsizei, @"type": GLenum, offset: GLintptr) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_drawRangeElements(instance, mode, start, end, count, @"type", offset);
}

pub fn call_texStorage2D(instance: *runtime.Instance, target: GLenum, levels: GLsizei, internalformat: GLenum, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_texStorage2D(instance, target, levels, internalformat, width, height);
}

pub fn call_deleteTransformFeedback(instance: *runtime.Instance, tf: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_deleteTransformFeedback(instance, tf);
}

pub fn call_getIndexedParameter(instance: *runtime.Instance, target: GLenum, index: GLuint) anyerror!runtime.JSValue {
    return try WebGL2RenderingContextBaseImpl.call_getIndexedParameter(instance, target, index);
}

pub fn call_getActiveUniformBlockName(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: GLuint) anyerror!?DOMString {
    return try WebGL2RenderingContextBaseImpl.call_getActiveUniformBlockName(instance, program, uniformBlockIndex);
}

pub fn call_bindVertexArray(instance: *runtime.Instance, array: ?*runtime.Instance) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_bindVertexArray(instance, array);
}

pub fn call_uniform4uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform4uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_clearBufferuiv(instance: *runtime.Instance, buffer: GLenum, drawbuffer: GLint, values: Uint32List, srcOffset: webidl.Opt(u64)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_clearBufferuiv(instance, buffer, drawbuffer, values, srcOffset);
}

pub fn call_uniformMatrix4x2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniformMatrix4x2fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_createSampler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGL2RenderingContextBaseImpl.call_createSampler(instance);
}

pub fn call_waitSync(instance: *runtime.Instance, sync: *runtime.Instance, flags: GLbitfield, timeout: GLint64) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_waitSync(instance, sync, flags, timeout);
}

pub fn call_vertexAttribI4ui(instance: *runtime.Instance, index: GLuint, x: GLuint, y: GLuint, z: GLuint, w: GLuint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_vertexAttribI4ui(instance, index, x, y, z, w);
}

pub fn call_copyTexSubImage3D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_copyTexSubImage3D(instance, target, level, xoffset, yoffset, zoffset, x, y, width, height);
}

pub fn call_uniform3uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform3uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_beginTransformFeedback(instance: *runtime.Instance, primitiveMode: GLenum) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_beginTransformFeedback(instance, primitiveMode);
}

pub fn call_createQuery(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGL2RenderingContextBaseImpl.call_createQuery(instance);
}

pub fn call_uniform3ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: GLuint, v1: GLuint, v2: GLuint) anyerror!void {
    return try WebGL2RenderingContextBaseImpl.call_uniform3ui(instance, location, v0, v1, v2);
}

pub fn call_compressedTexSubImage3D__1(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, format: GLenum, srcData: ArrayBufferView, srcOffset: webidl.Opt(u64), srcLengthOverride: webidl.Opt(GLuint)) anyerror!void {
    if (comptime @hasDecl(WebGL2RenderingContextBaseImpl, "call_compressedTexSubImage3D__1")) {
        return try WebGL2RenderingContextBaseImpl.call_compressedTexSubImage3D__1(instance, target, level, xoffset, yoffset, zoffset, width, height, depth, format, srcData, srcOffset, srcLengthOverride);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_texImage3D__1(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, format: GLenum, @"type": GLenum, source: TexImageSource) anyerror!void {
    if (comptime @hasDecl(WebGL2RenderingContextBaseImpl, "call_texImage3D__1")) {
        return try WebGL2RenderingContextBaseImpl.call_texImage3D__1(instance, target, level, internalformat, width, height, depth, border, format, @"type", source);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_texImage3D__2(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, format: GLenum, @"type": GLenum, srcData: ?ArrayBufferView) anyerror!void {
    if (comptime @hasDecl(WebGL2RenderingContextBaseImpl, "call_texImage3D__2")) {
        return try WebGL2RenderingContextBaseImpl.call_texImage3D__2(instance, target, level, internalformat, width, height, depth, border, format, @"type", srcData);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_texImage3D__3(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, format: GLenum, @"type": GLenum, srcData: ArrayBufferView, srcOffset: u64) anyerror!void {
    if (comptime @hasDecl(WebGL2RenderingContextBaseImpl, "call_texImage3D__3")) {
        return try WebGL2RenderingContextBaseImpl.call_texImage3D__3(instance, target, level, internalformat, width, height, depth, border, format, @"type", srcData, srcOffset);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_compressedTexImage3D__1(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, srcData: ArrayBufferView, srcOffset: webidl.Opt(u64), srcLengthOverride: webidl.Opt(GLuint)) anyerror!void {
    if (comptime @hasDecl(WebGL2RenderingContextBaseImpl, "call_compressedTexImage3D__1")) {
        return try WebGL2RenderingContextBaseImpl.call_compressedTexImage3D__1(instance, target, level, internalformat, width, height, depth, border, srcData, srcOffset, srcLengthOverride);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_texSubImage3D__1(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, format: GLenum, @"type": GLenum, source: TexImageSource) anyerror!void {
    if (comptime @hasDecl(WebGL2RenderingContextBaseImpl, "call_texSubImage3D__1")) {
        return try WebGL2RenderingContextBaseImpl.call_texSubImage3D__1(instance, target, level, xoffset, yoffset, zoffset, width, height, depth, format, @"type", source);
    } else {
        return error.NotImplemented;
    }
}

pub fn call_texSubImage3D__2(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, format: GLenum, @"type": GLenum, srcData: ?ArrayBufferView, srcOffset: webidl.Opt(u64)) anyerror!void {
    if (comptime @hasDecl(WebGL2RenderingContextBaseImpl, "call_texSubImage3D__2")) {
        return try WebGL2RenderingContextBaseImpl.call_texSubImage3D__2(instance, target, level, xoffset, yoffset, zoffset, width, height, depth, format, @"type", srcData, srcOffset);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "compressedTexSubImage3D", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_compressedTexSubImage3D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
        .{ .function = "call_compressedTexSubImage3D__1", .implemented = @hasDecl(WebGL2RenderingContextBaseImpl, "call_compressedTexSubImage3D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric}, .optionality = .optional }, .{ .kinds = &.{.other}, .optionality = .optional } } },
    } },
    .{ "texImage3D", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_texImage3D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
        .{ .function = "call_texImage3D__1", .implemented = @hasDecl(WebGL2RenderingContextBaseImpl, "call_texImage3D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
        .{ .function = "call_texImage3D__2", .implemented = @hasDecl(WebGL2RenderingContextBaseImpl, "call_texImage3D__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view }, .nullable = true } } },
        .{ .function = "call_texImage3D__3", .implemented = @hasDecl(WebGL2RenderingContextBaseImpl, "call_texImage3D__3"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric} } } },
    } },
    .{ "compressedTexImage3D", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_compressedTexImage3D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
        .{ .function = "call_compressedTexImage3D__1", .implemented = @hasDecl(WebGL2RenderingContextBaseImpl, "call_compressedTexImage3D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric}, .optionality = .optional }, .{ .kinds = &.{.other}, .optionality = .optional } } },
    } },
    .{ "texSubImage3D", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_texSubImage3D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
        .{ .function = "call_texSubImage3D__1", .implemented = @hasDecl(WebGL2RenderingContextBaseImpl, "call_texSubImage3D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
        .{ .function = "call_texSubImage3D__2", .implemented = @hasDecl(WebGL2RenderingContextBaseImpl, "call_texSubImage3D__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view }, .nullable = true }, .{ .kinds = &.{.numeric}, .optionality = .optional } } },
    } },
};
