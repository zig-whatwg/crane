//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLSubImageImpl = @import("../impls/XRWebGLSubImage.zig");
const XRSubImage = @import("XRSubImage.zig");

pub const XRWebGLSubImage = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLSubImage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRSubImage;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            colorTexture: WebGLTexture = undefined,
            depthStencilTexture: ?WebGLTexture = null,
            motionVectorTexture: ?WebGLTexture = null,
            imageIndex: ?u32 = null,
            colorTextureWidth: u32 = undefined,
            colorTextureHeight: u32 = undefined,
            depthStencilTextureWidth: ?u32 = null,
            depthStencilTextureHeight: ?u32 = null,
            motionVectorTextureWidth: ?u32 = null,
            motionVectorTextureHeight: ?u32 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRWebGLSubImage, .{
        .deinit_fn = &deinit_wrapper,

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
        .get_viewport = &get_viewport,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRWebGLSubImageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRWebGLSubImageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_viewport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_viewport) |cached| {
            return cached;
        }
        const value = XRWebGLSubImageImpl.get_viewport(state);
        state.cached_viewport = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_colorTexture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_colorTexture) |cached| {
            return cached;
        }
        const value = XRWebGLSubImageImpl.get_colorTexture(state);
        state.cached_colorTexture = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_depthStencilTexture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_depthStencilTexture) |cached| {
            return cached;
        }
        const value = XRWebGLSubImageImpl.get_depthStencilTexture(state);
        state.cached_depthStencilTexture = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_motionVectorTexture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_motionVectorTexture) |cached| {
            return cached;
        }
        const value = XRWebGLSubImageImpl.get_motionVectorTexture(state);
        state.cached_motionVectorTexture = value;
        return value;
    }

    pub fn get_imageIndex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLSubImageImpl.get_imageIndex(state);
    }

    pub fn get_colorTextureWidth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRWebGLSubImageImpl.get_colorTextureWidth(state);
    }

    pub fn get_colorTextureHeight(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRWebGLSubImageImpl.get_colorTextureHeight(state);
    }

    pub fn get_depthStencilTextureWidth(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLSubImageImpl.get_depthStencilTextureWidth(state);
    }

    pub fn get_depthStencilTextureHeight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLSubImageImpl.get_depthStencilTextureHeight(state);
    }

    pub fn get_motionVectorTextureWidth(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLSubImageImpl.get_motionVectorTextureWidth(state);
    }

    pub fn get_motionVectorTextureHeight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLSubImageImpl.get_motionVectorTextureHeight(state);
    }

};
