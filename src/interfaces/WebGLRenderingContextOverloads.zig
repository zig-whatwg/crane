//! Generated from: webgl1.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGLRenderingContextOverloadsImpl = @import("../impls/WebGLRenderingContextOverloads.zig");

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
        .call_bufferData = &call_bufferData,
        .call_bufferSubData = &call_bufferSubData,
        .call_compressedTexImage2D = &call_compressedTexImage2D,
        .call_compressedTexSubImage2D = &call_compressedTexSubImage2D,
        .call_readPixels = &call_readPixels,
        .call_texImage2D = &call_texImage2D,
        .call_texImage2D = &call_texImage2D,
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
        WebGLRenderingContextOverloadsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebGLRenderingContextOverloadsImpl.deinit(state);
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
        /// bufferData(target, data, usage)
        GLenum_AllowSharedBufferSource?_GLenum: struct {
            target: anyopaque,
            data: anyopaque,
            usage: anyopaque,
        },
    };

    pub fn call_bufferData(instance: *runtime.Instance, args: BufferDataArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLsizeiptr_GLenum => |a| return WebGLRenderingContextOverloadsImpl.GLenum_GLsizeiptr_GLenum(state, a.target, a.size, a.usage),
            .GLenum_AllowSharedBufferSource?_GLenum => |a| return WebGLRenderingContextOverloadsImpl.GLenum_AllowSharedBufferSource?_GLenum(state, a.target, a.data, a.usage),
        }
    }

    pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, xoffset: anyopaque, yoffset: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_compressedTexSubImage2D(state, target, level, xoffset, yoffset, width, height, format, data);
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
    };

    pub fn call_texSubImage2D(instance: *runtime.Instance, args: TexSubImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView? => |a| return WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLsizei_GLsizei_GLenum_GLenum_ArrayBufferView?(state, a.target, a.level, a.xoffset, a.yoffset, a.width, a.height, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.xoffset, a.yoffset, a.format, a.type_, a.source),
        }
    }

    pub fn call_readPixels(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque, format: anyopaque, type_: anyopaque, pixels: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_readPixels(state, x, y, width, height, format, type_, pixels);
    }

    pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniformMatrix2fv(state, location, transpose, value);
    }

    pub fn call_uniform4fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform4fv(state, location, v);
    }

    pub fn call_uniform2fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform2fv(state, location, v);
    }

    pub fn call_bufferSubData(instance: *runtime.Instance, target: anyopaque, offset: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_bufferSubData(state, target, offset, data);
    }

    pub fn call_uniform4iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform4iv(state, location, v);
    }

    pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniformMatrix4fv(state, location, transpose, value);
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
    };

    pub fn call_texImage2D(instance: *runtime.Instance, args: TexImage2DArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView? => |a| return WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLsizei_GLsizei_GLint_GLenum_GLenum_ArrayBufferView?(state, a.target, a.level, a.internalformat, a.width, a.height, a.border, a.format, a.type_, a.pixels),
            .GLenum_GLint_GLint_GLenum_GLenum_TexImageSource => |a| return WebGLRenderingContextOverloadsImpl.GLenum_GLint_GLint_GLenum_GLenum_TexImageSource(state, a.target, a.level, a.internalformat, a.format, a.type_, a.source),
        }
    }

    pub fn call_uniform1fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform1fv(state, location, v);
    }

    pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: anyopaque, level: anyopaque, internalformat: anyopaque, width: anyopaque, height: anyopaque, border: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_compressedTexImage2D(state, target, level, internalformat, width, height, border, data);
    }

    pub fn call_uniform1iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform1iv(state, location, v);
    }

    pub fn call_uniform2iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform2iv(state, location, v);
    }

    pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: anyopaque, transpose: anyopaque, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniformMatrix3fv(state, location, transpose, value);
    }

    pub fn call_uniform3iv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform3iv(state, location, v);
    }

    pub fn call_uniform3fv(instance: *runtime.Instance, location: anyopaque, v: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebGLRenderingContextOverloadsImpl.call_uniform3fv(state, location, v);
    }

};
