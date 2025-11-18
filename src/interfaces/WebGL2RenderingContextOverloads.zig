//! Generated from: webgl2.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGL2RenderingContextOverloadsImpl = @import("../impls/WebGL2RenderingContextOverloads.zig");

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
        .call_bufferData = &call_bufferData,
        .call_bufferData = &call_bufferData,
        .call_bufferSubData = &call_bufferSubData,
        .call_bufferSubData = &call_bufferSubData,
        .call_compressedTexImage2D = &call_compressedTexImage2D,
        .call_compressedTexImage2D = &call_compressedTexImage2D,
        .call_compressedTexSubImage2D = &call_compressedTexSubImage2D,
        .call_compressedTexSubImage2D = &call_compressedTexSubImage2D,
        .call_readPixels = &call_readPixels,
        .call_readPixels = &call_readPixels,
        .call_readPixels = &call_readPixels,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
        .call_texSubImage2D = &call_texSubImage2D,
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
        
        // Initialize the state (Impl receives full hierarchy)
        WebGL2RenderingContextOverloadsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebGL2RenderingContextOverloadsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for bufferData (WebIDL overloading)
    pub const BufferDataArgs = union(enum) {
        /// bufferData(target, size, usage)
        GLenum_GLsizeiptr_GLenum: struct {
            target: anyopaque,
            size: anyopaque,
            usage: anyopaque,
        },
        /// bufferData(target, srcData, usage)
        GLenum_AllowSharedBufferSource?_GLenum: struct {
            target: anyopaque,
            srcData: anyopaque,
            usage: anyopaque,
        },
        /// bufferData(target, srcData, usage, srcOffset, length)
        GLenum_ArrayBufferView_GLenum_long long_GLuint: struct {
            target: anyopaque,
            srcData: anyopaque,
            usage: anyopaque,
            srcOffset: u64,
            length: anyopaque,
        },
    };

    pub fn call_bufferData(instance: *runtime.Instance, args: BufferDataArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLsizeiptr_GLenum => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLsizeiptr_GLenum(state, a.target, a.size, a.usage),
            .GLenum_AllowSharedBufferSource?_GLenum => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_AllowSharedBufferSource?_GLenum(state, a.target, a.srcData, a.usage),
            .GLenum_ArrayBufferView_GLenum_long long_GLuint => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_ArrayBufferView_GLenum_long long_GLuint(state, a.target, a.srcData, a.usage, a.srcOffset, a.length),
        }
    }

    /// Arguments for compressedTexSubImage2D (WebIDL overloading)
    pub const CompressedTexSubImage2DArgs = union(enum) {
        /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, offset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            imageSize: anyopaque,
            offset: anyopaque,
        },
        /// compressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            srcLengthOverride: anyopaque,
        },
    };

    pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, args: CompressedTexSubImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLsizei_GLintptr(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.imageSize, a.offset),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_ArrayBufferView_long long_GLuint(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    /// Arguments for texSubImage2D (WebIDL overloading)
    pub const TexSubImage2DArgs = union(enum) {
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pixels: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, format, type, source)
        GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pboOffset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pboOffset: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, source)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: anyopaque,
            level: anyopaque,
            xoffset: anyopaque,
            yoffset: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
        },
    };

    pub fn call_texSubImage2D(instance: *runtime.Instance, args: TexSubImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.xoffset, a.yoffset, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniformMatrix2fv(state, location, transpose, data, srcOffset, srcLength);
    }

    /// Arguments for readPixels (WebIDL overloading)
    pub const ReadPixelsArgs = union(enum) {
        /// readPixels(x, y, width, height, format, type, dstData)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?: struct {
            x: anyopaque,
            y: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            dstData: anyopaque,
        },
        /// readPixels(x, y, width, height, format, type, offset)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr: struct {
            x: anyopaque,
            y: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            offset: anyopaque,
        },
        /// readPixels(x, y, width, height, format, type, dstData, dstOffset)
        GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long: struct {
            x: anyopaque,
            y: anyopaque,
            width: anyopaque,
            height: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            dstData: anyopaque,
            dstOffset: u64,
        },
    };

    pub fn call_readPixels(instance: *runtime.Instance, args: ReadPixelsArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return WebGL2RenderingContextOverloadsImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(state, a.x, a.y, a.width, a.height, a.format, a.type_, a.dstData),
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextOverloadsImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_GLintptr(state, a.x, a.y, a.width, a.height, a.format, a.type_, a.offset),
            .GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long => |a| return WebGL2RenderingContextOverloadsImpl.GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView_long long(state, a.x, a.y, a.width, a.height, a.format, a.type_, a.dstData, a.dstOffset),
        }
    }

    pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform4fv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform2fv(state, location, data, srcOffset, srcLength);
    }

    /// Arguments for bufferSubData (WebIDL overloading)
    pub const BufferSubDataArgs = union(enum) {
        /// bufferSubData(target, dstByteOffset, srcData)
        GLenum_GLintptr_AllowSharedBufferSource: struct {
            target: anyopaque,
            dstByteOffset: anyopaque,
            srcData: anyopaque,
        },
        /// bufferSubData(target, dstByteOffset, srcData, srcOffset, length)
        GLenum_GLintptr_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            dstByteOffset: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            length: anyopaque,
        },
    };

    pub fn call_bufferSubData(instance: *runtime.Instance, args: BufferSubDataArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLintptr_AllowSharedBufferSource => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLintptr_AllowSharedBufferSource(state, a.target, a.dstByteOffset, a.srcData),
            .GLenum_GLintptr_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLintptr_ArrayBufferView_long long_GLuint(state, a.target, a.dstByteOffset, a.srcData, a.srcOffset, a.length),
        }
    }

    pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform4iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniformMatrix4fv(state, location, transpose, data, srcOffset, srcLength);
    }

    /// Arguments for texImage2D (WebIDL overloading)
    pub const TexImage2DArgs = union(enum) {
        /// texImage2D(target, level, internalformat, width, height, border, format, type, pixels)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pixels: anyopaque,
        },
        /// texImage2D(target, level, internalformat, format, type, source)
        GLenum_GLint_GLint_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, pboOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            pboOffset: anyopaque,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, source)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            source: anyopaque,
        },
        /// texImage2D(target, level, internalformat, width, height, border, format, type, srcData, srcOffset)
        GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            format: anyopaque,
            type_: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
        },
    };

    pub fn call_texImage2D(instance: *runtime.Instance, args: TexImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView? => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.internalformat, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_GLintptr(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pboOffset),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.source),
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView_long long(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.srcData, a.srcOffset),
        }
    }

    pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform1fv(state, location, data, srcOffset, srcLength);
    }

    /// Arguments for compressedTexImage2D (WebIDL overloading)
    pub const CompressedTexImage2DArgs = union(enum) {
        /// compressedTexImage2D(target, level, internalformat, width, height, border, imageSize, offset)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            imageSize: anyopaque,
            offset: anyopaque,
        },
        /// compressedTexImage2D(target, level, internalformat, width, height, border, srcData, srcOffset, srcLengthOverride)
        GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint: struct {
            target: anyopaque,
            level: anyopaque,
            internalformat: anyopaque,
            width: anyopaque,
            height: anyopaque,
            border: anyopaque,
            srcData: anyopaque,
            srcOffset: u64,
            srcLengthOverride: anyopaque,
        },
    };

    pub fn call_compressedTexImage2D(instance: *runtime.Instance, args: CompressedTexImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_GLsizei_GLintptr(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.imageSize, a.offset),
            .GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint => |a| return WebGL2RenderingContextOverloadsImpl.GLenum_GLint_GLenum_GLsizei_GLsizei_GLint_ArrayBufferView_long long_GLuint(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.srcData, a.srcOffset, a.srcLengthOverride),
        }
    }

    pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform1iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform2iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniformMatrix3fv(state, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform3iv(state, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, data: anyopaque, srcOffset: u64, srcLength: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGL2RenderingContextOverloadsImpl.call_uniform3fv(state, location, data, srcOffset, srcLength);
    }

};
