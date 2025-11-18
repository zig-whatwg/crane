//! Generated from: webgl2.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGL2RenderingContextOverloadsImpl = @import("impls").WebGL2RenderingContextOverloads;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const Int32List = @import("typedefs").Int32List;
const GLboolean = @import("typedefs").GLboolean;
const GLint = @import("typedefs").GLint;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const Float32List = @import("typedefs").Float32List;
const TexImageSource = @import("typedefs").TexImageSource;
const GLuint = @import("typedefs").GLuint;
const GLenum = @import("typedefs").GLenum;
const GLsizeiptr = @import("typedefs").GLsizeiptr;
const GLintptr = @import("typedefs").GLintptr;
const GLsizei = @import("typedefs").GLsizei;
const WebGLUniformLocation = @import("interfaces").WebGLUniformLocation;

pub const WebGL2RenderingContextOverloads = struct {
    pub const Meta = struct {
        pub const name = "WebGL2RenderingContextOverloads";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebGL2RenderingContextOverloads, .{
        .deinit_fn = &deinit_wrapper,

        .call_bufferData = &call_bufferData,
        .call_bufferSubData = &call_bufferSubData,
        .call_compressedTexImage2D = &call_compressedTexImage2D,
        .call_compressedTexSubImage2D = &call_compressedTexSubImage2D,
        .call_readPixels = &call_readPixels,
        .call_texImage2D = &call_texImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_uniform1fv = &call_uniform1fv,
        .call_uniform1iv = &call_uniform1iv,
        .call_uniform2fv = &call_uniform2fv,
        .call_uniform2iv = &call_uniform2iv,
        .call_uniform3fv = &call_uniform3fv,
        .call_uniform3iv = &call_uniform3iv,
        .call_uniform4fv = &call_uniform4fv,
        .call_uniform4iv = &call_uniform4iv,
        .call_uniformMatrix2fv = &call_uniformMatrix2fv,
        .call_uniformMatrix3fv = &call_uniformMatrix3fv,
        .call_uniformMatrix4fv = &call_uniformMatrix4fv,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebGL2RenderingContextOverloadsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGL2RenderingContextOverloadsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for bufferData (WebIDL overloading)
    pub const BufferDataArgs = union(enum) {
        /// bufferData(target, size, usage)
        GLenum_GLsizeiptr_GLenum: struct {
            target: GLenum,
            size: GLsizeiptr,
            usage: GLenum,
        },
        /// bufferData(target, srcData, usage)
        GLenum_AllowSharedBufferSource?_GLenum: struct {
            target: GLenum,
            srcData: anyopaque,
            usage: GLenum,
        },
        /// bufferData(target, srcData, usage, srcOffset, length)
        GLenum_ArrayBufferView_GLenum_long long_GLuint: struct {
            target: GLenum,
            srcData: ArrayBufferView,
            usage: GLenum,
            srcOffset: u64,
            length: GLuint,
        },
    };

    pub fn call_bufferData(instance: *runtime.Instance, args: BufferDataArgs) anyerror!void {
        switch (args) {
            .GLenum_GLsizeiptr_GLenum => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLsizeiptr_GLenum(instance, a.target, a.size, a.usage),
            .GLenum_AllowSharedBufferSource?_GLenum => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_AllowSharedBufferSource?_GLenum(instance, a.target, a.srcData, a.usage),
            .GLenum_ArrayBufferView_GLenum_long long_GLuint => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_ArrayBufferView_GLenum_long long_GLuint(instance, a.target, a.srcData, a.usage, a.srcOffset, a.length),
        }
    }

    /// Arguments for compressedTexSubImage2D (WebIDL overloading)
    pub const CompressedTexSubImage2DArgs = union(enum) {
        /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, offset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            imageSize: GLsizei,
            offset: GLintptr,
        },
        /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            srcData: ArrayBufferView,
            srcOffset: u64,
            srcLengthOverride: GLuint,
        },
    };

    pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, args: CompressedTexSubImage2DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr(instance, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.imageSize, a.offset),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint(instance, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    /// Arguments for texSubImage2D (WebIDL overloading)
    pub const TexSubImage2DArgs = union(enum) {
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            type_: GLenum,
            pixels: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, format, type, source)
        GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            format: GLenum,
            type_: GLenum,
            source: TexImageSource,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pboOffset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            type_: GLenum,
            pboOffset: GLintptr,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, source)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            type_: GLenum,
            source: TexImageSource,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: GLenum,
            level: GLint,
            xoffset: GLint,
            yoffset: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            type_: GLenum,
            srcData: ArrayBufferView,
            srcOffset: u64,
        },
    };

    pub fn call_texSubImage2D(instance: *runtime.Instance, args: TexSubImage2DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(instance, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.xoffset, a.yoffset, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr(instance, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long(instance, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniformMatrix2fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    /// Arguments for readPixels (WebIDL overloading)
    pub const ReadPixelsArgs = union(enum) {
        /// readPixels(x, y, width, height, format, type, dstData)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?: struct {
            x: GLint,
            y: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            type_: GLenum,
            dstData: anyopaque,
        },
        /// readPixels(x, y, width, height, format, type, offset)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            x: GLint,
            y: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            type_: GLenum,
            offset: GLintptr,
        },
        /// readPixels(x, y, width, height, format, type, dstData, dstOffset)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long: struct {
            x: GLint,
            y: GLint,
            width: GLsizei,
            height: GLsizei,
            format: GLenum,
            type_: GLenum,
            dstData: ArrayBufferView,
            dstOffset: u64,
        },
    };

    pub fn call_readPixels(instance: *runtime.Instance, args: ReadPixelsArgs) anyerror!void {
        switch (args) {
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return try WebGL2RenderingContextOverloadsImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(instance, a.x, a.y, a.width, a.height, a.format, a.type_, a.dstData),
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return try WebGL2RenderingContextOverloadsImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr(instance, a.x, a.y, a.width, a.height, a.format, a.type_, a.offset),
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long => |a| return try WebGL2RenderingContextOverloadsImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long(instance, a.x, a.y, a.width, a.height, a.format, a.type_, a.dstData, a.dstOffset),
        }
    }

    pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform4fv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform2fv(instance, location, data, srcOffset, srcLength);
    }

    /// Arguments for bufferSubData (WebIDL overloading)
    pub const BufferSubDataArgs = union(enum) {
        /// bufferSubData(target, dstByteOffset, srcData)
        GLenum_GLintptr_AllowSharedBufferSource: struct {
            target: GLenum,
            dstByteOffset: GLintptr,
            srcData: AllowSharedBufferSource,
        },
        /// bufferSubData(target, dstByteOffset, srcData, srcOffset, length)
        GLenum_GLintptr_ArrayBufferView_long long_GLuint: struct {
            target: GLenum,
            dstByteOffset: GLintptr,
            srcData: ArrayBufferView,
            srcOffset: u64,
            length: GLuint,
        },
    };

    pub fn call_bufferSubData(instance: *runtime.Instance, args: BufferSubDataArgs) anyerror!void {
        switch (args) {
            .GLenum_GLintptr_AllowSharedBufferSource => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLintptr_AllowSharedBufferSource(instance, a.target, a.dstByteOffset, a.srcData),
            .GLenum_GLintptr_ArrayBufferView_long long_GLuint => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLintptr_ArrayBufferView_long long_GLuint(instance, a.target, a.dstByteOffset, a.srcData, a.srcOffset, a.length),
        }
    }

    pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, data: Int32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform4iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniformMatrix4fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    /// Arguments for texImage2D (WebIDL overloading)
    pub const TexImage2DArgs = union(enum) {
        /// texImage2D(target, level, internalformat, width, height, border, format, type, pixels)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            pixels: anyopaque,
        },
        /// texImage2D(target, level, internalformat, format, type, source)
        GLenum_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            format: GLenum,
            type_: GLenum,
            source: TexImageSource,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, pboOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            pboOffset: GLintptr,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, source)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            source: TexImageSource,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLint,
            width: GLsizei,
            height: GLsizei,
            border: GLint,
            format: GLenum,
            type_: GLenum,
            srcData: ArrayBufferView,
            srcOffset: u64,
        },
    };

    pub fn call_texImage2D(instance: *runtime.Instance, args: TexImage2DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView? => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?(instance, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.internalformat, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr(instance, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long(instance, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform1fv(instance, location, data, srcOffset, srcLength);
    }

    /// Arguments for compressedTexImage2D (WebIDL overloading)
    pub const CompressedTexImage2DArgs = union(enum) {
        /// compressedTexImage2D(target, level, internalformat, width, height, border, imageSize, offset)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLenum,
            width: GLsizei,
            height: GLsizei,
            border: GLint,
            imageSize: GLsizei,
            offset: GLintptr,
        },
        /// compressedTexImage2D(target, level, internalformat, width, height, border, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint: struct {
            target: GLenum,
            level: GLint,
            internalformat: GLenum,
            width: GLsizei,
            height: GLsizei,
            border: GLint,
            srcData: ArrayBufferView,
            srcOffset: u64,
            srcLengthOverride: GLuint,
        },
    };

    pub fn call_compressedTexImage2D(instance: *runtime.Instance, args: CompressedTexImage2DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr(instance, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.imageSize, a.offset),
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint => |a| return try WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint(instance, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, data: Int32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform1iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, data: Int32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform2iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniformMatrix3fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, data: Int32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform3iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, data: Float32List, srcOffset: u64, srcLength: GLuint) anyerror!void {
        
        return try WebGL2RenderingContextOverloadsImpl.call_uniform3fv(instance, location, data, srcOffset, srcLength);
    }

};
