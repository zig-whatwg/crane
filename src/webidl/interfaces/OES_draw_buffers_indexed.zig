//! Generated from: OES_draw_buffers_indexed.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OES_draw_buffers_indexedImpl = @import("impls").OES_draw_buffers_indexed;
const GLenum = @import("typedefs").GLenum;
const GLboolean = @import("typedefs").GLboolean;
const GLuint = @import("typedefs").GLuint;

pub const OES_draw_buffers_indexed = struct {
    pub const Meta = struct {
        pub const name = "OES_draw_buffers_indexed";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "enableiOES", "call_enableiOES", 2 },
            .{ "disableiOES", "call_disableiOES", 2 },
            .{ "blendEquationiOES", "call_blendEquationiOES", 2 },
            .{ "blendEquationSeparateiOES", "call_blendEquationSeparateiOES", 3 },
            .{ "blendFunciOES", "call_blendFunciOES", 3 },
            .{ "blendFuncSeparateiOES", "call_blendFuncSeparateiOES", 5 },
            .{ "colorMaskiOES", "call_colorMaskiOES", 5 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "enableiOES",
            "disableiOES",
            "blendEquationiOES",
            "blendEquationSeparateiOES",
            "blendFunciOES",
            "blendFuncSeparateiOES",
            "colorMaskiOES",
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
        struct {
            _internal: ?*OES_draw_buffers_indexedImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_blendEquationSeparateiOES = &call_blendEquationSeparateiOES,
        .call_blendEquationiOES = &call_blendEquationiOES,
        .call_blendFuncSeparateiOES = &call_blendFuncSeparateiOES,
        .call_blendFunciOES = &call_blendFunciOES,
        .call_colorMaskiOES = &call_colorMaskiOES,
        .call_disableiOES = &call_disableiOES,
        .call_enableiOES = &call_enableiOES,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OES_draw_buffers_indexedImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OES_draw_buffers_indexedImpl.deinit(instance);
    }

    pub fn call_enableiOES(instance: *runtime.Instance, target: GLenum, index: GLuint) anyerror!void {
        
        return try OES_draw_buffers_indexedImpl.call_enableiOES(instance, target, index);
    }

    pub fn call_blendEquationiOES(instance: *runtime.Instance, buf: GLuint, mode: GLenum) anyerror!void {
        
        return try OES_draw_buffers_indexedImpl.call_blendEquationiOES(instance, buf, mode);
    }

    pub fn call_blendEquationSeparateiOES(instance: *runtime.Instance, buf: GLuint, modeRGB: GLenum, modeAlpha: GLenum) anyerror!void {
        
        return try OES_draw_buffers_indexedImpl.call_blendEquationSeparateiOES(instance, buf, modeRGB, modeAlpha);
    }

    pub fn call_blendFunciOES(instance: *runtime.Instance, buf: GLuint, src: GLenum, dst: GLenum) anyerror!void {
        
        return try OES_draw_buffers_indexedImpl.call_blendFunciOES(instance, buf, src, dst);
    }

    pub fn call_blendFuncSeparateiOES(instance: *runtime.Instance, buf: GLuint, srcRGB: GLenum, dstRGB: GLenum, srcAlpha: GLenum, dstAlpha: GLenum) anyerror!void {
        
        return try OES_draw_buffers_indexedImpl.call_blendFuncSeparateiOES(instance, buf, srcRGB, dstRGB, srcAlpha, dstAlpha);
    }

    pub fn call_colorMaskiOES(instance: *runtime.Instance, buf: GLuint, r: GLboolean, g: GLboolean, b: GLboolean, a: GLboolean) anyerror!void {
        
        return try OES_draw_buffers_indexedImpl.call_colorMaskiOES(instance, buf, r, g, b, a);
    }

    pub fn call_disableiOES(instance: *runtime.Instance, target: GLenum, index: GLuint) anyerror!void {
        
        return try OES_draw_buffers_indexedImpl.call_disableiOES(instance, target, index);
    }

};
