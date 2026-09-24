//! Auto-generated mixin: WebGLRenderingContextBase
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebGLRenderingContextBaseImpl = @import("impls").WebGLRenderingContextBase;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WebGLTexture = @import("interfaces").WebGLTexture;
const WebGLActiveInfo = @import("interfaces").WebGLActiveInfo;
const WebGLShaderPrecisionFormat = @import("interfaces").WebGLShaderPrecisionFormat;
const OffscreenCanvas = @import("interfaces").OffscreenCanvas;
const GLboolean = @import("typedefs").GLboolean;
const GLfloat = @import("typedefs").GLfloat;
const WebGLRenderbuffer = @import("interfaces").WebGLRenderbuffer;
const WebGLContextAttributes = @import("dictionaries").WebGLContextAttributes;
const GLbitfield = @import("typedefs").GLbitfield;
const GLint = @import("typedefs").GLint;
const Float32List = @import("typedefs").Float32List;
const GLuint = @import("typedefs").GLuint;
const WebGLShader = @import("interfaces").WebGLShader;
const GLenum = @import("typedefs").GLenum;
const GLclampf = @import("typedefs").GLclampf;
const WebGLFramebuffer = @import("interfaces").WebGLFramebuffer;
const GLintptr = @import("typedefs").GLintptr;
const GLsizei = @import("typedefs").GLsizei;
const WebGLProgram = @import("interfaces").WebGLProgram;
const WebGLBuffer = @import("interfaces").WebGLBuffer;
const PredefinedColorSpace = @import("enums").PredefinedColorSpace;
const WebGLUniformLocation = @import("interfaces").WebGLUniformLocation;
const DOMString = @import("typedefs").DOMString;
const HTMLCanvasElement = @import("interfaces").HTMLCanvasElement;

pub const impl = @import("impls").WebGLRenderingContextBase;

pub fn get_canvas(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.get_canvas(instance);
}

pub fn get_drawingBufferWidth(instance: *runtime.Instance) anyerror!GLsizei {
    return try WebGLRenderingContextBaseImpl.get_drawingBufferWidth(instance);
}

pub fn get_drawingBufferHeight(instance: *runtime.Instance) anyerror!GLsizei {
    return try WebGLRenderingContextBaseImpl.get_drawingBufferHeight(instance);
}

pub fn get_drawingBufferFormat(instance: *runtime.Instance) anyerror!GLenum {
    return try WebGLRenderingContextBaseImpl.get_drawingBufferFormat(instance);
}

pub fn get_drawingBufferColorSpace(instance: *runtime.Instance) anyerror!PredefinedColorSpace {
    return try WebGLRenderingContextBaseImpl.get_drawingBufferColorSpace(instance);
}

pub fn set_drawingBufferColorSpace(instance: *runtime.Instance, value: PredefinedColorSpace) anyerror!void {
    try WebGLRenderingContextBaseImpl.set_drawingBufferColorSpace(instance, value);
}

pub fn get_unpackColorSpace(instance: *runtime.Instance) anyerror!PredefinedColorSpace {
    return try WebGLRenderingContextBaseImpl.get_unpackColorSpace(instance);
}

pub fn set_unpackColorSpace(instance: *runtime.Instance, value: PredefinedColorSpace) anyerror!void {
    try WebGLRenderingContextBaseImpl.set_unpackColorSpace(instance, value);
}

pub fn call_generateMipmap(instance: *runtime.Instance, target: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_generateMipmap(instance, target);
}

pub fn call_viewport(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_viewport(instance, x, y, width, height);
}

pub fn call_drawElements(instance: *runtime.Instance, mode: GLenum, count: GLsizei, @"type": GLenum, offset: GLintptr) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_drawElements(instance, mode, count, @"type", offset);
}

pub fn call_vertexAttrib4f(instance: *runtime.Instance, index: GLuint, x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib4f(instance, index, x, y, z, w);
}

pub fn call_renderbufferStorage(instance: *runtime.Instance, target: GLenum, internalformat: GLenum, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_renderbufferStorage(instance, target, internalformat, width, height);
}

pub fn call_bindAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, index: GLuint, name: DOMString) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_bindAttribLocation(instance, program, index, name);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_getVertexAttribOffset(instance: *runtime.Instance, index: GLuint, pname: GLenum) anyerror!GLintptr {
    return try WebGLRenderingContextBaseImpl.call_getVertexAttribOffset(instance, index, pname);
}

pub fn call_lineWidth(instance: *runtime.Instance, width: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_lineWidth(instance, width);
}

pub fn call_colorMask(instance: *runtime.Instance, red: GLboolean, green: GLboolean, blue: GLboolean, alpha: GLboolean) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_colorMask(instance, red, green, blue, alpha);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGLRenderingContextBaseImpl.call_isTexture(instance, texture);
}

pub fn call_createBuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_createBuffer(instance);
}

pub fn call_getTexParameter(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getTexParameter(instance, target, pname);
}

pub fn call_getAttachedShaders(instance: *runtime.Instance, program: *runtime.Instance) anyerror!?runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getAttachedShaders(instance, program);
}

pub fn call_stencilOpSeparate(instance: *runtime.Instance, face: GLenum, fail: GLenum, zfail: GLenum, zpass: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_stencilOpSeparate(instance, face, fail, zfail, zpass);
}

pub fn call_deleteShader(instance: *runtime.Instance, shader: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_deleteShader(instance, shader);
}

pub fn call_getProgramInfoLog(instance: *runtime.Instance, program: *runtime.Instance) anyerror!?DOMString {
    return try WebGLRenderingContextBaseImpl.call_getProgramInfoLog(instance, program);
}

pub fn call_pixelStorei(instance: *runtime.Instance, pname: GLenum, param: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_pixelStorei(instance, pname, param);
}

pub fn call_copyTexSubImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_copyTexSubImage2D(instance, target, level, xoffset, yoffset, x, y, width, height);
}

pub fn call_texParameterf(instance: *runtime.Instance, target: GLenum, pname: GLenum, param: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_texParameterf(instance, target, pname, param);
}

pub fn call_blendFuncSeparate(instance: *runtime.Instance, srcRGB: GLenum, dstRGB: GLenum, srcAlpha: GLenum, dstAlpha: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_blendFuncSeparate(instance, srcRGB, dstRGB, srcAlpha, dstAlpha);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isEnabled(instance: *runtime.Instance, cap: GLenum) anyerror!GLboolean {
    return try WebGLRenderingContextBaseImpl.call_isEnabled(instance, cap);
}

pub fn call_drawArrays(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_drawArrays(instance, mode, first, count);
}

pub fn call_createRenderbuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_createRenderbuffer(instance);
}

pub fn call_depthMask(instance: *runtime.Instance, flag: GLboolean) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_depthMask(instance, flag);
}

pub fn call_uniform4i(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLint, y: GLint, z: GLint, w: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform4i(instance, location, x, y, z, w);
}

pub fn call_blendEquation(instance: *runtime.Instance, mode: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_blendEquation(instance, mode);
}

pub fn call_stencilOp(instance: *runtime.Instance, fail: GLenum, zfail: GLenum, zpass: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_stencilOp(instance, fail, zfail, zpass);
}

pub fn call_getUniform(instance: *runtime.Instance, program: *runtime.Instance, location: *runtime.Instance) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getUniform(instance, program, location);
}

pub fn call_clearStencil(instance: *runtime.Instance, s: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_clearStencil(instance, s);
}

pub fn call_disable(instance: *runtime.Instance, cap: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_disable(instance, cap);
}

pub fn call_vertexAttrib1fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib1fv(instance, index, values);
}

pub fn call_getBufferParameter(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getBufferParameter(instance, target, pname);
}

pub fn call_vertexAttrib2fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib2fv(instance, index, values);
}

/// Extended attributes: [NewObject]
pub fn call_makeXRCompatible(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // [NewObject] - Caller owns the returned object
    return try WebGLRenderingContextBaseImpl.call_makeXRCompatible(instance);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isShader(instance: *runtime.Instance, shader: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGLRenderingContextBaseImpl.call_isShader(instance, shader);
}

pub fn call_deleteRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_deleteRenderbuffer(instance, renderbuffer);
}

pub fn call_vertexAttrib1f(instance: *runtime.Instance, index: GLuint, x: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib1f(instance, index, x);
}

pub fn call_compileShader(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_compileShader(instance, shader);
}

pub fn call_getVertexAttrib(instance: *runtime.Instance, index: GLuint, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getVertexAttrib(instance, index, pname);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGLRenderingContextBaseImpl.call_isBuffer(instance, buffer);
}

pub fn call_createTexture(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_createTexture(instance);
}

pub fn call_blendFunc(instance: *runtime.Instance, sfactor: GLenum, dfactor: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_blendFunc(instance, sfactor, dfactor);
}

pub fn call_uniform1f(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform1f(instance, location, x);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
    return try WebGLRenderingContextBaseImpl.call_isContextLost(instance);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!?WebGLContextAttributes {
    return try WebGLRenderingContextBaseImpl.call_getContextAttributes(instance);
}

pub fn call_getParameter(instance: *runtime.Instance, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getParameter(instance, pname);
}

pub fn call_sampleCoverage(instance: *runtime.Instance, value: GLclampf, invert: GLboolean) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_sampleCoverage(instance, value, invert);
}

pub fn call_texParameteri(instance: *runtime.Instance, target: GLenum, pname: GLenum, param: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_texParameteri(instance, target, pname, param);
}

pub fn call_framebufferTexture2D(instance: *runtime.Instance, target: GLenum, attachment: GLenum, textarget: GLenum, texture: ?*runtime.Instance, level: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_framebufferTexture2D(instance, target, attachment, textarget, texture, level);
}

pub fn call_polygonOffset(instance: *runtime.Instance, factor: GLfloat, units: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_polygonOffset(instance, factor, units);
}

pub fn call_cullFace(instance: *runtime.Instance, mode: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_cullFace(instance, mode);
}

pub fn call_stencilMask(instance: *runtime.Instance, mask: GLuint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_stencilMask(instance, mask);
}

pub fn call_clearColor(instance: *runtime.Instance, red: GLclampf, green: GLclampf, blue: GLclampf, alpha: GLclampf) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_clearColor(instance, red, green, blue, alpha);
}

pub fn call_enableVertexAttribArray(instance: *runtime.Instance, index: GLuint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_enableVertexAttribArray(instance, index);
}

pub fn call_flush(instance: *runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_flush(instance);
}

pub fn call_getSupportedExtensions(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getSupportedExtensions(instance);
}

pub fn call_attachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_attachShader(instance, program, shader);
}

pub fn call_deleteFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_deleteFramebuffer(instance, framebuffer);
}

pub fn call_getShaderInfoLog(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!?DOMString {
    return try WebGLRenderingContextBaseImpl.call_getShaderInfoLog(instance, shader);
}

pub fn call_hint(instance: *runtime.Instance, target: GLenum, mode: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_hint(instance, target, mode);
}

pub fn call_vertexAttrib4fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib4fv(instance, index, values);
}

pub fn call_bindTexture(instance: *runtime.Instance, target: GLenum, texture: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_bindTexture(instance, target, texture);
}

pub fn call_copyTexImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, x: GLint, y: GLint, width: GLsizei, height: GLsizei, border: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_copyTexImage2D(instance, target, level, internalformat, x, y, width, height, border);
}

pub fn call_getProgramParameter(instance: *runtime.Instance, program: *runtime.Instance, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getProgramParameter(instance, program, pname);
}

pub fn call_stencilFuncSeparate(instance: *runtime.Instance, face: GLenum, func: GLenum, ref: GLint, mask: GLuint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_stencilFuncSeparate(instance, face, func, ref, mask);
}

pub fn call_uniform2i(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLint, y: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform2i(instance, location, x, y);
}

pub fn call_activeTexture(instance: *runtime.Instance, texture: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_activeTexture(instance, texture);
}

pub fn call_deleteBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_deleteBuffer(instance, buffer);
}

pub fn call_shaderSource(instance: *runtime.Instance, shader: *runtime.Instance, source: DOMString) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_shaderSource(instance, shader, source);
}

pub fn call_scissor(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_scissor(instance, x, y, width, height);
}

pub fn call_uniform4f(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform4f(instance, location, x, y, z, w);
}

pub fn call_depthRange(instance: *runtime.Instance, zNear: GLclampf, zFar: GLclampf) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_depthRange(instance, zNear, zFar);
}

pub fn call_clear(instance: *runtime.Instance, mask: GLbitfield) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_clear(instance, mask);
}

pub fn call_deleteTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_deleteTexture(instance, texture);
}

pub fn call_linkProgram(instance: *runtime.Instance, program: *runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_linkProgram(instance, program);
}

pub fn call_framebufferRenderbuffer(instance: *runtime.Instance, target: GLenum, attachment: GLenum, renderbuffertarget: GLenum, renderbuffer: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_framebufferRenderbuffer(instance, target, attachment, renderbuffertarget, renderbuffer);
}

pub fn call_frontFace(instance: *runtime.Instance, mode: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_frontFace(instance, mode);
}

pub fn call_uniform3f(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLfloat, y: GLfloat, z: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform3f(instance, location, x, y, z);
}

pub fn call_validateProgram(instance: *runtime.Instance, program: *runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_validateProgram(instance, program);
}

pub fn call_vertexAttribPointer(instance: *runtime.Instance, index: GLuint, size: GLint, @"type": GLenum, normalized: GLboolean, stride: GLsizei, offset: GLintptr) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttribPointer(instance, index, size, @"type", normalized, stride, offset);
}

pub fn call_createProgram(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_createProgram(instance);
}

pub fn call_disableVertexAttribArray(instance: *runtime.Instance, index: GLuint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_disableVertexAttribArray(instance, index);
}

pub fn call_blendEquationSeparate(instance: *runtime.Instance, modeRGB: GLenum, modeAlpha: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_blendEquationSeparate(instance, modeRGB, modeAlpha);
}

pub fn call_uniform3i(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLint, y: GLint, z: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform3i(instance, location, x, y, z);
}

pub fn call_vertexAttrib3f(instance: *runtime.Instance, index: GLuint, x: GLfloat, y: GLfloat, z: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib3f(instance, index, x, y, z);
}

pub fn call_getActiveAttrib(instance: *runtime.Instance, program: *runtime.Instance, index: GLuint) anyerror!?*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_getActiveAttrib(instance, program, index);
}

pub fn call_getShaderSource(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!?DOMString {
    return try WebGLRenderingContextBaseImpl.call_getShaderSource(instance, shader);
}

pub fn call_blendColor(instance: *runtime.Instance, red: GLclampf, green: GLclampf, blue: GLclampf, alpha: GLclampf) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_blendColor(instance, red, green, blue, alpha);
}

pub fn call_stencilFunc(instance: *runtime.Instance, func: GLenum, ref: GLint, mask: GLuint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_stencilFunc(instance, func, ref, mask);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_checkFramebufferStatus(instance: *runtime.Instance, target: GLenum) anyerror!GLenum {
    return try WebGLRenderingContextBaseImpl.call_checkFramebufferStatus(instance, target);
}

pub fn call_bindBuffer(instance: *runtime.Instance, target: GLenum, buffer: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_bindBuffer(instance, target, buffer);
}

pub fn call_getExtension(instance: *runtime.Instance, name: DOMString) anyerror!?runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getExtension(instance, name);
}

pub fn call_getShaderPrecisionFormat(instance: *runtime.Instance, shadertype: GLenum, precisiontype: GLenum) anyerror!?*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_getShaderPrecisionFormat(instance, shadertype, precisiontype);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGLRenderingContextBaseImpl.call_isProgram(instance, program);
}

pub fn call_uniform2f(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLfloat, y: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform2f(instance, location, x, y);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGLRenderingContextBaseImpl.call_isFramebuffer(instance, framebuffer);
}

pub fn call_finish(instance: *runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_finish(instance);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_getAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, name: DOMString) anyerror!GLint {
    return try WebGLRenderingContextBaseImpl.call_getAttribLocation(instance, program, name);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_isRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) anyerror!GLboolean {
    return try WebGLRenderingContextBaseImpl.call_isRenderbuffer(instance, renderbuffer);
}

pub fn call_getActiveUniform(instance: *runtime.Instance, program: *runtime.Instance, index: GLuint) anyerror!?*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_getActiveUniform(instance, program, index);
}

pub fn call_vertexAttrib3fv(instance: *runtime.Instance, index: GLuint, values: Float32List) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib3fv(instance, index, values);
}

pub fn call_getShaderParameter(instance: *runtime.Instance, shader: *runtime.Instance, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getShaderParameter(instance, shader, pname);
}

pub fn call_bindRenderbuffer(instance: *runtime.Instance, target: GLenum, renderbuffer: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_bindRenderbuffer(instance, target, renderbuffer);
}

pub fn call_deleteProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_deleteProgram(instance, program);
}

pub fn call_createShader(instance: *runtime.Instance, @"type": GLenum) anyerror!?*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_createShader(instance, @"type");
}

pub fn call_enable(instance: *runtime.Instance, cap: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_enable(instance, cap);
}

pub fn call_uniform1i(instance: *runtime.Instance, location: ?*runtime.Instance, x: GLint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_uniform1i(instance, location, x);
}

pub fn call_bindFramebuffer(instance: *runtime.Instance, target: GLenum, framebuffer: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_bindFramebuffer(instance, target, framebuffer);
}

pub fn call_createFramebuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_createFramebuffer(instance);
}

pub fn call_depthFunc(instance: *runtime.Instance, func: GLenum) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_depthFunc(instance, func);
}

pub fn call_getUniformLocation(instance: *runtime.Instance, program: *runtime.Instance, name: DOMString) anyerror!?*runtime.Instance {
    return try WebGLRenderingContextBaseImpl.call_getUniformLocation(instance, program, name);
}

pub fn call_stencilMaskSeparate(instance: *runtime.Instance, face: GLenum, mask: GLuint) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_stencilMaskSeparate(instance, face, mask);
}

pub fn call_useProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_useProgram(instance, program);
}

pub fn call_vertexAttrib2f(instance: *runtime.Instance, index: GLuint, x: GLfloat, y: GLfloat) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_vertexAttrib2f(instance, index, x, y);
}

pub fn call_drawingBufferStorage(instance: *runtime.Instance, sizedFormat: GLenum, width: u32, height: u32) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_drawingBufferStorage(instance, sizedFormat, width, height);
}

pub fn call_getRenderbufferParameter(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getRenderbufferParameter(instance, target, pname);
}

pub fn call_detachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_detachShader(instance, program, shader);
}

pub fn call_clearDepth(instance: *runtime.Instance, depth: GLclampf) anyerror!void {
    return try WebGLRenderingContextBaseImpl.call_clearDepth(instance, depth);
}

/// Extended attributes: [WebGLHandlesContextLoss]
pub fn call_getError(instance: *runtime.Instance) anyerror!GLenum {
    return try WebGLRenderingContextBaseImpl.call_getError(instance);
}

pub fn call_getFramebufferAttachmentParameter(instance: *runtime.Instance, target: GLenum, attachment: GLenum, pname: GLenum) anyerror!runtime.JSValue {
    return try WebGLRenderingContextBaseImpl.call_getFramebufferAttachmentParameter(instance, target, attachment, pname);
}
