//! Generated from: webgl1.idl
//! Generated at: 2025-11-24T18:47:07Z
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
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "bufferData", "call_bufferData", 3 },
            .{ "bufferData", "call_bufferData", 3 },
            .{ "bufferSubData", "call_bufferSubData", 3 },
            .{ "compressedTexImage2D", "call_compressedTexImage2D", 7 },
            .{ "compressedTexSubImage2D", "call_compressedTexSubImage2D", 8 },
            .{ "readPixels", "call_readPixels", 7 },
            .{ "texImage2D", "call_texImage2D", 9 },
            .{ "texImage2D", "call_texImage2D", 6 },
            .{ "texSubImage2D", "call_texSubImage2D", 9 },
            .{ "texSubImage2D", "call_texSubImage2D", 7 },
            .{ "uniform1fv", "call_uniform1fv", 2 },
            .{ "uniform2fv", "call_uniform2fv", 2 },
            .{ "uniform3fv", "call_uniform3fv", 2 },
            .{ "uniform4fv", "call_uniform4fv", 2 },
            .{ "uniform1iv", "call_uniform1iv", 2 },
            .{ "uniform2iv", "call_uniform2iv", 2 },
            .{ "uniform3iv", "call_uniform3iv", 2 },
            .{ "uniform4iv", "call_uniform4iv", 2 },
            .{ "uniformMatrix2fv", "call_uniformMatrix2fv", 3 },
            .{ "uniformMatrix3fv", "call_uniformMatrix3fv", 3 },
            .{ "uniformMatrix4fv", "call_uniformMatrix4fv", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "bufferData",
            "bufferData",
            "bufferSubData",
            "compressedTexImage2D",
            "compressedTexSubImage2D",
            "readPixels",
            "texImage2D",
            "texImage2D",
            "texSubImage2D",
            "texSubImage2D",
            "uniform1fv",
            "uniform2fv",
            "uniform3fv",
            "uniform4fv",
            "uniform1iv",
            "uniform2iv",
            "uniform3iv",
            "uniform4iv",
            "uniformMatrix2fv",
            "uniformMatrix3fv",
            "uniformMatrix4fv",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebGLRenderingContextOverloadsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGLRenderingContextOverloadsImpl.deinit(instance);
    }

    pub fn call_bufferData(instance: *runtime.Instance, target: GLenum, size: GLsizeiptr, usage: GLenum) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_bufferData(instance, target, size, usage);
    }

    pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, data: ArrayBufferView) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_compressedTexSubImage2D(instance, target, level, xoffset, yoffset, width, height, format, data);
    }

    pub fn call_texSubImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, pixels: ArrayBufferView) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_texSubImage2D(instance, target, level, xoffset, yoffset, width, height, format, @"type", pixels);
    }

    pub fn call_readPixels(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, pixels: ArrayBufferView) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_readPixels(instance, x, y, width, height, format, @"type", pixels);
    }

    pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: GLboolean, value: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniformMatrix2fv(instance, location, transpose, value);
    }

    pub fn call_uniform4fv(instance: *runtime.Instance, location: *runtime.Instance, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform4fv(instance, location, v);
    }

    pub fn call_uniform2fv(instance: *runtime.Instance, location: *runtime.Instance, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform2fv(instance, location, v);
    }

    pub fn call_bufferSubData(instance: *runtime.Instance, target: GLenum, offset: GLintptr, data: AllowSharedBufferSource) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_bufferSubData(instance, target, offset, data);
    }

    pub fn call_uniform4iv(instance: *runtime.Instance, location: *runtime.Instance, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform4iv(instance, location, v);
    }

    pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: GLboolean, value: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniformMatrix4fv(instance, location, transpose, value);
    }

    pub fn call_texImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, @"type": GLenum, pixels: ArrayBufferView) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_texImage2D(instance, target, level, internalformat, width, height, border, format, @"type", pixels);
    }

    pub fn call_uniform1fv(instance: *runtime.Instance, location: *runtime.Instance, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform1fv(instance, location, v);
    }

    pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, border: GLint, data: ArrayBufferView) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_compressedTexImage2D(instance, target, level, internalformat, width, height, border, data);
    }

    pub fn call_uniform1iv(instance: *runtime.Instance, location: *runtime.Instance, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform1iv(instance, location, v);
    }

    pub fn call_uniform2iv(instance: *runtime.Instance, location: *runtime.Instance, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform2iv(instance, location, v);
    }

    pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: *runtime.Instance, transpose: GLboolean, value: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniformMatrix3fv(instance, location, transpose, value);
    }

    pub fn call_uniform3iv(instance: *runtime.Instance, location: *runtime.Instance, v: Int32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform3iv(instance, location, v);
    }

    pub fn call_uniform3fv(instance: *runtime.Instance, location: *runtime.Instance, v: Float32List) anyerror!void {
        
        return try WebGLRenderingContextOverloadsImpl.call_uniform3fv(instance, location, v);
    }

};
