//! Implementation for WebGL2RenderingContext interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebGL2RenderingContext = @import("interfaces").WebGL2RenderingContext;

pub const State = WebGL2RenderingContext.State;

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

