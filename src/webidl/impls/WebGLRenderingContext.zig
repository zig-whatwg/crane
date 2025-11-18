//! Implementation for WebGLRenderingContext interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebGLRenderingContext = @import("interfaces").WebGLRenderingContext;

pub const State = WebGLRenderingContext.State;

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

/// Getter for canvas
pub fn get_canvas(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for drawingBufferWidth
pub fn get_drawingBufferWidth(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for drawingBufferHeight
pub fn get_drawingBufferHeight(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for drawingBufferFormat
pub fn get_drawingBufferFormat(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for drawingBufferColorSpace
pub fn get_drawingBufferColorSpace(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for unpackColorSpace
pub fn get_unpackColorSpace(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for drawingBufferColorSpace
pub fn set_drawingBufferColorSpace(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for unpackColorSpace
pub fn set_unpackColorSpace(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: getContextAttributes
pub fn call_getContextAttributes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isContextLost
pub fn call_isContextLost(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getSupportedExtensions
pub fn call_getSupportedExtensions(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getExtension
pub fn call_getExtension(instance: *runtime.Instance, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawingBufferStorage
pub fn call_drawingBufferStorage(instance: *runtime.Instance, sizedFormat: anyopaque, width: u32, height: u32) ImplError!void {
    _ = instance;
    _ = sizedFormat;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: activeTexture
pub fn call_activeTexture(instance: *runtime.Instance, texture: anyopaque) ImplError!void {
    _ = instance;
    _ = texture;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: attachShader
pub fn call_attachShader(instance: *runtime.Instance, program: anyopaque, shader: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindAttribLocation
pub fn call_bindAttribLocation(instance: *runtime.Instance, program: anyopaque, index: anyopaque, name: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = program;
    _ = index;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindBuffer
pub fn call_bindBuffer(instance: *runtime.Instance, target: anyopaque, buffer: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = buffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindFramebuffer
pub fn call_bindFramebuffer(instance: *runtime.Instance, target: anyopaque, framebuffer: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = framebuffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindRenderbuffer
pub fn call_bindRenderbuffer(instance: *runtime.Instance, target: anyopaque, renderbuffer: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = renderbuffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bindTexture
pub fn call_bindTexture(instance: *runtime.Instance, target: anyopaque, texture: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = texture;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendColor
pub fn call_blendColor(instance: *runtime.Instance, red: anyopaque, green: anyopaque, blue: anyopaque, alpha: anyopaque) ImplError!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendEquation
pub fn call_blendEquation(instance: *runtime.Instance, mode: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendEquationSeparate
pub fn call_blendEquationSeparate(instance: *runtime.Instance, modeRGB: anyopaque, modeAlpha: anyopaque) ImplError!void {
    _ = instance;
    _ = modeRGB;
    _ = modeAlpha;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendFunc
pub fn call_blendFunc(instance: *runtime.Instance, sfactor: anyopaque, dfactor: anyopaque) ImplError!void {
    _ = instance;
    _ = sfactor;
    _ = dfactor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: blendFuncSeparate
pub fn call_blendFuncSeparate(instance: *runtime.Instance, srcRGB: anyopaque, dstRGB: anyopaque, srcAlpha: anyopaque, dstAlpha: anyopaque) ImplError!void {
    _ = instance;
    _ = srcRGB;
    _ = dstRGB;
    _ = srcAlpha;
    _ = dstAlpha;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: checkFramebufferStatus
pub fn call_checkFramebufferStatus(instance: *runtime.Instance, target: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance, mask: anyopaque) ImplError!void {
    _ = instance;
    _ = mask;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearColor
pub fn call_clearColor(instance: *runtime.Instance, red: anyopaque, green: anyopaque, blue: anyopaque, alpha: anyopaque) ImplError!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearDepth
pub fn call_clearDepth(instance: *runtime.Instance, depth: anyopaque) ImplError!void {
    _ = instance;
    _ = depth;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearStencil
pub fn call_clearStencil(instance: *runtime.Instance, s: anyopaque) ImplError!void {
    _ = instance;
    _ = s;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: colorMask
pub fn call_colorMask(instance: *runtime.Instance, red: anyopaque, green: anyopaque, blue: anyopaque, alpha: anyopaque) ImplError!void {
    _ = instance;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compileShader
pub fn call_compileShader(instance: *runtime.Instance, shader: anyopaque) ImplError!void {
    _ = instance;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyTexImage2D
pub fn call_copyTexImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = border;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyTexSubImage2D
pub fn call_copyTexSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createBuffer
pub fn call_createBuffer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createFramebuffer
pub fn call_createFramebuffer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createProgram
pub fn call_createProgram(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createRenderbuffer
pub fn call_createRenderbuffer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createShader
pub fn call_createShader(instance: *runtime.Instance, type: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createTexture
pub fn call_createTexture(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cullFace
pub fn call_cullFace(instance: *runtime.Instance, mode: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteBuffer
pub fn call_deleteBuffer(instance: *runtime.Instance, buffer: anyopaque) ImplError!void {
    _ = instance;
    _ = buffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteFramebuffer
pub fn call_deleteFramebuffer(instance: *runtime.Instance, framebuffer: anyopaque) ImplError!void {
    _ = instance;
    _ = framebuffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteProgram
pub fn call_deleteProgram(instance: *runtime.Instance, program: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteRenderbuffer
pub fn call_deleteRenderbuffer(instance: *runtime.Instance, renderbuffer: anyopaque) ImplError!void {
    _ = instance;
    _ = renderbuffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteShader
pub fn call_deleteShader(instance: *runtime.Instance, shader: anyopaque) ImplError!void {
    _ = instance;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteTexture
pub fn call_deleteTexture(instance: *runtime.Instance, texture: anyopaque) ImplError!void {
    _ = instance;
    _ = texture;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: depthFunc
pub fn call_depthFunc(instance: *runtime.Instance, func: anyopaque) ImplError!void {
    _ = instance;
    _ = func;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: depthMask
pub fn call_depthMask(instance: *runtime.Instance, flag: anyopaque) ImplError!void {
    _ = instance;
    _ = flag;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: depthRange
pub fn call_depthRange(instance: *runtime.Instance, zNear: anyopaque, zFar: anyopaque) ImplError!void {
    _ = instance;
    _ = zNear;
    _ = zFar;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: detachShader
pub fn call_detachShader(instance: *runtime.Instance, program: anyopaque, shader: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disable
pub fn call_disable(instance: *runtime.Instance, cap: anyopaque) ImplError!void {
    _ = instance;
    _ = cap;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disableVertexAttribArray
pub fn call_disableVertexAttribArray(instance: *runtime.Instance, index: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawArrays
pub fn call_drawArrays(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = first;
    _ = count;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawElements
pub fn call_drawElements(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    _ = count;
    _ = type;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: enable
pub fn call_enable(instance: *runtime.Instance, cap: anyopaque) ImplError!void {
    _ = instance;
    _ = cap;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: enableVertexAttribArray
pub fn call_enableVertexAttribArray(instance: *runtime.Instance, index: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: finish
pub fn call_finish(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: flush
pub fn call_flush(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: framebufferRenderbuffer
pub fn call_framebufferRenderbuffer(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, renderbuffertarget: anyopaque, renderbuffer: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = renderbuffertarget;
    _ = renderbuffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: framebufferTexture2D
pub fn call_framebufferTexture2D(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, textarget: anyopaque, texture: anyopaque, level: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = textarget;
    _ = texture;
    _ = level;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: frontFace
pub fn call_frontFace(instance: *runtime.Instance, mode: anyopaque) ImplError!void {
    _ = instance;
    _ = mode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: generateMipmap
pub fn call_generateMipmap(instance: *runtime.Instance, target: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getActiveAttrib
pub fn call_getActiveAttrib(instance: *runtime.Instance, program: anyopaque, index: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getActiveUniform
pub fn call_getActiveUniform(instance: *runtime.Instance, program: anyopaque, index: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttachedShaders
pub fn call_getAttachedShaders(instance: *runtime.Instance, program: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttribLocation
pub fn call_getAttribLocation(instance: *runtime.Instance, program: anyopaque, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getBufferParameter
pub fn call_getBufferParameter(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getParameter
pub fn call_getParameter(instance: *runtime.Instance, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getError
pub fn call_getError(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getFramebufferAttachmentParameter
pub fn call_getFramebufferAttachmentParameter(instance: *runtime.Instance, target: anyopaque, attachment: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = attachment;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getProgramParameter
pub fn call_getProgramParameter(instance: *runtime.Instance, program: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getProgramInfoLog
pub fn call_getProgramInfoLog(instance: *runtime.Instance, program: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getRenderbufferParameter
pub fn call_getRenderbufferParameter(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getShaderParameter
pub fn call_getShaderParameter(instance: *runtime.Instance, shader: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = shader;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getShaderPrecisionFormat
pub fn call_getShaderPrecisionFormat(instance: *runtime.Instance, shadertype: anyopaque, precisiontype: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = shadertype;
    _ = precisiontype;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getShaderInfoLog
pub fn call_getShaderInfoLog(instance: *runtime.Instance, shader: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getShaderSource
pub fn call_getShaderSource(instance: *runtime.Instance, shader: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getTexParameter
pub fn call_getTexParameter(instance: *runtime.Instance, target: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getUniform
pub fn call_getUniform(instance: *runtime.Instance, program: anyopaque, location: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = location;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getUniformLocation
pub fn call_getUniformLocation(instance: *runtime.Instance, program: anyopaque, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = program;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getVertexAttrib
pub fn call_getVertexAttrib(instance: *runtime.Instance, index: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = index;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getVertexAttribOffset
pub fn call_getVertexAttribOffset(instance: *runtime.Instance, index: anyopaque, pname: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = index;
    _ = pname;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: hint
pub fn call_hint(instance: *runtime.Instance, target: anyopaque, mode: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = mode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isBuffer
pub fn call_isBuffer(instance: *runtime.Instance, buffer: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = buffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isEnabled
pub fn call_isEnabled(instance: *runtime.Instance, cap: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = cap;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isFramebuffer
pub fn call_isFramebuffer(instance: *runtime.Instance, framebuffer: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = framebuffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isProgram
pub fn call_isProgram(instance: *runtime.Instance, program: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = program;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isRenderbuffer
pub fn call_isRenderbuffer(instance: *runtime.Instance, renderbuffer: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = renderbuffer;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isShader
pub fn call_isShader(instance: *runtime.Instance, shader: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = shader;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isTexture
pub fn call_isTexture(instance: *runtime.Instance, texture: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = texture;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lineWidth
pub fn call_lineWidth(instance: *runtime.Instance, width: anyopaque) ImplError!void {
    _ = instance;
    _ = width;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: linkProgram
pub fn call_linkProgram(instance: *runtime.Instance, program: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pixelStorei
pub fn call_pixelStorei(instance: *runtime.Instance, pname: anyopaque, param: anyopaque) ImplError!void {
    _ = instance;
    _ = pname;
    _ = param;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: polygonOffset
pub fn call_polygonOffset(instance: *runtime.Instance, factor: anyopaque, units: anyopaque) ImplError!void {
    _ = instance;
    _ = factor;
    _ = units;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: renderbufferStorage
pub fn call_renderbufferStorage(instance: *runtime.Instance, target: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = internalformat;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: sampleCoverage
pub fn call_sampleCoverage(instance: *runtime.Instance, value: anyopaque, invert: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    _ = invert;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: scissor
pub fn call_scissor(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: shaderSource
pub fn call_shaderSource(instance: *runtime.Instance, shader: anyopaque, source: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = shader;
    _ = source;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stencilFunc
pub fn call_stencilFunc(instance: *runtime.Instance, func: anyopaque, ref: anyopaque, mask: anyopaque) ImplError!void {
    _ = instance;
    _ = func;
    _ = ref;
    _ = mask;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stencilFuncSeparate
pub fn call_stencilFuncSeparate(instance: *runtime.Instance, face: anyopaque, func: anyopaque, ref: anyopaque, mask: anyopaque) ImplError!void {
    _ = instance;
    _ = face;
    _ = func;
    _ = ref;
    _ = mask;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stencilMask
pub fn call_stencilMask(instance: *runtime.Instance, mask: anyopaque) ImplError!void {
    _ = instance;
    _ = mask;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stencilMaskSeparate
pub fn call_stencilMaskSeparate(instance: *runtime.Instance, face: anyopaque, mask: anyopaque) ImplError!void {
    _ = instance;
    _ = face;
    _ = mask;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stencilOp
pub fn call_stencilOp(instance: *runtime.Instance, fail: anyopaque, zfail: anyopaque, zpass: anyopaque) ImplError!void {
    _ = instance;
    _ = fail;
    _ = zfail;
    _ = zpass;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: stencilOpSeparate
pub fn call_stencilOpSeparate(instance: *runtime.Instance, face: anyopaque, fail: anyopaque, zfail: anyopaque, zpass: anyopaque) ImplError!void {
    _ = instance;
    _ = face;
    _ = fail;
    _ = zfail;
    _ = zpass;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texParameterf
pub fn call_texParameterf(instance: *runtime.Instance, target: anyopaque, pname: anyopaque, param: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = pname;
    _ = param;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: texParameteri
pub fn call_texParameteri(instance: *runtime.Instance, target: anyopaque, pname: anyopaque, param: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = pname;
    _ = param;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1f
pub fn call_uniform1f(instance: *runtime.Instance, location: anyopaque, x: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2f
pub fn call_uniform2f(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3f
pub fn call_uniform3f(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4f
pub fn call_uniform4f(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1i
pub fn call_uniform1i(instance: *runtime.Instance, location: anyopaque, x: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2i
pub fn call_uniform2i(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3i
pub fn call_uniform3i(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4i
pub fn call_uniform4i(instance: *runtime.Instance, location: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: useProgram
pub fn call_useProgram(instance: *runtime.Instance, program: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: validateProgram
pub fn call_validateProgram(instance: *runtime.Instance, program: anyopaque) ImplError!void {
    _ = instance;
    _ = program;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib1f
pub fn call_vertexAttrib1f(instance: *runtime.Instance, index: anyopaque, x: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib2f
pub fn call_vertexAttrib2f(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib3f
pub fn call_vertexAttrib3f(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib4f
pub fn call_vertexAttrib4f(instance: *runtime.Instance, index: anyopaque, x: anyopaque, y: anyopaque, z: anyopaque, w: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = x;
    _ = y;
    _ = z;
    _ = w;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib1fv
pub fn call_vertexAttrib1fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib2fv
pub fn call_vertexAttrib2fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib3fv
pub fn call_vertexAttrib3fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttrib4fv
pub fn call_vertexAttrib4fv(instance: *runtime.Instance, index: anyopaque, values: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = values;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: vertexAttribPointer
pub fn call_vertexAttribPointer(instance: *runtime.Instance, index: anyopaque, size: anyopaque, type: anyopaque, normalized: anyopaque, stride: anyopaque, offset: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = size;
    _ = type;
    _ = normalized;
    _ = stride;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: viewport
pub fn call_viewport(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: makeXRCompatible
pub fn call_makeXRCompatible(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
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
pub fn call_bufferData(instance: *runtime.Instance, target: anyopaque, data: anyopaque, usage: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = data;
    _ = usage;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bufferSubData
pub fn call_bufferSubData(instance: *runtime.Instance, target: anyopaque, offset: anyopaque, data: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = offset;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexImage2D
pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, data: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = internalformat;
    _ = width;
    _ = height;
    _ = border;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compressedTexSubImage2D
pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, data: anyopaque) ImplError!void {
    _ = instance;
    _ = target;
    _ = level;
    _ = xoffset;
    _ = yoffset;
    _ = width;
    _ = height;
    _ = format;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: readPixels
pub fn call_readPixels(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type: anyopaque, pixels: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = format;
    _ = type;
    _ = pixels;
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

/// Operation: uniform1fv
pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2fv
pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3fv
pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4fv
pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform1iv
pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform2iv
pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform3iv
pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniform4iv
pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = v;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix2fv
pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix3fv
pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: uniformMatrix4fv
pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) ImplError!void {
    _ = instance;
    _ = location;
    _ = transpose;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

