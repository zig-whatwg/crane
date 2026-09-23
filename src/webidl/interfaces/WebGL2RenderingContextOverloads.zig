//! Generated from: webgl2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebGL2RenderingContextOverloadsImpl = @import("impls").WebGL2RenderingContextOverloads;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
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
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "bufferData", "call_bufferData", 3 },
            .{ "bufferSubData", "call_bufferSubData", 3 },
            .{ "texImage2D", "call_texImage2D", 6 },
            .{ "texSubImage2D", "call_texSubImage2D", 7 },
            .{ "compressedTexImage2D", "call_compressedTexImage2D", 7 },
            .{ "compressedTexSubImage2D", "call_compressedTexSubImage2D", 8 },
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
            .{ "readPixels", "call_readPixels", 7 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "bufferData",
            "bufferSubData",
            "texImage2D",
            "texSubImage2D",
            "compressedTexImage2D",
            "compressedTexSubImage2D",
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
            "readPixels",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*WebGL2RenderingContextOverloadsImpl.InternalState = null,
        },
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebGL2RenderingContextOverloadsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return WebGL2RenderingContextOverloadsImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGL2RenderingContextOverloadsImpl.deinit(instance);
    }

    pub fn call_texSubImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, pixels: ?ArrayBufferView) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_texSubImage2D(instance, target, level, xoffset, yoffset, width, height, format, @"type", pixels);
    }

    pub fn call_uniformMatrix4fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniformMatrix4fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_compressedTexImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, border: GLint, imageSize: GLsizei, offset: GLintptr) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_compressedTexImage2D(instance, target, level, internalformat, width, height, border, imageSize, offset);
    }

    pub fn call_uniform4iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform4iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_texImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, @"type": GLenum, pixels: ?ArrayBufferView) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_texImage2D(instance, target, level, internalformat, width, height, border, format, @"type", pixels);
    }

    pub fn call_uniformMatrix3fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniformMatrix3fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_compressedTexSubImage2D(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, imageSize: GLsizei, offset: GLintptr) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_compressedTexSubImage2D(instance, target, level, xoffset, yoffset, width, height, format, imageSize, offset);
    }

    pub fn call_bufferData(instance: *runtime.Instance, target: GLenum, size: GLsizeiptr, usage: GLenum) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_bufferData(instance, target, size, usage);
    }

    pub fn call_uniform4fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform4fv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_bufferSubData(instance: *runtime.Instance, target: GLenum, dstByteOffset: GLintptr, srcData: AllowSharedBufferSource) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_bufferSubData(instance, target, dstByteOffset, srcData);
    }

    pub fn call_readPixels(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, dstData: ?ArrayBufferView) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_readPixels(instance, x, y, width, height, format, @"type", dstData);
    }

    pub fn call_uniform3iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform3iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform3fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform3fv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform1iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform1iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniformMatrix2fv(instance: *runtime.Instance, location: ?*runtime.Instance, transpose: GLboolean, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniformMatrix2fv(instance, location, transpose, data, srcOffset, srcLength);
    }

    pub fn call_uniform2iv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Int32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform2iv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform2fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform2fv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_uniform1fv(instance: *runtime.Instance, location: ?*runtime.Instance, data: Float32List, srcOffset: webidl.Opt(u64), srcLength: webidl.Opt(GLuint)) anyerror!void {
        return try WebGL2RenderingContextOverloadsImpl.call_uniform1fv(instance, location, data, srcOffset, srcLength);
    }

    pub fn call_texSubImage2D__1(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, format: GLenum, @"type": GLenum, source: TexImageSource) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__1")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texSubImage2D__1(instance, target, level, xoffset, yoffset, format, @"type", source);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_texSubImage2D__2(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, pboOffset: GLintptr) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__2")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texSubImage2D__2(instance, target, level, xoffset, yoffset, width, height, format, @"type", pboOffset);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_texSubImage2D__3(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, source: TexImageSource) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__3")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texSubImage2D__3(instance, target, level, xoffset, yoffset, width, height, format, @"type", source);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_texSubImage2D__4(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, srcData: ArrayBufferView, srcOffset: u64) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__4")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texSubImage2D__4(instance, target, level, xoffset, yoffset, width, height, format, @"type", srcData, srcOffset);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_compressedTexImage2D__1(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, border: GLint, srcData: ArrayBufferView, srcOffset: webidl.Opt(u64), srcLengthOverride: webidl.Opt(GLuint)) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_compressedTexImage2D__1")) {
            return try WebGL2RenderingContextOverloadsImpl.call_compressedTexImage2D__1(instance, target, level, internalformat, width, height, border, srcData, srcOffset, srcLengthOverride);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_texImage2D__1(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, format: GLenum, @"type": GLenum, source: TexImageSource) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__1")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texImage2D__1(instance, target, level, internalformat, format, @"type", source);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_texImage2D__2(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, @"type": GLenum, pboOffset: GLintptr) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__2")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texImage2D__2(instance, target, level, internalformat, width, height, border, format, @"type", pboOffset);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_texImage2D__3(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, @"type": GLenum, source: TexImageSource) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__3")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texImage2D__3(instance, target, level, internalformat, width, height, border, format, @"type", source);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_texImage2D__4(instance: *runtime.Instance, target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, @"type": GLenum, srcData: ArrayBufferView, srcOffset: u64) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__4")) {
            return try WebGL2RenderingContextOverloadsImpl.call_texImage2D__4(instance, target, level, internalformat, width, height, border, format, @"type", srcData, srcOffset);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_compressedTexSubImage2D__1(instance: *runtime.Instance, target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, srcData: ArrayBufferView, srcOffset: webidl.Opt(u64), srcLengthOverride: webidl.Opt(GLuint)) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_compressedTexSubImage2D__1")) {
            return try WebGL2RenderingContextOverloadsImpl.call_compressedTexSubImage2D__1(instance, target, level, xoffset, yoffset, width, height, format, srcData, srcOffset, srcLengthOverride);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_bufferData__1(instance: *runtime.Instance, target: GLenum, srcData: ?AllowSharedBufferSource, usage: GLenum) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_bufferData__1")) {
            return try WebGL2RenderingContextOverloadsImpl.call_bufferData__1(instance, target, srcData, usage);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_bufferData__2(instance: *runtime.Instance, target: GLenum, srcData: ArrayBufferView, usage: GLenum, srcOffset: u64, length: webidl.Opt(GLuint)) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_bufferData__2")) {
            return try WebGL2RenderingContextOverloadsImpl.call_bufferData__2(instance, target, srcData, usage, srcOffset, length);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_bufferSubData__1(instance: *runtime.Instance, target: GLenum, dstByteOffset: GLintptr, srcData: ArrayBufferView, srcOffset: u64, length: webidl.Opt(GLuint)) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_bufferSubData__1")) {
            return try WebGL2RenderingContextOverloadsImpl.call_bufferSubData__1(instance, target, dstByteOffset, srcData, srcOffset, length);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_readPixels__1(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, offset: GLintptr) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_readPixels__1")) {
            return try WebGL2RenderingContextOverloadsImpl.call_readPixels__1(instance, x, y, width, height, format, @"type", offset);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_readPixels__2(instance: *runtime.Instance, x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, dstData: ArrayBufferView, dstOffset: u64) anyerror!void {
        if (comptime @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_readPixels__2")) {
            return try WebGL2RenderingContextOverloadsImpl.call_readPixels__2(instance, x, y, width, height, format, @"type", dstData, dstOffset);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "texSubImage2D", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_texSubImage2D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view }, .nullable = true } } },
            .{ .function = "call_texSubImage2D__1", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_texSubImage2D__2", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_texSubImage2D__3", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__3"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_texSubImage2D__4", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texSubImage2D__4"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "compressedTexImage2D", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_compressedTexImage2D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_compressedTexImage2D__1", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_compressedTexImage2D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric}, .optionality = .optional }, .{ .kinds = &.{.other}, .optionality = .optional } } },
        } },
        .{ "texImage2D", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_texImage2D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view }, .nullable = true } } },
            .{ .function = "call_texImage2D__1", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_texImage2D__2", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_texImage2D__3", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__3"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_texImage2D__4", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_texImage2D__4"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "compressedTexSubImage2D", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_compressedTexSubImage2D", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_compressedTexSubImage2D__1", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_compressedTexSubImage2D__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric}, .optionality = .optional }, .{ .kinds = &.{.other}, .optionality = .optional } } },
        } },
        .{ "bufferData", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_bufferData", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_bufferData__1", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_bufferData__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{ .array_buffer, .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view }, .nullable = true }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_bufferData__2", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_bufferData__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.other}, .optionality = .optional } } },
        } },
        .{ "bufferSubData", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_bufferSubData", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .array_buffer, .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } } } },
            .{ .function = "call_bufferSubData__1", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_bufferSubData__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.other}, .optionality = .optional } } },
        } },
        .{ "readPixels", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_readPixels", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view }, .nullable = true } } },
            .{ .function = "call_readPixels__1", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_readPixels__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
            .{ .function = "call_readPixels__2", .implemented = @hasDecl(WebGL2RenderingContextOverloadsImpl, "call_readPixels__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.numeric} } } },
        } },
    };
};
