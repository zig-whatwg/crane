//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRWebGLSubImageImpl = @import("impls").XRWebGLSubImage;
const mixins = @import("mixins");
const XRSubImage = @import("interfaces").XRSubImage;
const XRViewport = @import("interfaces").XRViewport;
const WebGLTexture = @import("interfaces").WebGLTexture;

pub const XRWebGLSubImage = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLSubImage";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRSubImage;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "colorTexture", "get_colorTexture", null },
            .{ "depthStencilTexture", "get_depthStencilTexture", null },
            .{ "motionVectorTexture", "get_motionVectorTexture", null },
            .{ "imageIndex", "get_imageIndex", null },
            .{ "colorTextureWidth", "get_colorTextureWidth", null },
            .{ "colorTextureHeight", "get_colorTextureHeight", null },
            .{ "depthStencilTextureWidth", "get_depthStencilTextureWidth", null },
            .{ "depthStencilTextureHeight", "get_depthStencilTextureHeight", null },
            .{ "motionVectorTextureWidth", "get_motionVectorTextureWidth", null },
            .{ "motionVectorTextureHeight", "get_motionVectorTextureHeight", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "colorTexture", "get_colorTexture", null },
            .{ "depthStencilTexture", "get_depthStencilTexture", null },
            .{ "motionVectorTexture", "get_motionVectorTexture", null },
            .{ "imageIndex", "get_imageIndex", null },
            .{ "colorTextureWidth", "get_colorTextureWidth", null },
            .{ "colorTextureHeight", "get_colorTextureHeight", null },
            .{ "depthStencilTextureWidth", "get_depthStencilTextureWidth", null },
            .{ "depthStencilTextureHeight", "get_depthStencilTextureHeight", null },
            .{ "motionVectorTextureWidth", "get_motionVectorTextureWidth", null },
            .{ "motionVectorTextureHeight", "get_motionVectorTextureHeight", null },
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
            colorTexture: *runtime.Instance = undefined,
            depthStencilTexture: ?*runtime.Instance = null,
            motionVectorTexture: ?*runtime.Instance = null,
            imageIndex: ?u32 = null,
            colorTextureWidth: u32 = undefined,
            colorTextureHeight: u32 = undefined,
            depthStencilTextureWidth: ?u32 = null,
            depthStencilTextureHeight: ?u32 = null,
            motionVectorTextureWidth: ?u32 = null,
            motionVectorTextureHeight: ?u32 = null,
            cached_colorTexture: ?*runtime.Instance = null,
            cached_depthStencilTexture: ?*runtime.Instance = null,
            cached_motionVectorTexture: ?*runtime.Instance = null,
            _internal: ?*XRWebGLSubImageImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_colorTexture = &get_colorTexture,
        .get_colorTextureHeight = &get_colorTextureHeight,
        .get_colorTextureWidth = &get_colorTextureWidth,
        .get_depthStencilTexture = &get_depthStencilTexture,
        .get_depthStencilTextureHeight = &get_depthStencilTextureHeight,
        .get_depthStencilTextureWidth = &get_depthStencilTextureWidth,
        .get_imageIndex = &get_imageIndex,
        .get_motionVectorTexture = &get_motionVectorTexture,
        .get_motionVectorTextureHeight = &get_motionVectorTextureHeight,
        .get_motionVectorTextureWidth = &get_motionVectorTextureWidth,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRWebGLSubImageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRWebGLSubImageImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_colorTexture(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_colorTexture) |cached| {
            return cached;
        }
        const value = try XRWebGLSubImageImpl.get_colorTexture(instance);
        state.own.cached_colorTexture = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_depthStencilTexture(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_depthStencilTexture) |cached| {
            return cached;
        }
        const value = try XRWebGLSubImageImpl.get_depthStencilTexture(instance);
        state.own.cached_depthStencilTexture = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_motionVectorTexture(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_motionVectorTexture) |cached| {
            return cached;
        }
        const value = try XRWebGLSubImageImpl.get_motionVectorTexture(instance);
        state.own.cached_motionVectorTexture = value;
        return value;
    }

    pub fn get_imageIndex(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_imageIndex(instance);
    }

    pub fn get_colorTextureWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLSubImageImpl.get_colorTextureWidth(instance);
    }

    pub fn get_colorTextureHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLSubImageImpl.get_colorTextureHeight(instance);
    }

    pub fn get_depthStencilTextureWidth(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_depthStencilTextureWidth(instance);
    }

    pub fn get_depthStencilTextureHeight(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_depthStencilTextureHeight(instance);
    }

    pub fn get_motionVectorTextureWidth(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_motionVectorTextureWidth(instance);
    }

    pub fn get_motionVectorTextureHeight(instance: *runtime.Instance) anyerror!?u32 {
        return try XRWebGLSubImageImpl.get_motionVectorTextureHeight(instance);
    }

};
