//! Auto-generated mixin: WebGLRenderingContextOverloads
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WebGLRenderingContextOverloadsImpl = @import("impls").WebGLRenderingContextOverloads;

// Re-export types from impl
pub const impl = @import("impls").WebGLRenderingContextOverloads;

/// Arguments for texSubImage2D (WebIDL overloading)
pub const TexSubImage2DArgs = union(enum) {
    /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels)
    GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        pixels: ?typedefs.ArrayBufferView,
    },
    /// texSubImage2D(target, level, xoffset, yoffset, format, type, source)
    GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        source: typedefs.TexImageSource,
    },
};

pub fn call_texSubImage2D(instance: *runtime.Instance, args: TexSubImage2DArgs) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_texSubImage2D(instance, args);
}

pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, value: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniformMatrix4fv(instance, location, transpose, value);
}

pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, internalformat: typedefs.GLenum, width: typedefs.GLsizei, height: typedefs.GLsizei, border: typedefs.GLint, data: typedefs.ArrayBufferView) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_compressedTexImage2D(instance, target, level, internalformat, width, height, border, data);
}

pub fn call_uniform4iv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Int32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform4iv(instance, location, v);
}

/// Arguments for texImage2D (WebIDL overloading)
pub const TexImage2DArgs = union(enum) {
    /// texImage2D(target, level, internalformat, width, height, border, format, type, pixels)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        pixels: ?typedefs.ArrayBufferView,
    },
    /// texImage2D(target, level, internalformat, format, type, source)
    GLenum_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        source: typedefs.TexImageSource,
    },
};

pub fn call_texImage2D(instance: *runtime.Instance, args: TexImage2DArgs) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_texImage2D(instance, args);
}

pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, value: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniformMatrix3fv(instance, location, transpose, value);
}

/// Arguments for bufferData (WebIDL overloading)
pub const BufferDataArgs = union(enum) {
    /// bufferData(target, size, usage)
    GLenum_GLsizeiptr_GLenum: struct {
        target: typedefs.GLenum,
        size: typedefs.GLsizeiptr,
        usage: typedefs.GLenum,
    },
    /// bufferData(target, data, usage)
    GLenum_AllowSharedBufferSource_GLenum: struct {
        target: typedefs.GLenum,
        data: ?typedefs.AllowSharedBufferSource,
        usage: typedefs.GLenum,
    },
};

pub fn call_bufferData(instance: *runtime.Instance, args: BufferDataArgs) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_bufferData(instance, args);
}

pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: typedefs.GLenum, level: typedefs.GLint, xoffset: typedefs.GLint, yoffset: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, data: typedefs.ArrayBufferView) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_compressedTexSubImage2D(instance, target, level, xoffset, yoffset, width, height, format, data);
}

pub fn call_readPixels(instance: *runtime.Instance, x: typedefs.GLint, y: typedefs.GLint, width: typedefs.GLsizei, height: typedefs.GLsizei, format: typedefs.GLenum, @"type": typedefs.GLenum, pixels: ?typedefs.ArrayBufferView) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_readPixels(instance, x, y, width, height, format, @"type", pixels);
}

pub fn call_bufferSubData(instance: *runtime.Instance, target: typedefs.GLenum, offset: typedefs.GLintptr, data: typedefs.AllowSharedBufferSource) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_bufferSubData(instance, target, offset, data);
}

pub fn call_uniform4fv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform4fv(instance, location, v);
}

pub fn call_uniform3iv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Int32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform3iv(instance, location, v);
}

pub fn call_uniform3fv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform3fv(instance, location, v);
}

pub fn call_uniform1iv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Int32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform1iv(instance, location, v);
}

pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, value: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniformMatrix2fv(instance, location, transpose, value);
}

pub fn call_uniform2iv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Int32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform2iv(instance, location, v);
}

pub fn call_uniform2fv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform2fv(instance, location, v);
}

pub fn call_uniform1fv(instance: *runtime.Instance, location: ?*runtime.Instance, v: typedefs.Float32List) anyerror!void {
    return WebGLRenderingContextOverloadsImpl.call_uniform1fv(instance, location, v);
}

