//! Auto-generated mixin: WebGLRenderingContextBase
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WebGLRenderingContextBaseImpl = @import("impls").WebGLRenderingContextBase;

// Re-export types from impl
pub const impl = @import("impls").WebGLRenderingContextBase;

pub fn get_canvas(instance: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.get_canvas(instance);
}

pub fn get_drawingBufferWidth(instance: *runtime.Instance) anyerror!typedefs.GLsizei {
    return WebGLRenderingContextBaseImpl.get_drawingBufferWidth(instance);
}

pub fn get_drawingBufferHeight(instance: *runtime.Instance) anyerror!typedefs.GLsizei {
    return WebGLRenderingContextBaseImpl.get_drawingBufferHeight(instance);
}

pub fn get_drawingBufferFormat(instance: *runtime.Instance) anyerror!typedefs.GLenum {
    return WebGLRenderingContextBaseImpl.get_drawingBufferFormat(instance);
}

pub fn get_drawingBufferColorSpace(instance: *runtime.Instance) anyerror!enums.PredefinedColorSpace {
    return WebGLRenderingContextBaseImpl.get_drawingBufferColorSpace(instance);
}

pub fn set_drawingBufferColorSpace(instance: *runtime.Instance, value: enums.PredefinedColorSpace) !void {
    return WebGLRenderingContextBaseImpl.set_drawingBufferColorSpace(instance, value);
}

pub fn get_unpackColorSpace(instance: *runtime.Instance) anyerror!enums.PredefinedColorSpace {
    return WebGLRenderingContextBaseImpl.get_unpackColorSpace(instance);
}

pub fn set_unpackColorSpace(instance: *runtime.Instance, value: enums.PredefinedColorSpace) !void {
    return WebGLRenderingContextBaseImpl.set_unpackColorSpace(instance, value);
}

pub fn call_generateMipmap(instance: *runtime.Instance, target: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_generateMipmap(instance, target);
}

pub fn call_viewport(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_viewport(instance, x, y, width, height);
}

pub fn call_drawElements(instance: *runtime.Instance, mode: typedefs.GLenum, count: typedefs.GLsizei, @"type": typedefs.GLenum, offset: typedefs.GLintptr) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_drawElements(instance, mode, count, @"type", offset);
}

pub fn call_vertexAttrib4f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat, w: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib4f(instance, index, x, y, z, w);
}

pub fn call_renderbufferStorage(instance: *runtime.Instance, target: typedefs.GLenum, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_renderbufferStorage(instance, target, internalformat, width, height);
}

pub fn call_bindAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint, name: typedefs.DOMString) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_bindAttribLocation(instance, program, index, name);
}

pub fn call_getVertexAttribOffset(instance: *runtime.Instance, index: typedefs.GLuint, pname: typedefs.GLenum) anyerror!typedefs.GLintptr {
    return WebGLRenderingContextBaseImpl.call_getVertexAttribOffset(instance, index, pname);
}

pub fn call_lineWidth(instance: *runtime.Instance, width: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_lineWidth(instance, width);
}

pub fn call_colorMask(instance: *runtime.Instance, red: typedefs.GLboolean, green: typedefs.GLboolean, blue: typedefs.GLboolean, alpha: typedefs.GLboolean) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_colorMask(instance, red, green, blue, alpha);
}

pub fn call_isTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGLRenderingContextBaseImpl.call_isTexture(instance, texture);
}

pub fn call_createBuffer(instance: *runtime.Instance) !*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_createBuffer(instance);
}

pub fn call_getTexParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getTexParameter(instance, target, pname);
}

pub fn call_getAttachedShaders(instance: *runtime.Instance, program: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_getAttachedShaders(instance, program);
}

pub fn call_stencilOpSeparate(instance: *runtime.Instance, face: typedefs.GLenum, fail: typedefs.GLenum, zfail: typedefs.GLenum, zpass: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_stencilOpSeparate(instance, face, fail, zfail, zpass);
}

pub fn call_deleteShader(instance: *runtime.Instance, shader: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_deleteShader(instance, shader);
}

pub fn call_getProgramInfoLog(instance: *runtime.Instance, program: *runtime.Instance) anyerror!typedefs.DOMString {
    return WebGLRenderingContextBaseImpl.call_getProgramInfoLog(instance, program);
}

pub fn call_pixelStorei(instance: *runtime.Instance, pname: typedefs.GLenum, param: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_pixelStorei(instance, pname, param);
}

pub fn call_copyTexSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_copyTexSubImage2D(instance, target, level, xoffset, yoffset, x, y, width, height);
}

pub fn call_texParameterf(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum, param: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_texParameterf(instance, target, pname, param);
}

pub fn call_blendFuncSeparate(instance: *runtime.Instance, srcRGB: typedefs.GLenum, dstRGB: typedefs.GLenum, srcAlpha: typedefs.GLenum, dstAlpha: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_blendFuncSeparate(instance, srcRGB, dstRGB, srcAlpha, dstAlpha);
}

pub fn call_isEnabled(instance: *runtime.Instance, cap: typedefs.GLenum) anyerror!typedefs.GLboolean {
    return WebGLRenderingContextBaseImpl.call_isEnabled(instance, cap);
}

pub fn call_drawArrays(instance: *runtime.Instance, mode: typedefs.GLenum, first: typedefs.GLint, count: typedefs.GLsizei) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_drawArrays(instance, mode, first, count);
}

pub fn call_createRenderbuffer(instance: *runtime.Instance) !*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_createRenderbuffer(instance);
}

pub fn call_depthMask(instance: *runtime.Instance, flag: typedefs.GLboolean) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_depthMask(instance, flag);
}

pub fn call_uniform4i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint, w: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform4i(instance, location, x, y, z, w);
}

pub fn call_blendEquation(instance: *runtime.Instance, mode: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_blendEquation(instance, mode);
}

pub fn call_stencilOp(instance: *runtime.Instance, fail: typedefs.GLenum, zfail: typedefs.GLenum, zpass: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_stencilOp(instance, fail, zfail, zpass);
}

pub fn call_getUniform(instance: *runtime.Instance, program: *runtime.Instance, location: *runtime.Instance) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getUniform(instance, program, location);
}

pub fn call_clearStencil(instance: *runtime.Instance, s: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_clearStencil(instance, s);
}

pub fn call_disable(instance: *runtime.Instance, cap: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_disable(instance, cap);
}

pub fn call_vertexAttrib1fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib1fv(instance, index, values);
}

pub fn call_getBufferParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getBufferParameter(instance, target, pname);
}

pub fn call_vertexAttrib2fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib2fv(instance, index, values);
}

pub fn call_makeXRCompatible(instance: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_makeXRCompatible(instance);
}

pub fn call_isShader(instance: *runtime.Instance, shader: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGLRenderingContextBaseImpl.call_isShader(instance, shader);
}

pub fn call_deleteRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_deleteRenderbuffer(instance, renderbuffer);
}

pub fn call_vertexAttrib1f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib1f(instance, index, x);
}

pub fn call_compileShader(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_compileShader(instance, shader);
}

pub fn call_getVertexAttrib(instance: *runtime.Instance, index: typedefs.GLuint, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getVertexAttrib(instance, index, pname);
}

pub fn call_isBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGLRenderingContextBaseImpl.call_isBuffer(instance, buffer);
}

pub fn call_createTexture(instance: *runtime.Instance) !*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_createTexture(instance);
}

pub fn call_blendFunc(instance: *runtime.Instance, sfactor: typedefs.GLenum, dfactor: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_blendFunc(instance, sfactor, dfactor);
}

pub fn call_uniform1f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform1f(instance, location, x);
}

pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
    return WebGLRenderingContextBaseImpl.call_isContextLost(instance);
}

pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!dictionaries.WebGLContextAttributes {
    return WebGLRenderingContextBaseImpl.call_getContextAttributes(instance);
}

pub fn call_getParameter(instance: *runtime.Instance, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getParameter(instance, pname);
}

pub fn call_sampleCoverage(instance: *runtime.Instance, value: typedefs.GLclampf, invert: typedefs.GLboolean) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_sampleCoverage(instance, value, invert);
}

pub fn call_texParameteri(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum, param: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_texParameteri(instance, target, pname, param);
}

pub fn call_framebufferTexture2D(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, textarget: typedefs.GLenum, texture: ?*runtime.Instance, level: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_framebufferTexture2D(instance, target, attachment, textarget, texture, level);
}

pub fn call_polygonOffset(instance: *runtime.Instance, factor: typedefs.GLfloat, units: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_polygonOffset(instance, factor, units);
}

pub fn call_cullFace(instance: *runtime.Instance, mode: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_cullFace(instance, mode);
}

pub fn call_stencilMask(instance: *runtime.Instance, mask: typedefs.GLuint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_stencilMask(instance, mask);
}

pub fn call_clearColor(instance: *runtime.Instance, red: typedefs.GLclampf, green: typedefs.GLclampf, blue: typedefs.GLclampf, alpha: typedefs.GLclampf) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_clearColor(instance, red, green, blue, alpha);
}

pub fn call_enableVertexAttribArray(instance: *runtime.Instance, index: typedefs.GLuint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_enableVertexAttribArray(instance, index);
}

pub fn call_flush(instance: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_flush(instance);
}

pub fn call_getSupportedExtensions(instance: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_getSupportedExtensions(instance);
}

pub fn call_attachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_attachShader(instance, program, shader);
}

pub fn call_deleteFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_deleteFramebuffer(instance, framebuffer);
}

pub fn call_getShaderInfoLog(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!typedefs.DOMString {
    return WebGLRenderingContextBaseImpl.call_getShaderInfoLog(instance, shader);
}

pub fn call_hint(instance: *runtime.Instance, target: typedefs.GLenum, mode: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_hint(instance, target, mode);
}

pub fn call_vertexAttrib4fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib4fv(instance, index, values);
}

pub fn call_bindTexture(instance: *runtime.Instance, target: typedefs.GLenum, texture: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_bindTexture(instance, target, texture);
}

pub fn call_copyTexImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLenum, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_copyTexImage2D(instance, target, level, internalformat, x, y, width, height, border);
}

pub fn call_getProgramParameter(instance: *runtime.Instance, program: *runtime.Instance, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getProgramParameter(instance, program, pname);
}

pub fn call_stencilFuncSeparate(instance: *runtime.Instance, face: typedefs.GLenum, func: typedefs.GLenum, ref: typedefs.GLint, mask: typedefs.GLuint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_stencilFuncSeparate(instance, face, func, ref, mask);
}

pub fn call_uniform2i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform2i(instance, location, x, y);
}

pub fn call_activeTexture(instance: *runtime.Instance, texture: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_activeTexture(instance, texture);
}

pub fn call_deleteBuffer(instance: *runtime.Instance, buffer: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_deleteBuffer(instance, buffer);
}

pub fn call_shaderSource(instance: *runtime.Instance, shader: *runtime.Instance, source: typedefs.DOMString) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_shaderSource(instance, shader, source);
}

pub fn call_scissor(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_scissor(instance, x, y, width, height);
}

pub fn call_uniform4f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat, w: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform4f(instance, location, x, y, z, w);
}

pub fn call_depthRange(instance: *runtime.Instance, zNear: typedefs.GLclampf, zFar: typedefs.GLclampf) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_depthRange(instance, zNear, zFar);
}

pub fn call_clear(instance: *runtime.Instance, mask: typedefs.GLbitfield) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_clear(instance, mask);
}

pub fn call_deleteTexture(instance: *runtime.Instance, texture: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_deleteTexture(instance, texture);
}

pub fn call_linkProgram(instance: *runtime.Instance, program: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_linkProgram(instance, program);
}

pub fn call_framebufferRenderbuffer(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, renderbuffertarget: typedefs.GLenum, renderbuffer: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_framebufferRenderbuffer(instance, target, attachment, renderbuffertarget, renderbuffer);
}

pub fn call_frontFace(instance: *runtime.Instance, mode: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_frontFace(instance, mode);
}

pub fn call_uniform3f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform3f(instance, location, x, y, z);
}

pub fn call_validateProgram(instance: *runtime.Instance, program: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_validateProgram(instance, program);
}

pub fn call_vertexAttribPointer(instance: *runtime.Instance, index: typedefs.GLuint, size: typedefs.GLint, @"type": typedefs.GLenum, normalized: typedefs.GLboolean, stride: typedefs.GLsizei, offset: typedefs.GLintptr) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttribPointer(instance, index, size, @"type", normalized, stride, offset);
}

pub fn call_createProgram(instance: *runtime.Instance) !*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_createProgram(instance);
}

pub fn call_disableVertexAttribArray(instance: *runtime.Instance, index: typedefs.GLuint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_disableVertexAttribArray(instance, index);
}

pub fn call_blendEquationSeparate(instance: *runtime.Instance, modeRGB: typedefs.GLenum, modeAlpha: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_blendEquationSeparate(instance, modeRGB, modeAlpha);
}

pub fn call_uniform3i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, z: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform3i(instance, location, x, y, z);
}

pub fn call_vertexAttrib3f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat, z: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib3f(instance, index, x, y, z);
}

pub fn call_getActiveAttrib(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) !?*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_getActiveAttrib(instance, program, index);
}

pub fn call_getShaderSource(instance: *runtime.Instance, shader: *runtime.Instance) anyerror!typedefs.DOMString {
    return WebGLRenderingContextBaseImpl.call_getShaderSource(instance, shader);
}

pub fn call_blendColor(instance: *runtime.Instance, red: typedefs.GLclampf, green: typedefs.GLclampf, blue: typedefs.GLclampf, alpha: typedefs.GLclampf) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_blendColor(instance, red, green, blue, alpha);
}

pub fn call_stencilFunc(instance: *runtime.Instance, func: typedefs.GLenum, ref: typedefs.GLint, mask: typedefs.GLuint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_stencilFunc(instance, func, ref, mask);
}

pub fn call_checkFramebufferStatus(instance: *runtime.Instance, target: typedefs.GLenum) anyerror!typedefs.GLenum {
    return WebGLRenderingContextBaseImpl.call_checkFramebufferStatus(instance, target);
}

pub fn call_bindBuffer(instance: *runtime.Instance, target: typedefs.GLenum, buffer: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_bindBuffer(instance, target, buffer);
}

pub fn call_getExtension(instance: *runtime.Instance, name: typedefs.DOMString) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getExtension(instance, name);
}

pub fn call_getShaderPrecisionFormat(instance: *runtime.Instance, shadertype: typedefs.GLenum, precisiontype: typedefs.GLenum) !?*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_getShaderPrecisionFormat(instance, shadertype, precisiontype);
}

pub fn call_isProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGLRenderingContextBaseImpl.call_isProgram(instance, program);
}

pub fn call_uniform2f(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLfloat, y: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform2f(instance, location, x, y);
}

pub fn call_isFramebuffer(instance: *runtime.Instance, framebuffer: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGLRenderingContextBaseImpl.call_isFramebuffer(instance, framebuffer);
}

pub fn call_finish(instance: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_finish(instance);
}

pub fn call_getAttribLocation(instance: *runtime.Instance, program: *runtime.Instance, name: typedefs.DOMString) anyerror!typedefs.GLint {
    return WebGLRenderingContextBaseImpl.call_getAttribLocation(instance, program, name);
}

pub fn call_isRenderbuffer(instance: *runtime.Instance, renderbuffer: ?*runtime.Instance) anyerror!typedefs.GLboolean {
    return WebGLRenderingContextBaseImpl.call_isRenderbuffer(instance, renderbuffer);
}

pub fn call_getActiveUniform(instance: *runtime.Instance, program: *runtime.Instance, index: typedefs.GLuint) !?*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_getActiveUniform(instance, program, index);
}

pub fn call_vertexAttrib3fv(instance: *runtime.Instance, index: typedefs.GLuint, values: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib3fv(instance, index, values);
}

pub fn call_getShaderParameter(instance: *runtime.Instance, shader: *runtime.Instance, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getShaderParameter(instance, shader, pname);
}

pub fn call_bindRenderbuffer(instance: *runtime.Instance, target: typedefs.GLenum, renderbuffer: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_bindRenderbuffer(instance, target, renderbuffer);
}

pub fn call_deleteProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_deleteProgram(instance, program);
}

pub fn call_createShader(instance: *runtime.Instance, @"type": typedefs.GLenum) !?*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_createShader(instance, @"type");
}

pub fn call_enable(instance: *runtime.Instance, cap: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_enable(instance, cap);
}

pub fn call_uniform1i(instance: *runtime.Instance, location: ?*runtime.Instance, x: typedefs.GLint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_uniform1i(instance, location, x);
}

pub fn call_bindFramebuffer(instance: *runtime.Instance, target: typedefs.GLenum, framebuffer: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_bindFramebuffer(instance, target, framebuffer);
}

pub fn call_createFramebuffer(instance: *runtime.Instance) !*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_createFramebuffer(instance);
}

pub fn call_depthFunc(instance: *runtime.Instance, func: typedefs.GLenum) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_depthFunc(instance, func);
}

pub fn call_getUniformLocation(instance: *runtime.Instance, program: *runtime.Instance, name: typedefs.DOMString) !?*runtime.Instance {
    return WebGLRenderingContextBaseImpl.call_getUniformLocation(instance, program, name);
}

pub fn call_stencilMaskSeparate(instance: *runtime.Instance, face: typedefs.GLenum, mask: typedefs.GLuint) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_stencilMaskSeparate(instance, face, mask);
}

pub fn call_useProgram(instance: *runtime.Instance, program: ?*runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_useProgram(instance, program);
}

pub fn call_vertexAttrib2f(instance: *runtime.Instance, index: typedefs.GLuint, x: typedefs.GLfloat, y: typedefs.GLfloat) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_vertexAttrib2f(instance, index, x, y);
}

pub fn call_drawingBufferStorage(instance: *runtime.Instance, sizedFormat: typedefs.GLenum, width: runtime.JSValue, height: runtime.JSValue) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_drawingBufferStorage(instance, sizedFormat, width, height);
}

pub fn call_getRenderbufferParameter(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getRenderbufferParameter(instance, target, pname);
}

pub fn call_detachShader(instance: *runtime.Instance, program: *runtime.Instance, shader: *runtime.Instance) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_detachShader(instance, program, shader);
}

pub fn call_clearDepth(instance: *runtime.Instance, depth: typedefs.GLclampf) anyerror!void {
    return WebGLRenderingContextBaseImpl.call_clearDepth(instance, depth);
}

pub fn call_getError(instance: *runtime.Instance) anyerror!typedefs.GLenum {
    return WebGLRenderingContextBaseImpl.call_getError(instance);
}

pub fn call_getFramebufferAttachmentParameter(instance: *runtime.Instance, target: typedefs.GLenum, attachment: typedefs.GLenum, pname: typedefs.GLenum) anyerror!runtime.JSValue {
    return WebGLRenderingContextBaseImpl.call_getFramebufferAttachmentParameter(instance, target, attachment, pname);
}

