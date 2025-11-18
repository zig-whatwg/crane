//! Generated from: OES_draw_buffers_indexed.idl
//! Generated at: 2025-11-18T18:28:11Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(OES_draw_buffers_indexed, .{
        .deinit_fn = &deinit_wrapper,

        .call_blendEquationSeparateiOES = &call_blendEquationSeparateiOES,
        .call_blendEquationiOES = &call_blendEquationiOES,
        .call_blendFuncSeparateiOES = &call_blendFuncSeparateiOES,
        .call_blendFunciOES = &call_blendFunciOES,
        .call_colorMaskiOES = &call_colorMaskiOES,
        .call_disableiOES = &call_disableiOES,
        .call_enableiOES = &call_enableiOES,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        OES_draw_buffers_indexedImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OES_draw_buffers_indexedImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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
