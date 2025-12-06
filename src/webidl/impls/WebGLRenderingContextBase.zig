//! Implementation for WebGLRenderingContextBase interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WebGLRenderingContextBase = interfaces.WebGLRenderingContextBase;

pub const State = WebGLRenderingContextBase.State;

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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for canvas
pub fn get_canvas(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferWidth
pub fn get_drawingBufferWidth(instance: *runtime.Instance) anyerror!typedefs.GLsizei {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferHeight
pub fn get_drawingBufferHeight(instance: *runtime.Instance) anyerror!typedefs.GLsizei {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferFormat
pub fn get_drawingBufferFormat(instance: *runtime.Instance) anyerror!typedefs.GLenum {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for drawingBufferColorSpace
pub fn get_drawingBufferColorSpace(instance: *runtime.Instance) anyerror!enums.PredefinedColorSpace {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for unpackColorSpace
pub fn get_unpackColorSpace(instance: *runtime.Instance) anyerror!enums.PredefinedColorSpace {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for drawingBufferColorSpace
pub fn set_drawingBufferColorSpace(instance: *runtime.Instance, value: enums.PredefinedColorSpace) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for unpackColorSpace
pub fn set_unpackColorSpace(instance: *runtime.Instance, value: enums.PredefinedColorSpace) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: createRenderbuffer
pub fn call_createRenderbuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createFramebuffer
pub fn call_createFramebuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createTexture
pub fn call_createTexture(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: vertexAttrib4f
pub fn call_vertexAttrib4f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat, w: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: vertexAttribPointer
pub fn call_vertexAttribPointer(instance: *runtime.Instance, index: typedefs.GLuint, size: typedefs.GLint, @"type": typedefs.GLenum, normalized: typedefs.GLboolean, stride: typedefs.GLsizei, offset: typedefs.GLintptr) anyerror!void {
    _ = instance;
    _ = index;
    _ = size;
    _ = @"type";
    _ = normalized;
    _ = stride;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: uniform4f
pub fn call_uniform4f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat, w: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: stencilOpSeparate
pub fn call_stencilOpSeparate(instance: *runtime.Instance, face: typedefs.GLenum, fail: typedefs.GLenum, zfail: typedefs.GLenum, zpass: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = face;
    _ = fail;
    _ = zfail;
    _ = zpass;
    return error.NotImplemented;
}

/// Operation: generateMipmap
pub fn call_generateMipmap(instance: *runtime.Instance, target: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = target;
    return error.NotImplemented;
}

/// Operation: getActiveAttrib
pub fn call_getActiveAttrib(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) anyerror!?*runtime.Instance {
    _ = instance;
    _ = program;
    _ = index;
    return null;
}

/// Operation: blendFunc
pub fn call_blendFunc(instance: *runtime.Instance, sfactor: typedefs.GLenum, dfactor: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = sfactor;
    _ = dfactor;
    return error.NotImplemented;
}

/// Operation: getFramebufferAttachmentParameter
pub fn call_getFramebufferAttachmentParameter(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: isEnabled
pub fn call_isEnabled(instance: *runtime.Instance, cap: typedefs.GLenum) anyerror!typedefs.GLboolean {
    _ = instance;
    _ = cap;
    return error.NotImplemented;
}

/// Operation: copyTexSubImage2D
pub fn call_copyTexSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
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

/// Operation: getContextAttributes
pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!?dictionaries.WebGLContextAttributes {
    _ = instance;
    return null;
}

/// Operation: isRenderbuffer
pub fn call_isRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    _ = instance;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: vertexAttrib2f
pub fn call_vertexAttrib2f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance, mask: typedefs.GLbitfield) anyerror!void {
    _ = instance;
    _ = mask;
    return error.NotImplemented;
}

/// Operation: deleteTexture
pub fn call_deleteTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = texture;
    return error.NotImplemented;
}

/// Operation: getShaderSource
pub fn call_getShaderSource(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    _ = shader;
    return null;
}

/// Operation: disable
pub fn call_disable(instance: *runtime.Instance, cap: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = cap;
    return error.NotImplemented;
}

/// Operation: compileShader
pub fn call_compileShader(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: blendEquationSeparate
pub fn call_blendEquationSeparate(instance: *runtime.Instance, modeRGB: typedefs.GLenum, modeAlpha: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = modeRGB;
    _ = modeAlpha;
    return error.NotImplemented;
}

/// Operation: depthMask
pub fn call_depthMask(instance: *runtime.Instance, flag: typedefs.GLboolean) anyerror!void {
    _ = instance;
    _ = flag;
    return error.NotImplemented;
}

/// Operation: depthRange
pub fn call_depthRange(instance: *runtime.Instance, zNear: typedefs.GLclampf, zFar: typedefs.GLclampf) anyerror!void {
    _ = instance;
    _ = zNear;
    _ = zFar;
    return error.NotImplemented;
}

/// Operation: polygonOffset
pub fn call_polygonOffset(instance: *runtime.Instance, factor: typedefs.GLfloat, units: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = factor;
    _ = units;
    return error.NotImplemented;
}

/// Operation: drawElements
pub fn call_drawElements(instance: *runtime.Instance, mode: typedefs.GLenum, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr) anyerror!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = @"type";
    _ = offset;
    return error.NotImplemented;
}

/// Operation: bindBuffer
pub fn call_bindBuffer(instance: *runtime.Instance, target: typedefs.GLenum, buffer: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = target;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: isShader
pub fn call_isShader(instance: *runtime.Instance, shader: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    _ = instance;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: getParameter
pub fn call_getParameter(instance: *runtime.Instance, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: makeXRCompatible
pub fn call_makeXRCompatible(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getSupportedExtensions
pub fn call_getSupportedExtensions(instance: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    return null;
}

/// Operation: clearStencil
pub fn call_clearStencil(instance: *runtime.Instance, s: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = s;
    return error.NotImplemented;
}

/// Operation: drawingBufferStorage
pub fn call_drawingBufferStorage(instance: *runtime.Instance, sizedFormat: typedefs.GLenum, width: u32, height: u32) anyerror!void {
    _ = instance;
    _ = sizedFormat;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: enable
pub fn call_enable(instance: *runtime.Instance, cap: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = cap;
    return error.NotImplemented;
}

/// Operation: renderbufferStorage
pub fn call_renderbufferStorage(instance: *runtime.Instance, target: typedefs.GLenum, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    _ = instance;
    _ = target;
    _ = internalformat;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: getVertexAttrib
pub fn call_getVertexAttrib(instance: *runtime.Instance, index: typedefs.GLuint, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = index;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: clearDepth
pub fn call_clearDepth(instance: *runtime.Instance, depth: typedefs.GLclampf) anyerror!void {
    _ = instance;
    _ = depth;
    return error.NotImplemented;
}

/// Operation: shaderSource
pub fn call_shaderSource(instance: *runtime.Instance, shader: *runtime.Instance, source: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = shader;
    _ = source;
    return error.NotImplemented;
}

/// Operation: blendFuncSeparate
pub fn call_blendFuncSeparate(instance: *runtime.Instance, srcRGB: typedefs.GLenum, dstRGB: typedefs.GLenum, srcAlpha: typedefs.GLenum, dstAlpha: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = srcRGB;
    _ = dstRGB;
    _ = srcAlpha;
    _ = dstAlpha;
    return error.NotImplemented;
}

/// Operation: detachShader
pub fn call_detachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = program;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: clearColor
pub fn call_clearColor(instance: *runtime.Instance, red: typedefs.GLclampf, green: typedefs.GLclampf, blue: typedefs.GLclampf, alpha: typedefs.GLclampf) anyerror!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    return error.NotImplemented;
}

/// Operation: getError
pub fn call_getError(instance: *runtime.Instance) anyerror!typedefs.GLenum {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: deleteRenderbuffer
pub fn call_deleteRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: vertexAttrib3fv
pub fn call_vertexAttrib3fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: activeTexture
pub fn call_activeTexture(instance: *runtime.Instance, texture: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = texture;
    return error.NotImplemented;
}

/// Operation: stencilFunc
pub fn call_stencilFunc(instance: *runtime.Instance, func: typedefs.GLenum, ref: typedefs.GLint, mask: typedefs.GLuint) anyerror!void {
    _ = instance;
    _ = func;
    _ = ref;
    _ = mask;
    return error.NotImplemented;
}

/// Operation: framebufferTexture2D
pub fn call_framebufferTexture2D(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, textarget: typedefs.GLenum, texture: ?*runtime.Instance, level: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = textarget;
    _ = texture;
    _ = level;
    return error.NotImplemented;
}

/// Operation: createProgram
pub fn call_createProgram(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getProgramInfoLog
pub fn call_getProgramInfoLog(instance: *runtime.Instance, program: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    _ = program;
    return null;
}

/// Operation: createShader
pub fn call_createShader(instance: *runtime.Instance, @"type": typedefs.GLenum) anyerror!?*runtime.Instance {
    _ = instance;
    _ = @"type";
    return null;
}

/// Operation: deleteProgram
pub fn call_deleteProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: useProgram
pub fn call_useProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: getTexParameter
pub fn call_getTexParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: blendColor
pub fn call_blendColor(instance: *runtime.Instance, red: typedefs.GLclampf, green: typedefs.GLclampf, blue: typedefs.GLclampf, alpha: typedefs.GLclampf) anyerror!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    return error.NotImplemented;
}

/// Operation: frontFace
pub fn call_frontFace(instance: *runtime.Instance, mode: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = mode;
    return error.NotImplemented;
}

/// Operation: isBuffer
pub fn call_isBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    _ = instance;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: bindTexture
pub fn call_bindTexture(instance: *runtime.Instance, target: typedefs.GLenum, texture: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = target;
    _ = texture;
    return error.NotImplemented;
}

/// Operation: uniform3f
pub fn call_uniform3f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    return error.NotImplemented;
}

/// Operation: blendEquation
pub fn call_blendEquation(instance: *runtime.Instance, mode: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = mode;
    return error.NotImplemented;
}

/// Operation: enableVertexAttribArray
pub fn call_enableVertexAttribArray(instance: *runtime.Instance, index: typedefs.GLuint) anyerror!void {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: bindFramebuffer
pub fn call_bindFramebuffer(instance: *runtime.Instance, target: typedefs.GLenum, framebuffer: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = target;
    _ = framebuffer;
    return error.NotImplemented;
}

/// Operation: stencilFuncSeparate
pub fn call_stencilFuncSeparate(instance: *runtime.Instance, face: typedefs.GLenum, func: typedefs.GLenum, ref: typedefs.GLint, mask: typedefs.GLuint) anyerror!void {
    _ = instance;
    _ = face;
    _ = func;
    _ = ref;
    _ = mask;
    return error.NotImplemented;
}

/// Operation: isFramebuffer
pub fn call_isFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    _ = instance;
    _ = framebuffer;
    return error.NotImplemented;
}

/// Operation: finish
pub fn call_finish(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: checkFramebufferStatus
pub fn call_checkFramebufferStatus(instance: *runtime.Instance, target: typedefs.GLenum) anyerror!typedefs.GLenum {
    _ = instance;
    _ = target;
    return error.NotImplemented;
}

/// Operation: getRenderbufferParameter
pub fn call_getRenderbufferParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: isTexture
pub fn call_isTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    _ = instance;
    _ = texture;
    return error.NotImplemented;
}

/// Operation: linkProgram
pub fn call_linkProgram(instance: *runtime.Instance, program: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: pixelStorei
pub fn call_pixelStorei(instance: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: framebufferRenderbuffer
pub fn call_framebufferRenderbuffer(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, renderbuffertarget: typedefs.GLenum, renderbuffer: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = renderbuffertarget;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: getActiveUniform
pub fn call_getActiveUniform(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) anyerror!?*runtime.Instance {
    _ = instance;
    _ = program;
    _ = index;
    return null;
}

/// Operation: stencilOp
pub fn call_stencilOp(instance: *runtime.Instance, fail: typedefs.GLenum, zfail: typedefs.GLenum, zpass: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = fail;
    _ = zfail;
    _ = zpass;
    return error.NotImplemented;
}

/// Operation: texParameteri
pub fn call_texParameteri(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum, param: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = target;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: vertexAttrib1f
pub fn call_vertexAttrib1f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = index;
    _ = x;
    return error.NotImplemented;
}

/// Operation: getShaderInfoLog
pub fn call_getShaderInfoLog(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    _ = shader;
    return null;
}

/// Operation: isContextLost
pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: deleteFramebuffer
pub fn call_deleteFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = framebuffer;
    return error.NotImplemented;
}

/// Operation: vertexAttrib3f
pub fn call_vertexAttrib3f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    return error.NotImplemented;
}

/// Operation: viewport
pub fn call_viewport(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: bindRenderbuffer
pub fn call_bindRenderbuffer(instance: *runtime.Instance, target: typedefs.GLenum, renderbuffer: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = target;
    _ = renderbuffer;
    return error.NotImplemented;
}

/// Operation: depthFunc
pub fn call_depthFunc(instance: *runtime.Instance, func: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = func;
    return error.NotImplemented;
}

/// Operation: bindAttribLocation
pub fn call_bindAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint, name: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = program;
    _ = index;
    _ = name;
    return error.NotImplemented;
}

/// Operation: hint
pub fn call_hint(instance: *runtime.Instance, target: typedefs.GLenum, mode: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = target;
    _ = mode;
    return error.NotImplemented;
}

/// Operation: getUniformLocation
pub fn call_getUniformLocation(instance: *runtime.Instance, program: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
    _ = instance;
    _ = program;
    _ = name;
    return null;
}

/// Operation: uniform1f
pub fn call_uniform1f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    return error.NotImplemented;
}

/// Operation: getExtension
pub fn call_getExtension(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*const anyopaque {
    _ = instance;
    _ = name;
    return null;
}

/// Operation: colorMask
pub fn call_colorMask(instance: *runtime.Instance, red: typedefs.GLboolean, green: typedefs.GLboolean, blue: typedefs.GLboolean, alpha: typedefs.GLboolean) anyerror!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    return error.NotImplemented;
}

/// Operation: cullFace
pub fn call_cullFace(instance: *runtime.Instance, mode: typedefs.GLenum) anyerror!void {
    _ = instance;
    _ = mode;
    return error.NotImplemented;
}

/// Operation: deleteShader
pub fn call_deleteShader(instance: *runtime.Instance, shader: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: vertexAttrib4fv
pub fn call_vertexAttrib4fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: disableVertexAttribArray
pub fn call_disableVertexAttribArray(instance: *runtime.Instance, index: typedefs.GLuint) anyerror!void {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: flush
pub fn call_flush(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getAttribLocation
pub fn call_getAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, name: runtime.DOMString) anyerror!typedefs.GLint {
    _ = instance;
    _ = program;
    _ = name;
    return error.NotImplemented;
}

/// Operation: getProgramParameter
pub fn call_getProgramParameter(instance: *runtime.Instance, program: *runtime.Instance, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = program;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: vertexAttrib2fv
pub fn call_vertexAttrib2fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: uniform3i
pub fn call_uniform3i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    return error.NotImplemented;
}

/// Operation: uniform2f
pub fn call_uniform2f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: drawArrays
pub fn call_drawArrays(instance: *runtime.Instance, mode: typedefs.GLenum, first: typedefs.GLint, count: typedefs.GLsizei) anyerror!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    return error.NotImplemented;
}

/// Operation: validateProgram
pub fn call_validateProgram(instance: *runtime.Instance, program: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: uniform2i
pub fn call_uniform2i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: vertexAttrib1fv
pub fn call_vertexAttrib1fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    _ = instance;
    _ = index;
    _ = values;
    return error.NotImplemented;
}

/// Operation: createBuffer
pub fn call_createBuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: scissor
pub fn call_scissor(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: getVertexAttribOffset
pub fn call_getVertexAttribOffset(instance: *runtime.Instance, index: typedefs.GLuint, pname: typedefs.GLenum) anyerror!typedefs.GLintptr {
    _ = instance;
    _ = index;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: getShaderParameter
pub fn call_getShaderParameter(instance: *runtime.Instance, shader: *runtime.Instance, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = shader;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: uniform4i
pub fn call_uniform4i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint, w: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    return error.NotImplemented;
}

/// Operation: isProgram
pub fn call_isProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    _ = instance;
    _ = program;
    return error.NotImplemented;
}

/// Operation: deleteBuffer
pub fn call_deleteBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: lineWidth
pub fn call_lineWidth(instance: *runtime.Instance, width: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = width;
    return error.NotImplemented;
}

/// Operation: stencilMask
pub fn call_stencilMask(instance: *runtime.Instance, mask: typedefs.GLuint) anyerror!void {
    _ = instance;
    _ = mask;
    return error.NotImplemented;
}

/// Operation: uniform1i
pub fn call_uniform1i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint) anyerror!void {
    _ = instance;
    _ = location;
    _ = x;
    return error.NotImplemented;
}

/// Operation: getShaderPrecisionFormat
pub fn call_getShaderPrecisionFormat(instance: *runtime.Instance, shadertype: typedefs.GLenum, precisiontype: typedefs.GLenum) anyerror!?*runtime.Instance {
    _ = instance;
    _ = shadertype;
    _ = precisiontype;
    return null;
}

/// Operation: getBufferParameter
pub fn call_getBufferParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) anyerror!*const anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: texParameterf
pub fn call_texParameterf(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum, param: typedefs.GLfloat) anyerror!void {
    _ = instance;
    _ = target;
    _ = pname;
    _ = param;
    return error.NotImplemented;
}

/// Operation: stencilMaskSeparate
pub fn call_stencilMaskSeparate(instance: *runtime.Instance, face: typedefs.GLenum, mask: typedefs.GLuint) anyerror!void {
    _ = instance;
    _ = face;
    _ = mask;
    return error.NotImplemented;
}

/// Operation: copyTexImage2D
pub fn call_copyTexImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLenum, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint) anyerror!void {
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

/// Operation: sampleCoverage
pub fn call_sampleCoverage(instance: *runtime.Instance, value: typedefs.GLclampf, invert: typedefs.GLboolean) anyerror!void {
    _ = instance;
    _ = value;
    _ = invert;
    return error.NotImplemented;
}

/// Operation: attachShader
pub fn call_attachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = program;
    _ = shader;
    return error.NotImplemented;
}

/// Operation: getUniform
pub fn call_getUniform(instance: *runtime.Instance, program: *runtime.Instance, location: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    _ = program;
    _ = location;
    return error.NotImplemented;
}

/// Operation: getAttachedShaders
pub fn call_getAttachedShaders(instance: *runtime.Instance, program: *runtime.Instance) anyerror!?*const anyopaque {
    _ = instance;
    _ = program;
    return null;
}
