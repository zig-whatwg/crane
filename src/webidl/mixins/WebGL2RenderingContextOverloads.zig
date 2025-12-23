//! Auto-generated mixin: WebGL2RenderingContextOverloads
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WebGL2RenderingContextOverloadsImpl = @import("impls").WebGL2RenderingContextOverloads;

// Re-export types from impl
pub const impl = @import("impls").WebGL2RenderingContextOverloads;

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
    /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pboOffset)
    GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        pboOffset: typedefs.GLintptr,
    },
    /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, source)
    GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        source: typedefs.TexImageSource,
    },
    /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, srcData, srcOffset)
    GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_unsigned_long_long: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        srcData: typedefs.ArrayBufferView,
        srcOffset: runtime.JSValue,
    },
};

pub fn call_texSubImage2D(instance: *runtime.Instance, args: TexSubImage2DArgs) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_texSubImage2D(instance, args);
}

pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniformMatrix4fv(instance, location, transpose, data, srcOffset, srcLength);
}

/// Arguments for compressedTexImage2D (WebIDL overloading)
pub const CompressedTexImage2DArgs = union(enum) {
    /// compressedTexImage2D(target, level, internalformat, width, height, border, imageSize, offset)
    GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLenum,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        border: typedefs.GLint,
        imageSize: typedefs.GLsizei,
        offset: typedefs.GLintptr,
    },
    /// compressedTexImage2D(target, level, internalformat, width, height, border, srcData, srcOffset, srcLengthOverride)
    GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_unsigned_long_long_GLuint: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLenum,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        border: typedefs.GLint,
        srcData: typedefs.ArrayBufferView,
        srcOffset: webidl.Opt(runtime.JSValue),
        srcLengthOverride: webidl.Opt(typedefs.GLuint),
    },
};

pub fn call_compressedTexImage2D(instance: *runtime.Instance, args: CompressedTexImage2DArgs) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_compressedTexImage2D(instance, args);
}

pub fn call_uniform4iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform4iv(instance, location, data, srcOffset, srcLength);
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
    /// texImage2D(target, level, internalformat, width, height, border, format, type, pboOffset)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        pboOffset: typedefs.GLintptr,
    },
    /// texImage2D(target, level, internalformat, width, height, border, format, type, source)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        source: typedefs.TexImageSource,
    },
    /// texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset)
    GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_unsigned_long_long: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        internalformat: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        border: typedefs.GLint,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        srcData: typedefs.ArrayBufferView,
        srcOffset: runtime.JSValue,
    },
};

pub fn call_texImage2D(instance: *runtime.Instance, args: TexImage2DArgs) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_texImage2D(instance, args);
}

pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniformMatrix3fv(instance, location, transpose, data, srcOffset, srcLength);
}

/// Arguments for compressedTexSubImage2D (WebIDL overloading)
pub const CompressedTexSubImage2DArgs = union(enum) {
    /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, offset)
    GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        imageSize: typedefs.GLsizei,
        offset: typedefs.GLintptr,
    },
    /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, srcData, srcOffset, srcLengthOverride)
    GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_unsigned_long_long_GLuint: struct {
        target: typedefs.GLenum,
        level: typedefs.GLint,
        xoffset: typedefs.GLint,
        yoffset: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        srcData: typedefs.ArrayBufferView,
        srcOffset: webidl.Opt(runtime.JSValue),
        srcLengthOverride: webidl.Opt(typedefs.GLuint),
    },
};

pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, args: CompressedTexSubImage2DArgs) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_compressedTexSubImage2D(instance, args);
}

/// Arguments for bufferData (WebIDL overloading)
pub const BufferDataArgs = union(enum) {
    /// bufferData(target, size, usage)
    GLenum_GLsizeiptr_GLenum: struct {
        target: typedefs.GLenum,
        size: typedefs.GLsizeiptr,
        usage: typedefs.GLenum,
    },
    /// bufferData(target, srcData, usage)
    GLenum_AllowSharedBufferSource_GLenum: struct {
        target: typedefs.GLenum,
        srcData: ?typedefs.AllowSharedBufferSource,
        usage: typedefs.GLenum,
    },
    /// bufferData(target, srcData, usage, srcOffset, length)
    GLenum_ArrayBufferView_GLenum_unsigned_long_long_GLuint: struct {
        target: typedefs.GLenum,
        srcData: typedefs.ArrayBufferView,
        usage: typedefs.GLenum,
        srcOffset: runtime.JSValue,
        length: webidl.Opt(typedefs.GLuint),
    },
};

pub fn call_bufferData(instance: *runtime.Instance, args: BufferDataArgs) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_bufferData(instance, args);
}

pub fn call_uniform4fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform4fv(instance, location, data, srcOffset, srcLength);
}

/// Arguments for bufferSubData (WebIDL overloading)
pub const BufferSubDataArgs = union(enum) {
    /// bufferSubData(target, dstByteOffset, srcData)
    GLenum_GLintptr_AllowSharedBufferSource: struct {
        target: typedefs.GLenum,
        dstByteOffset: typedefs.GLintptr,
        srcData: typedefs.AllowSharedBufferSource,
    },
    /// bufferSubData(target, dstByteOffset, srcData, srcOffset, length)
    GLenum_GLintptr_ArrayBufferView_unsigned_long_long_GLuint: struct {
        target: typedefs.GLenum,
        dstByteOffset: typedefs.GLintptr,
        srcData: typedefs.ArrayBufferView,
        srcOffset: runtime.JSValue,
        length: webidl.Opt(typedefs.GLuint),
    },
};

pub fn call_bufferSubData(instance: *runtime.Instance, args: BufferSubDataArgs) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_bufferSubData(instance, args);
}

/// Arguments for readPixels (WebIDL overloading)
pub const ReadPixelsArgs = union(enum) {
    /// readPixels(x, y, width, height, format, type, dstData)
    GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView: struct {
        x: typedefs.GLint,
        y: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        dstData: ?typedefs.ArrayBufferView,
    },
    /// readPixels(x, y, width, height, format, type, offset)
    GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
        x: typedefs.GLint,
        y: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        offset: typedefs.GLintptr,
    },
    /// readPixels(x, y, width, height, format, type, dstData, dstOffset)
    GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_unsigned_long_long: struct {
        x: typedefs.GLint,
        y: typedefs.GLint,
        width: typedefs.GLsizei,
        height: typedefs.GLsizei,
        format: typedefs.GLenum,
        @"type": typedefs.GLenum,
        dstData: typedefs.ArrayBufferView,
        dstOffset: runtime.JSValue,
    },
};

pub fn call_readPixels(instance: *runtime.Instance, args: ReadPixelsArgs) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_readPixels(instance, args);
}

pub fn call_uniform3iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform3iv(instance, location, data, srcOffset, srcLength);
}

pub fn call_uniform3fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform3fv(instance, location, data, srcOffset, srcLength);
}

pub fn call_uniform1iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform1iv(instance, location, data, srcOffset, srcLength);
}

pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: typedefs.GLboolean, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniformMatrix2fv(instance, location, transpose, data, srcOffset, srcLength);
}

pub fn call_uniform2iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Int32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform2iv(instance, location, data, srcOffset, srcLength);
}

pub fn call_uniform2fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform2fv(instance, location, data, srcOffset, srcLength);
}

pub fn call_uniform1fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: typedefs.Float32List, srcOffset: runtime.JSValue, srcLength: typedefs.GLuint) anyerror!void {
    return WebGL2RenderingContextOverloadsImpl.call_uniform1fv(instance, location, data, srcOffset, srcLength);
}

