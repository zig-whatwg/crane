//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for WebGL2RenderingContext interface
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
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const WebGL2RenderingContext = interfaces.WebGL2RenderingContext;

pub const State = WebGL2RenderingContext.State;

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

/// Getter for canvas
pub fn get_canvas(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferWidth
pub fn get_drawingBufferWidth(instance: *runtime.Instance) ImplError!typedefs.GLsizei {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferHeight
pub fn get_drawingBufferHeight(instance: *runtime.Instance) ImplError!typedefs.GLsizei {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferFormat
pub fn get_drawingBufferFormat(instance: *runtime.Instance) ImplError!typedefs.GLenum {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferColorSpace
pub fn get_drawingBufferColorSpace(instance: *runtime.Instance) ImplError!enums.PredefinedColorSpace {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for unpackColorSpace
pub fn get_unpackColorSpace(instance: *runtime.Instance) ImplError!enums.PredefinedColorSpace {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for drawingBufferColorSpace
pub fn set_drawingBufferColorSpace(instance: *runtime.Instance, value: enums.PredefinedColorSpace) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for unpackColorSpace
pub fn set_unpackColorSpace(instance: *runtime.Instance, value: enums.PredefinedColorSpace) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: createRenderbuffer
pub fn call_createRenderbuffer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: uniform4ui
pub fn call_uniform4ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint, v2: typedefs.GLuint, v3: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    _ = v2;
    _ = v3;
    return error.NotImplemented;
}

/// Operation: resumeTransformFeedback
pub fn call_resumeTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
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

/// Operation: vertexAttribPointer
pub fn call_vertexAttribPointer(instance: *runtime.Instance, index: typedefs.GLuint, size: typedefs.GLint, @"type": typedefs.GLenum, normalized: typedefs.GLboolean, stride: typedefs.GLsizei, offset: typedefs.GLintptr) ImplError!void {
    _ = instance;
    _ = index;
    _ = size;
    _ = @"type";
    _ = normalized;
    _ = stride;
    _ = offset;
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

/// Operation: createVertexArray
pub fn call_createVertexArray(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getActiveAttrib
pub fn call_getActiveAttrib(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) ImplError!?*runtime.Instance {
    _ = instance;
    _ = program;
    _ = index;
    return null;
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

/// Operation: blendFunc
pub fn call_blendFunc(instance: *runtime.Instance, sfactor: typedefs.GLenum, dfactor: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = sfactor;
    _ = dfactor;
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

/// Operation: uniform3fv
pub fn call_uniform3fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: getContextAttributes
pub fn call_getContextAttributes(instance: *runtime.Instance) ImplError!?dictionaries.WebGLContextAttributes {
    _ = instance;
    return null;
}

/// Operation: uniformMatrix2x3fv
pub fn call_uniformMatrix2x3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: isRenderbuffer
pub fn call_isRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: uniformMatrix2fv
pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniform4fv
pub fn call_uniform4fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: deleteTexture
pub fn call_deleteTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = texture;
    return error.NotImplemented;
}

/// Operation: getShaderSource
pub fn call_getShaderSource(instance: *runtime.Instance, shader: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    _ = shader;
    return null;
}

/// Operation: clearBufferiv
pub fn call_clearBufferiv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Int32List, srcOffset: webidl.Opt(u64)) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
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

/// Operation: bindSampler
pub fn call_bindSampler(instance: *runtime.Instance, unit: typedefs.GLuint, sampler: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = unit;
    _ = sampler;
    return error.NotImplemented;
}

/// Operation: vertexAttribI4uiv
pub fn call_vertexAttribI4uiv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Uint32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: depthMask
pub fn call_depthMask(instance: *runtime.Instance, flag: typedefs.GLboolean) ImplError!void {
    _ = instance;
    _ = flag;
    return error.NotImplemented;
}

/// Operation: drawElements
pub fn call_drawElements(instance: *runtime.Instance, mode: typedefs.GLenum, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr) ImplError!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = @"type";
    _ = offset;
    return error.NotImplemented;
}

/// Operation: drawBuffers
pub fn call_drawBuffers(instance: *runtime.Instance, buffers: *const anyopaque) ImplError!void {
    _ = instance;
    _ = buffers;
    return error.NotImplemented;
}

/// Operation: isShader
pub fn call_isShader(instance: *runtime.Instance, shader: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: getParameter
pub fn call_getParameter(instance: *runtime.Instance, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: getBufferSubData
pub fn call_getBufferSubData(instance: *runtime.Instance, target: typedefs.GLenum, srcByteOffset: typedefs.GLintptr, dstBuffer: typedefs.ArrayBufferView, dstOffset: webidl.Opt(u64), length: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = target;
    _ = srcByteOffset;
    _ = dstBuffer;
    _ = dstOffset;
    _ = length;
    return error.NotImplemented;
}

/// Operation: drawingBufferStorage
pub fn call_drawingBufferStorage(instance: *runtime.Instance, sizedFormat: typedefs.GLenum, width: u32, height: u32) ImplError!void {
    _ = instance;
    _ = sizedFormat;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: uniform3iv
pub fn call_uniform3iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: renderbufferStorage
pub fn call_renderbufferStorage(instance: *runtime.Instance, target: typedefs.GLenum, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = target;
    _ = internalformat;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: bindTransformFeedback
pub fn call_bindTransformFeedback(instance: *runtime.Instance, target: typedefs.GLenum, tf: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = tf;
    return error.NotImplemented;
}

/// Operation: getVertexAttrib
pub fn call_getVertexAttrib(instance: *runtime.Instance, index: typedefs.GLuint, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = index;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: blendFuncSeparate
pub fn call_blendFuncSeparate(instance: *runtime.Instance, srcRGB: typedefs.GLenum, dstRGB: typedefs.GLenum, srcAlpha: typedefs.GLenum, dstAlpha: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = srcRGB;
    _ = dstRGB;
    _ = srcAlpha;
    _ = dstAlpha;
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

/// Operation: getTransformFeedbackVarying
pub fn call_getTransformFeedbackVarying(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) ImplError!?*runtime.Instance {
    _ = instance;
    _ = program;
    _ = index;
    return null;
}

/// Operation: clearColor
pub fn call_clearColor(instance: *runtime.Instance, red: typedefs.GLclampf, green: typedefs.GLclampf, blue: typedefs.GLclampf, alpha: typedefs.GLclampf) ImplError!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    return error.NotImplemented;
}

/// Operation: deleteRenderbuffer
pub fn call_deleteRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: activeTexture
pub fn call_activeTexture(instance: *runtime.Instance, texture: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = texture;
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

/// Operation: createProgram
pub fn call_createProgram(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: uniform2uiv
pub fn call_uniform2uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: getProgramInfoLog
pub fn call_getProgramInfoLog(instance: *runtime.Instance, program: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    _ = program;
    return null;
}

/// Operation: uniform1fv
pub fn call_uniform1fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: deleteProgram
pub fn call_deleteProgram(instance: *runtime.Instance, program: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: uniform1uiv
pub fn call_uniform1uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: bindBufferRange
pub fn call_bindBufferRange(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint, buffer: ?*runtime.Instance, offset: typedefs.GLintptr, size: typedefs.GLsizeiptr) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    _ = buffer;
    _ = offset;
    _ = size;
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

/// Operation: frontFace
pub fn call_frontFace(instance: *runtime.Instance, mode: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = mode;
    return error.NotImplemented;
}

/// Operation: isBuffer
pub fn call_isBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: bindTexture
pub fn call_bindTexture(instance: *runtime.Instance, target: typedefs.GLenum, texture: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = texture;
    return error.NotImplemented;
}

/// Operation: uniform3f
pub fn call_uniform3f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    return error.NotImplemented;
}

/// Operation: blendEquation
pub fn call_blendEquation(instance: *runtime.Instance, mode: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = mode;
    return error.NotImplemented;
}

/// Operation: enableVertexAttribArray
pub fn call_enableVertexAttribArray(instance: *runtime.Instance, index: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: isFramebuffer
pub fn call_isFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = framebuffer;
    return error.NotImplemented;
}

/// Operation: finish
pub fn call_finish(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: checkFramebufferStatus
pub fn call_checkFramebufferStatus(instance: *runtime.Instance, target: typedefs.GLenum) ImplError!typedefs.GLenum {
    _ = instance;
    _ = target;
    return error.NotImplemented;
}

/// Operation: getRenderbufferParameter
pub fn call_getRenderbufferParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: isTexture
pub fn call_isTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = texture;
    return error.NotImplemented;
}

/// Operation: linkProgram
pub fn call_linkProgram(instance: *runtime.Instance, program: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: framebufferRenderbuffer
pub fn call_framebufferRenderbuffer(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, renderbuffertarget: typedefs.GLenum, renderbuffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = renderbuffertarget;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: getActiveUniform
pub fn call_getActiveUniform(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) ImplError!?*runtime.Instance {
    _ = instance;
    _ = program;
    _ = index;
    return null;
}

/// Operation: vertexAttrib1f
pub fn call_vertexAttrib1f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    return error.NotImplemented;
}

/// Operation: getShaderInfoLog
pub fn call_getShaderInfoLog(instance: *runtime.Instance, shader: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    _ = shader;
    return null;
}

/// Operation: isContextLost
pub fn call_isContextLost(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: deleteFramebuffer
pub fn call_deleteFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = framebuffer;
    return error.NotImplemented;
}

/// Operation: uniform2ui
pub fn call_uniform2ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    _ = v1;
    return error.NotImplemented;
}

/// Operation: uniformMatrix4x3fv
pub fn call_uniformMatrix4x3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: getUniformBlockIndex
pub fn call_getUniformBlockIndex(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockName: runtime.DOMString) ImplError!typedefs.GLuint {
    _ = instance;
    _ = program;
    _ = uniformBlockName;
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

/// Operation: bindAttribLocation
pub fn call_bindAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint, name: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = program;
    _ = index;
    _ = name;
    return error.NotImplemented;
}

/// Operation: getUniformLocation
pub fn call_getUniformLocation(instance: *runtime.Instance, program: *runtime.Instance, name: runtime.DOMString) ImplError!?*runtime.Instance {
    _ = instance;
    _ = program;
    _ = name;
    return null;
}

/// Operation: uniform4iv
pub fn call_uniform4iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: bindBufferBase
pub fn call_bindBufferBase(instance: *runtime.Instance, target: typedefs.GLenum, index: typedefs.GLuint, buffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = index;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: getExtension
pub fn call_getExtension(instance: *runtime.Instance, name: runtime.DOMString) ImplError!?*const anyopaque {
    _ = instance;
    _ = name;
    return null;
}

/// Operation: colorMask
pub fn call_colorMask(instance: *runtime.Instance, red: typedefs.GLboolean, green: typedefs.GLboolean, blue: typedefs.GLboolean, alpha: typedefs.GLboolean) ImplError!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    return error.NotImplemented;
}

/// Operation: cullFace
pub fn call_cullFace(instance: *runtime.Instance, mode: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = mode;
    return error.NotImplemented;
}

/// Operation: deleteShader
pub fn call_deleteShader(instance: *runtime.Instance, shader: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: vertexAttrib4fv
pub fn call_vertexAttrib4fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: disableVertexAttribArray
pub fn call_disableVertexAttribArray(instance: *runtime.Instance, index: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: uniformMatrix4x2fv
pub fn call_uniformMatrix4x2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: getAttribLocation
pub fn call_getAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, name: runtime.DOMString) ImplError!typedefs.GLint {
    _ = instance;
    _ = program;
    _ = name;
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

/// Operation: uniform3i
pub fn call_uniform3i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    return error.NotImplemented;
}

/// Operation: uniform2i
pub fn call_uniform2i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: vertexAttrib1fv
pub fn call_vertexAttrib1fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
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

/// Operation: scissor
pub fn call_scissor(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: vertexAttribI4iv
pub fn call_vertexAttribI4iv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Int32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: getShaderParameter
pub fn call_getShaderParameter(instance: *runtime.Instance, shader: *runtime.Instance, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = shader;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: isProgram
pub fn call_isProgram(instance: *runtime.Instance, program: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: uniformMatrix3x4fv
pub fn call_uniformMatrix3x4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: lineWidth
pub fn call_lineWidth(instance: *runtime.Instance, width: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = width;
    return error.NotImplemented;
}

/// Operation: uniform1ui
pub fn call_uniform1ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = location;
    _ = v0;
    return error.NotImplemented;
}

/// Operation: uniform1i
pub fn call_uniform1i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    return error.NotImplemented;
}

/// Operation: getShaderPrecisionFormat
pub fn call_getShaderPrecisionFormat(instance: *runtime.Instance, shadertype: typedefs.GLenum, precisiontype: typedefs.GLenum) ImplError!?*runtime.Instance {
    _ = instance;
    _ = shadertype;
    _ = precisiontype;
    return null;
}

/// Operation: samplerParameterf
pub fn call_samplerParameterf(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = sampler;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: texParameterf
pub fn call_texParameterf(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum, param: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = target;
    _ = pname;
    _ = param;
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

/// Operation: sampleCoverage
pub fn call_sampleCoverage(instance: *runtime.Instance, value: typedefs.GLclampf, invert: typedefs.GLboolean) ImplError!void {
    _ = instance;
    _ = value;
    _ = invert;
    return error.NotImplemented;
}

/// Operation: uniform1iv
pub fn call_uniform1iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: uniformMatrix4fv
pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: getAttachedShaders
pub fn call_getAttachedShaders(instance: *runtime.Instance, program: *runtime.Instance) ImplError!?*const anyopaque {
    _ = instance;
    _ = program;
    return null;
}

/// Operation: createFramebuffer
pub fn call_createFramebuffer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createTexture
pub fn call_createTexture(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: vertexAttrib4f
pub fn call_vertexAttrib4f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat, w: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: uniform4f
pub fn call_uniform4f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat, w: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: createTransformFeedback
pub fn call_createTransformFeedback(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getQuery
pub fn call_getQuery(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) ImplError!?*runtime.Instance {
    _ = instance;
    _ = target;
    _ = pname;
    return null;
}

/// Operation: stencilOpSeparate
pub fn call_stencilOpSeparate(instance: *runtime.Instance, face: typedefs.GLenum, fail: typedefs.GLenum, zfail: typedefs.GLenum, zpass: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = face;
    _ = fail;
    _ = zfail;
    _ = zpass;
    return error.NotImplemented;
}

/// Operation: endTransformFeedback
pub fn call_endTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: generateMipmap
pub fn call_generateMipmap(instance: *runtime.Instance, target: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = target;
    return error.NotImplemented;
}

/// Operation: getUniformIndices
pub fn call_getUniformIndices(instance: *runtime.Instance, program: *runtime.Instance, uniformNames: *const anyopaque) ImplError!?*const anyopaque {
    _ = instance;
    _ = program;
    _ = uniformNames;
    return null;
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

/// Operation: getFramebufferAttachmentParameter
pub fn call_getFramebufferAttachmentParameter(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: isEnabled
pub fn call_isEnabled(instance: *runtime.Instance, cap: typedefs.GLenum) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = cap;
    return error.NotImplemented;
}

/// Operation: copyTexSubImage2D
pub fn call_copyTexSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: fenceSync
pub fn call_fenceSync(instance: *runtime.Instance, condition: typedefs.GLenum, flags: typedefs.GLbitfield) ImplError!?*runtime.Instance {
    _ = instance;
    _ = condition;
    _ = flags;
    return null;
}

/// Operation: vertexAttrib2f
pub fn call_vertexAttrib2f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance, mask: typedefs.GLbitfield) ImplError!void {
    _ = instance;
    _ = mask;
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

/// Operation: uniform2fv
pub fn call_uniform2fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: disable
pub fn call_disable(instance: *runtime.Instance, cap: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = cap;
    return error.NotImplemented;
}

/// Operation: framebufferTextureLayer
pub fn call_framebufferTextureLayer(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, texture: ?*runtime.Instance, level: typedefs.GLint, layer: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = texture;
    _ = level;
    _ = layer;
    return error.NotImplemented;
}

/// Operation: endQuery
pub fn call_endQuery(instance: *runtime.Instance, target: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = target;
    return error.NotImplemented;
}

/// Operation: compileShader
pub fn call_compileShader(instance: *runtime.Instance, shader: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = shader;
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

/// Operation: blendEquationSeparate
pub fn call_blendEquationSeparate(instance: *runtime.Instance, modeRGB: typedefs.GLenum, modeAlpha: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = modeRGB;
    _ = modeAlpha;
    return error.NotImplemented;
}

/// Operation: isSampler
pub fn call_isSampler(instance: *runtime.Instance, sampler: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
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

/// Operation: depthRange
pub fn call_depthRange(instance: *runtime.Instance, zNear: typedefs.GLclampf, zFar: typedefs.GLclampf) ImplError!void {
    _ = instance;
    _ = zNear;
    _ = zFar;
    return error.NotImplemented;
}

/// Operation: getActiveUniformBlockName
pub fn call_getActiveUniformBlockName(instance: *runtime.Instance, program: *runtime.Instance, uniformBlockIndex: typedefs.GLuint) ImplError!?runtime.DOMString {
    _ = instance;
    _ = program;
    _ = uniformBlockIndex;
    return null;
}

/// Operation: polygonOffset
pub fn call_polygonOffset(instance: *runtime.Instance, factor: typedefs.GLfloat, units: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = factor;
    _ = units;
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

/// Operation: isVertexArray
pub fn call_isVertexArray(instance: *runtime.Instance, vertexArray: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = vertexArray;
    return error.NotImplemented;
}

/// Operation: bindBuffer
pub fn call_bindBuffer(instance: *runtime.Instance, target: typedefs.GLenum, buffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: makeXRCompatible
pub fn call_makeXRCompatible(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
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
pub fn call_uniformMatrix3x2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: deleteQuery
pub fn call_deleteQuery(instance: *runtime.Instance, query: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: getSupportedExtensions
pub fn call_getSupportedExtensions(instance: *runtime.Instance) ImplError!?*const anyopaque {
    _ = instance;
    return null;
}

/// Operation: isSync
pub fn call_isSync(instance: *runtime.Instance, sync: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = sync;
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

/// Operation: clearStencil
pub fn call_clearStencil(instance: *runtime.Instance, s: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = s;
    return error.NotImplemented;
}

/// Operation: enable
pub fn call_enable(instance: *runtime.Instance, cap: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = cap;
    return error.NotImplemented;
}

/// Operation: shaderSource
pub fn call_shaderSource(instance: *runtime.Instance, shader: *runtime.Instance, source: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = shader;
    _ = source;
    return error.NotImplemented;
}

/// Operation: clearDepth
pub fn call_clearDepth(instance: *runtime.Instance, depth: typedefs.GLclampf) ImplError!void {
    _ = instance;
    _ = depth;
    return error.NotImplemented;
}

/// Operation: detachShader
pub fn call_detachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = program;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: getError
pub fn call_getError(instance: *runtime.Instance) ImplError!typedefs.GLenum {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: vertexAttrib3fv
pub fn call_vertexAttrib3fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: stencilFunc
pub fn call_stencilFunc(instance: *runtime.Instance, func: typedefs.GLenum, ref: typedefs.GLint, mask: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = func;
    _ = ref;
    _ = mask;
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

/// Operation: framebufferTexture2D
pub fn call_framebufferTexture2D(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, textarget: typedefs.GLenum, texture: ?*runtime.Instance, level: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = textarget;
    _ = texture;
    _ = level;
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

/// Operation: deleteVertexArray
pub fn call_deleteVertexArray(instance: *runtime.Instance, vertexArray: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = vertexArray;
    return error.NotImplemented;
}

/// Operation: createShader
pub fn call_createShader(instance: *runtime.Instance, @"type": typedefs.GLenum) ImplError!?*runtime.Instance {
    _ = instance;
    _ = @"type";
    return null;
}

/// Operation: useProgram
pub fn call_useProgram(instance: *runtime.Instance, program: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: uniform3ui
pub fn call_uniform3ui(instance: *runtime.Instance, location: ?*runtime.Instance, v0: typedefs.GLuint, v1: typedefs.GLuint, v2: typedefs.GLuint) ImplError!void {
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

/// Operation: bufferData
pub fn call_bufferData(instance: *runtime.Instance, target: typedefs.GLenum, size: typedefs.GLsizeiptr, usage: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = target;
    _ = size;
    _ = usage;
    return error.NotImplemented;
}

/// Operation: getTexParameter
pub fn call_getTexParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: blendColor
pub fn call_blendColor(instance: *runtime.Instance, red: typedefs.GLclampf, green: typedefs.GLclampf, blue: typedefs.GLclampf, alpha: typedefs.GLclampf) ImplError!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    return error.NotImplemented;
}

/// Operation: readBuffer
pub fn call_readBuffer(instance: *runtime.Instance, src: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = src;
    return error.NotImplemented;
}

/// Operation: clearBufferuiv
pub fn call_clearBufferuiv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Uint32List, srcOffset: webidl.Opt(u64)) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
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

/// Operation: bindFramebuffer
pub fn call_bindFramebuffer(instance: *runtime.Instance, target: typedefs.GLenum, framebuffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = framebuffer;
    return error.NotImplemented;
}

/// Operation: stencilFuncSeparate
pub fn call_stencilFuncSeparate(instance: *runtime.Instance, face: typedefs.GLenum, func: typedefs.GLenum, ref: typedefs.GLint, mask: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = face;
    _ = func;
    _ = ref;
    _ = mask;
    return error.NotImplemented;
}

/// Operation: clearBufferfv
pub fn call_clearBufferfv(instance: *runtime.Instance, buffer: typedefs.GLenum, drawbuffer: typedefs.GLint, values: typedefs.Float32List, srcOffset: webidl.Opt(u64)) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = drawbuffer;
    _ = values;
    _ = srcOffset;
    return error.NotImplemented;
}

/// Operation: vertexAttrib3f
pub fn call_vertexAttrib3f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
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

/// Operation: texParameteri
pub fn call_texParameteri(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum, param: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = target;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: pixelStorei
pub fn call_pixelStorei(instance: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: viewport
pub fn call_viewport(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
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

/// Operation: stencilOp
pub fn call_stencilOp(instance: *runtime.Instance, fail: typedefs.GLenum, zfail: typedefs.GLenum, zpass: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = fail;
    _ = zfail;
    _ = zpass;
    return error.NotImplemented;
}

/// Operation: deleteSampler
pub fn call_deleteSampler(instance: *runtime.Instance, sampler: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = sampler;
    return error.NotImplemented;
}

/// Operation: getSyncParameter
pub fn call_getSyncParameter(instance: *runtime.Instance, sync: *runtime.Instance, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = sync;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: bindRenderbuffer
pub fn call_bindRenderbuffer(instance: *runtime.Instance, target: typedefs.GLenum, renderbuffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = target;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: depthFunc
pub fn call_depthFunc(instance: *runtime.Instance, func: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = func;
    return error.NotImplemented;
}

/// Operation: hint
pub fn call_hint(instance: *runtime.Instance, target: typedefs.GLenum, mode: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = target;
    _ = mode;
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

/// Operation: uniform1f
pub fn call_uniform1f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    return error.NotImplemented;
}

/// Operation: beginTransformFeedback
pub fn call_beginTransformFeedback(instance: *runtime.Instance, primitiveMode: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = primitiveMode;
    return error.NotImplemented;
}

/// Operation: bindVertexArray
pub fn call_bindVertexArray(instance: *runtime.Instance, array: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = array;
    return error.NotImplemented;
}

/// Operation: uniformMatrix3fv
pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: pauseTransformFeedback
pub fn call_pauseTransformFeedback(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: isQuery
pub fn call_isQuery(instance: *runtime.Instance, query: ?*runtime.Instance) ImplError!typedefs.GLboolean {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: uniform3uiv
pub fn call_uniform3uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: getProgramParameter
pub fn call_getProgramParameter(instance: *runtime.Instance, program: *runtime.Instance, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = program;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: flush
pub fn call_flush(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: vertexAttrib2fv
pub fn call_vertexAttrib2fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
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
pub fn call_uniform4uiv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Uint32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: createQuery
pub fn call_createQuery(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: uniform2f
pub fn call_uniform2f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: drawArrays
pub fn call_drawArrays(instance: *runtime.Instance, mode: typedefs.GLenum, first: typedefs.GLint, count: typedefs.GLsizei) ImplError!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    return error.NotImplemented;
}

/// Operation: validateProgram
pub fn call_validateProgram(instance: *runtime.Instance, program: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: deleteSync
pub fn call_deleteSync(instance: *runtime.Instance, sync: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = sync;
    return error.NotImplemented;
}

/// Operation: getFragDataLocation
pub fn call_getFragDataLocation(instance: *runtime.Instance, program: *runtime.Instance, name: runtime.DOMString) ImplError!typedefs.GLint {
    _ = instance;
    _ = program;
    _ = name;
    return error.NotImplemented;
}

/// Operation: createBuffer
pub fn call_createBuffer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
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

/// Operation: getVertexAttribOffset
pub fn call_getVertexAttribOffset(instance: *runtime.Instance, index: typedefs.GLuint, pname: typedefs.GLenum) ImplError!typedefs.GLintptr {
    _ = instance;
    _ = index;
    _ = pname;
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

/// Operation: uniform4i
pub fn call_uniform4i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint, w: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: deleteBuffer
pub fn call_deleteBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: stencilMask
pub fn call_stencilMask(instance: *runtime.Instance, mask: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = mask;
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

/// Operation: samplerParameteri
pub fn call_samplerParameteri(instance: *runtime.Instance, sampler: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = sampler;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: isTransformFeedback
pub fn call_isTransformFeedback(instance: *runtime.Instance, tf: ?*runtime.Instance) ImplError!typedefs.GLboolean {
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
pub fn call_deleteTransformFeedback(instance: *runtime.Instance, tf: ?*runtime.Instance) ImplError!void {
    _ = instance;
    _ = tf;
    return error.NotImplemented;
}

/// Operation: getBufferParameter
pub fn call_getBufferParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: stencilMaskSeparate
pub fn call_stencilMaskSeparate(instance: *runtime.Instance, face: typedefs.GLenum, mask: typedefs.GLuint) ImplError!void {
    _ = instance;
    _ = face;
    _ = mask;
    return error.NotImplemented;
}

/// Operation: uniformMatrix2x4fv
pub fn call_uniformMatrix2x4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: copyTexImage2D
pub fn call_copyTexImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLenum, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = border;
    return error.NotImplemented;
}

/// Operation: uniform2iv
pub fn call_uniform2iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(typedefs.GLuint)) ImplError!void {
    _ = instance;
    _ = location;
    _ = data;
    _ = srcOffset;
    _ = srcLength;
    return error.NotImplemented;
}

/// Operation: attachShader
pub fn call_attachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = program;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: getUniform
pub fn call_getUniform(instance: *runtime.Instance, program: *runtime.Instance, location: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    _ = program;
    _ = location;
    return error.NotImplemented;
}

