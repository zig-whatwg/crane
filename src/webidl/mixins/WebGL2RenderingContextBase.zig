//! Auto-generated mixin: WebGL2RenderingContextBase
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WebGL2RenderingContextBaseImpl = @import("impls").WebGL2RenderingContextBase;

// Re-export types from impl
pub const impl = @import("impls").WebGL2RenderingContextBase;

pub fn call_vertexAttribIPointer(instance: *runtime.Instance, index: typedefs.GLuint, size: typedefs.GLint, @"type": typedefs.GLenum, stride: typedefs.GLsizei, offset: typedefs.GLintptr) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_vertexAttribIPointer(instance, index, size, @"type", stride, offset);
}

pub fn call_bindBufferBase(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint, buffer: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_bindBufferBase(instance, target, index, buffer);
}

pub fn call_uniform2uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform2uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_uniformMatrix4x3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniformMatrix4x3fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_invalidateFramebuffer(instance: *runtime.Instance, target: typedefs.GLenum, attachments: runtime.JSValue) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_invalidateFramebuffer(instance, target, attachments);
}

pub fn call_transformFeedbackVaryings(instance: *runtime.Instance, program: *runtime.Instance, varyings: runtime.JSValue, bufferMode: typedefs.GLenum) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_transformFeedbackVaryings(instance, program, varyings, bufferMode);
}

pub fn call_getSyncParameter(instance: *runtime.Instance, sync: *runtime.Instance, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGL2RenderingContextBaseImpl.call_getSyncParameter(instance, sync, pname);
}

pub fn call_clearBufferfi(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, depth: typedefs.GLfloat, stencil: typedefs.GLint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_clearBufferfi(instance, buffer, drawbuffer, depth, stencil);
}

pub fn call_deleteQuery(instance: *runtime.Instance, query: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_deleteQuery(instance, query);
}

pub fn call_getFragDataLocation(instance: *runtime.Instance, program: *runtime.Instance, name: typedefs.DOMString) anyerror!typedefs.GLint {
    return WebGL2RenderingContextBaseImpl.call_getFragDataLocation(instance, program, name);
}

pub fn call_isQuery(instance: *runtime.Instance, query: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGL2RenderingContextBaseImpl.call_isQuery(instance, query);
}

pub fn call_getQuery(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) !?*runtime.Instance {
    return WebGL2RenderingContextBaseImpl.call_getQuery(instance, target, pname);
}

pub fn call_bindSampler(instance: *runtime.Instance, unit: typedefs.GLuint, sampler: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_bindSampler(instance, unit, sampler);
}

pub fn call_bindBufferRange(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint, buffer: ?*runtime.Instance, offset: typedefs.GLintptr, size: typedefs.GLsizeiptr) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_bindBufferRange(instance, target, index, buffer, offset, size);
}

pub fn call_bindTransformFeedback(instance: *runtime.Instance, target: typedefs.GLenum, tf: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_bindTransformFeedback(instance, target, tf);
}

pub fn call_uniformBlockBinding(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: typedefs.GLuint, uniformBlockBinding: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniformBlockBinding(instance, program, uniformBlockIndex, uniformBlockBinding);
}

pub fn call_beginQuery(instance: *runtime.Instance, target: typedefs.GLenum, query: *runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_beginQuery(instance, target, query);
}

pub fn call_copyBufferSubData(instance: *runtime.Instance, readTarget: typedefs.GLenum, writeTarget: typedefs.GLenum, readOffset: typedefs.GLintptr, writeOffset: typedefs.GLintptr, size: typedefs.GLsizeiptr) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_copyBufferSubData(instance, readTarget, writeTarget, readOffset, writeOffset, size);
}

pub fn call_resumeTransformFeedback(instance: *runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_resumeTransformFeedback(instance);
}

pub fn call_drawArraysInstanced(instance: *runtime.Instance, mode: typedefs.GLenum, first: typedefs.GLint, count: typedefs.GLsizei, instanceCount: typedefs.GLsizei) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_drawArraysInstanced(instance, mode, first, count, instanceCount);
}

pub fn call_renderbufferStorageMultisample(instance: *runtime.Instance, target: typedefs.GLenum, samples: typedefs.GLsizei, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_renderbufferStorageMultisample(instance, target, samples, internalformat, width, height);
}

pub fn call_getUniformBlockIndex(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockName: typedefs.DOMString) anyerror!typedefs.GLuint {
    return WebGL2RenderingContextBaseImpl.call_getUniformBlockIndex(instance, program, uniformBlockName);
}

pub fn call_createVertexArray(instance: *runtime.Instance) !*runtime.Instance {
    return WebGL2RenderingContextBaseImpl.call_createVertexArray(instance);
}

pub fn call_createTransformFeedback(instance: *runtime.Instance) !*runtime.Instance {
    return WebGL2RenderingContextBaseImpl.call_createTransformFeedback(instance);
}

pub fn call_framebufferTextureLayer(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, texture: ?*runtime.Instance, level: typedefs.GLint, layer: typedefs.GLint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_framebufferTextureLayer(instance, target, attachment, texture, level, layer);
}

pub fn call_isSync(instance: *runtime.Instance, sync: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGL2RenderingContextBaseImpl.call_isSync(instance, sync);
}

pub fn call_clientWaitSync(instance: *runtime.Instance, sync: *runtime.Instance, flags: typedefs.GLbitfield, timeout: typedefs.GLuint64) anyerror!typedefs.GLenum {
    return WebGL2RenderingContextBaseImpl.call_clientWaitSync(instance, sync, flags, timeout);
}

/// Arguments for compressedTexSubImage3D (WebIDL overloading)
pub const CompressedTexSubImage3DArgs = union(enum) {
    /// compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, offset)
    GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLsizei_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        zoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        format: typedefs.GLenum,
        imageSize: typedefs.GLsizei,
        offset: typedefs.GLintptr,
    },
    /// compressedTexSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, srcData, srcOffset, srcLengthOverride)
    GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_ArrayBufferView_unsigned_long_long_GLuint: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        zoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        format: typedefs.GLenum,
        srcData: typedefs.ArrayBufferView,
        srcOffset: webidl.Opt(runtime.JSValue),
        srcLengthOverride: webidl.Opt(typedefs.GLuint),
    },
};

pub fn call_compressedTexSubImage3D(instance: *runtime.Instance, args: CompressedTexSubImage3DArgs) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_compressedTexSubImage3D(instance, args);
}

pub fn call_getBufferSubData(instance: *runtime.Instance, target: typedefs.GLenum, srcByteOffset: typedefs.GLintptr, dstBuffer: typedefs.ArrayBufferView, dstOffset: runtime.JSValue, length: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_getBufferSubData(instance, target, srcByteOffset, dstBuffer, dstOffset, length);
}

pub fn call_getInternalformatParameter(instance: *runtime.Instance, target: typedefs.GLenum, internalformat: typedefs.GLenum, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGL2RenderingContextBaseImpl.call_getInternalformatParameter(instance, target, internalformat, pname);
}

pub fn call_uniform4ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint, v2: typedefs.GLuint, v3: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform4ui(instance, location, v0, v1, v2, v3);
}

pub fn call_vertexAttribDivisor(instance: *runtime.Instance, index: typedefs.GLuint, divisor: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_vertexAttribDivisor(instance, index, divisor);
}

pub fn call_isVertexArray(instance: *runtime.Instance, vertexArray: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGL2RenderingContextBaseImpl.call_isVertexArray(instance, vertexArray);
}

pub fn call_texStorage3D(instance: *runtime.Instance, target: typedefs.GLenum, levels: typedefs.GLsizei, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei, depth: typedefs.GLsizei) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_texStorage3D(instance, target, levels, internalformat, width, height, depth);
}

pub fn call_fenceSync(instance: *runtime.Instance, condition: typedefs.GLenum, flags: typedefs.GLbitfield) !?*runtime.Instance {
    return WebGL2RenderingContextBaseImpl.call_fenceSync(instance, condition, flags);
}

pub fn call_getActiveUniforms(instance: *runtime.Instance, program: *runtime.Instance, uniformIndices: runtime.JSValue, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGL2RenderingContextBaseImpl.call_getActiveUniforms(instance, program, uniformIndices, pname);
}

pub fn call_deleteVertexArray(instance: *runtime.Instance, vertexArray: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_deleteVertexArray(instance, vertexArray);
}

pub fn call_isSampler(instance: *runtime.Instance, sampler: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGL2RenderingContextBaseImpl.call_isSampler(instance, sampler);
}

pub fn call_getActiveUniformBlockParameter(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: typedefs.GLuint, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGL2RenderingContextBaseImpl.call_getActiveUniformBlockParameter(instance, program, uniformBlockIndex, pname);
}

pub fn call_uniform1uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform1uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_clearBufferiv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Int32List, srcOffset: runtime.JSValue) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_clearBufferiv(instance, buffer, drawbuffer, values, srcOffset);
}

pub fn call_getQueryParameter(instance: *runtime.Instance, query: *runtime.Instance, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGL2RenderingContextBaseImpl.call_getQueryParameter(instance, query, pname);
}

pub fn call_vertexAttribI4iv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Int32List) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_vertexAttribI4iv(instance, index, values);
}

/// Arguments for texImage3D (WebIDL overloading)
pub const TexImage3DArgs = union(enum) {
    /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, pboOffset)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        pboOffset: typedefs.GLintptr,
    },
    /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, source)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        source: typedefs.TexImageSource,
    },
    /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, srcData)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        srcData: ?typedefs.ArrayBufferView,
    },
    /// texImage3D(target, level, internalformat, width, height, depth, border, format, type, srcData, srcOffset)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_unsigned_long_long: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        srcData: typedefs.ArrayBufferView,
        srcOffset: runtime.JSValue,
    },
};

pub fn call_texImage3D(instance: *runtime.Instance, args: TexImage3DArgs) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_texImage3D(instance, args);
}

pub fn call_drawElementsInstanced(instance: *runtime.Instance, mode: typedefs.GLenum, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr, instanceCount: typedefs.GLsizei) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_drawElementsInstanced(instance, mode, count, @"type", offset, instanceCount);
}

pub fn call_deleteSync(instance: *runtime.Instance, sync: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_deleteSync(instance, sync);
}

pub fn call_vertexAttribI4uiv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Uint32List) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_vertexAttribI4uiv(instance, index, values);
}

pub fn call_endTransformFeedback(instance: *runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_endTransformFeedback(instance);
}

pub fn call_uniformMatrix3x4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniformMatrix3x4fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_endQuery(instance: *runtime.Instance, target: typedefs.GLenum) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_endQuery(instance, target);
}

pub fn call_invalidateSubFramebuffer(instance: *runtime.Instance, target: typedefs.GLenum, attachments: runtime.JSValue, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_invalidateSubFramebuffer(instance, target, attachments, x, y, width, height);
}

pub fn call_isTransformFeedback(instance: *runtime.Instance, tf: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGL2RenderingContextBaseImpl.call_isTransformFeedback(instance, tf);
}

/// Arguments for compressedTexImage3D (WebIDL overloading)
pub const CompressedTexImage3DArgs = union(enum) {
    /// compressedTexImage3D(target, level, internalformat, width, height, depth, border, imageSize, offset)
    GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_GLsizei_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLenum,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        border: typedefs.GLint,
        imageSize: typedefs.GLsizei,
        offset: typedefs.GLintptr,
    },
    /// compressedTexImage3D(target, level, internalformat, width, height, depth, border, srcData, srcOffset, srcLengthOverride)
    GLenum_GLint_GLenum_GLsizei_GLsizei_GLsizei_GLint_ArrayBufferView_unsigned_long_long_GLuint: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLenum,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        border: typedefs.GLint,
        srcData: typedefs.ArrayBufferView,
        srcOffset: webidl.Opt(runtime.JSValue),
        srcLengthOverride: webidl.Opt(typedefs.GLuint),
    },
};

pub fn call_compressedTexImage3D(instance: *runtime.Instance, args: CompressedTexImage3DArgs) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_compressedTexImage3D(instance, args);
}

pub fn call_uniform1ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform1ui(instance, location, v0);
}

pub fn call_pauseTransformFeedback(instance: *runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_pauseTransformFeedback(instance);
}

pub fn call_samplerParameteri(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_samplerParameteri(instance, sampler, pname, param);
}

pub fn call_blitFramebuffer(instance: *runtime.Instance, srcX0: typedefs.GLint, srcY0: typedefs.GLint, srcX1: typedefs.GLint, srcY1: typedefs.GLint, dstX0: typedefs.GLint, dstY0: typedefs.GLint, dstX1: typedefs.GLint, dstY1: typedefs.GLint, mask: typedefs.GLbitfield, filter: typedefs.GLenum) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_blitFramebuffer(instance, srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter);
}

pub fn call_clearBufferfv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Float32List, srcOffset: runtime.JSValue) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_clearBufferfv(instance, buffer, drawbuffer, values, srcOffset);
}

/// Arguments for texSubImage3D (WebIDL overloading)
pub const TexSubImage3DArgs = union(enum) {
    /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, pboOffset)
    GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        zoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        pboOffset: typedefs.GLintptr,
    },
    /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, source)
    GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_TexImageSource: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        zoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        source: typedefs.TexImageSource,
    },
    /// texSubImage3D(target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, srcData, srcOffset)
    GLenum_GLint_GLint_GLint_GLint_GLsizei_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_unsigned_long_long: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        zoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        depth: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        srcData: ?typedefs.ArrayBufferView,
        srcOffset: webidl.Opt(runtime.JSValue),
    },
};

pub fn call_texSubImage3D(instance: *runtime.Instance, args: TexSubImage3DArgs) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_texSubImage3D(instance, args);
}

pub fn call_uniformMatrix2x4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniformMatrix2x4fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_readBuffer(instance: *runtime.Instance, src: typedefs.GLenum) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_readBuffer(instance, src);
}

pub fn call_deleteSampler(instance: *runtime.Instance, sampler: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_deleteSampler(instance, sampler);
}

pub fn call_getSamplerParameter(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGL2RenderingContextBaseImpl.call_getSamplerParameter(instance, sampler, pname);
}

pub fn call_drawBuffers(instance: *runtime.Instance, buffers: runtime.JSValue) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_drawBuffers(instance, buffers);
}

pub fn call_uniform2ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform2ui(instance, location, v0, v1);
}

pub fn call_getTransformFeedbackVarying(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) !?*runtime.Instance {
    return WebGL2RenderingContextBaseImpl.call_getTransformFeedbackVarying(instance, program, index);
}

pub fn call_getUniformIndices(instance: *runtime.Instance, program: *runtime.Instance, uniformNames: runtime.JSValue) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_getUniformIndices(instance, program, uniformNames);
}

pub fn call_uniformMatrix2x3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniformMatrix2x3fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_vertexAttribI4i(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint, w: typedefs.GLint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_vertexAttribI4i(instance, index, x, y, z, w);
}

pub fn call_uniformMatrix3x2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniformMatrix3x2fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_samplerParameterf(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLfloat) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_samplerParameterf(instance, sampler, pname, param);
}

pub fn call_drawRangeElements(instance: *runtime.Instance, mode: typedefs.GLenum, start: typedefs.GLuint, end: typedefs.GLuint, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_drawRangeElements(instance, mode, start, end, count, @"type", offset);
}

pub fn call_texStorage2D(instance: *runtime.Instance, target: typedefs.GLenum, levels: typedefs.GLsizei, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_texStorage2D(instance, target, levels, internalformat, width, height);
}

pub fn call_deleteTransformFeedback(instance: *runtime.Instance, tf: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_deleteTransformFeedback(instance, tf);
}

pub fn call_getIndexedParameter(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint) anyerror!runtime.JSValue {
    return WebGL2RenderingContextBaseImpl.call_getIndexedParameter(instance, target, index);
}

pub fn call_getActiveUniformBlockName(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: typedefs.GLuint) anyerror!typedefs.DOMString {
    return WebGL2RenderingContextBaseImpl.call_getActiveUniformBlockName(instance, program, uniformBlockIndex);
}

pub fn call_bindVertexArray(instance: *runtime.Instance, array: ?*runtime.Instance) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_bindVertexArray(instance, array);
}

pub fn call_uniform4uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform4uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_clearBufferuiv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Uint32List, srcOffset: runtime.JSValue) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_clearBufferuiv(instance, buffer, drawbuffer, values, srcOffset);
}

pub fn call_uniformMatrix4x2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniformMatrix4x2fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_createSampler(instance: *runtime.Instance) !*runtime.Instance {
    return WebGL2RenderingContextBaseImpl.call_createSampler(instance);
}

pub fn call_waitSync(instance: *runtime.Instance, sync: *runtime.Instance, flags: typedefs.GLbitfield, timeout: typedefs.GLint64) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_waitSync(instance, sync, flags, timeout);
}

pub fn call_vertexAttribI4ui(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLuint, y: typedefs.GLuint, z: typedefs.GLuint, w: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_vertexAttribI4ui(instance, index, x, y, z, w);
}

pub fn call_copyTexSubImage3D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, zoffset: typedefs.GLint, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_copyTexSubImage3D(instance, target, level, xoffset, yoffset, zoffset, x, y, width, height);
}

pub fn call_uniform3uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform3uiv(instance, location, data, srcOffset, srcLength);
}

pub fn call_beginTransformFeedback(instance: *runtime.Instance, primitiveMode: typedefs.GLenum) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_beginTransformFeedback(instance, primitiveMode);
}

pub fn call_createQuery(instance: *runtime.Instance) !*runtime.Instance {
    return WebGL2RenderingContextBaseImpl.call_createQuery(instance);
}

pub fn call_uniform3ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint, v2: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextBaseImpl.call_uniform3ui(instance, location, v0, v1, v2);
}

