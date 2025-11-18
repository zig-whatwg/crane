//! Generated from: webgl1.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGLRenderingContextOverloadsImpl = @import("impls").WebGLRenderingContextOverloads;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const Int32List = @import("typedefs").Int32List;
const GLboolean = @import("typedefs").GLboolean;
const GLint = @import("typedefs").GLint;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const Float32List = @import("typedefs").Float32List;
const TexImageSource = @import("typedefs").TexImageSource;
const GLenum = @import("typedefs").GLenum;
const GLsizeiptr = @import("typedefs").GLsizeiptr;
const GLintptr = @import("typedefs").GLintptr;
const GLsizei = @import("typedefs").GLsizei;
const WebGLUniformLocation = @import("interfaces").WebGLUniformLocation;

pub const WebGLRenderingContextOverloads = struct {
    pub const Meta = struct {
        pub const name = "WebGLRenderingContextOverloads";
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

    pub const vtable = runtime.buildVTable(WebGLRenderingContextOverloads, .{
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
        WebGLRenderingContextOverloadsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGLRenderingContextOverloadsImpl.deinit(instance);
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
        /// bufferData(target, data, usage)
        GLenum_AllowSharedBufferSource?_GLenum: struct {
            target: GLenum,
            data: anyopaque,
            usage: GLenum,
        },
    };

    pub fn call_bufferData(instance: *runtime.Instance, args: BufferDataArgs) anyerror!void {
        switch (args) {
            .GLenum_GLsizeiptr_GLenum => |a| return try WebGLRenderingContextOverloadsImpl.GLenum_GLsizeiptr_GLenum(instance, a.target, a.size, a.usage),
            .GLenum_AllowSharedBufferSource?_GLenum => |a| return try WebGLRenderingContextOverloadsImpl.GLenum_AllowSharedBufferSource?_GLenum(instance, a.target, a.data, a.usage),
        }
    }

    pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, data: ArrayBufferView) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_compressedTexSubImage2D(instance, target, level, xoffset, yoffset, width, height, format, data);
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
    };

    pub fn call_texSubImage2D(instance: *runtime.Instance, args: TexSubImage2DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return try WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(instance, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return try WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.xoffset, a.yoffset, a.format, a.type_, a.source),
        }
    }

    pub fn call_readPixels(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, type_: GLenum, pixels: anyopaque) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_readPixels(instance, x, y, width, height, format, type_, pixels);
    }

    pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, value: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniformMatrix2fv(instance, location, transpose, value);
    }

    pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform4fv(instance, location, v);
    }

    pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform2fv(instance, location, v);
    }

    pub fn call_bufferSubData(instance: *runtime.Instance, target: GLenum, offset: GLintptr, data: AllowSharedBufferSource) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_bufferSubData(instance, target, offset, data);
    }

    pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform4iv(instance, location, v);
    }

    pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, value: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniformMatrix4fv(instance, location, transpose, value);
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
    };

    pub fn call_texImage2D(instance: *runtime.Instance, args: TexImage2DArgs) anyerror!void {
        switch (args) {
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView? => |a| return try WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?(instance, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return try WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLenum_GLenum_TexImageSource(instance, a.target, a.level, a.internalformat, a.format, a.type_, a.source),
        }
    }

    pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform1fv(instance, location, v);
    }

    pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, border: GLint, data: ArrayBufferView) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_compressedTexImage2D(instance, target, level, internalformat, width, height, border, data);
    }

    pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform1iv(instance, location, v);
    }

    pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform2iv(instance, location, v);
    }

    pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: GLboolean, value: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniformMatrix3fv(instance, location, transpose, value);
    }

    pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform3iv(instance, location, v);
    }

    pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform3fv(instance, location, v);
    }

};
