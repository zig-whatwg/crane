//! Generated from: webxr-depth-sensing.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLDepthInformationImpl = @import("../impls/XRWebGLDepthInformation.zig");
const XRDepthInformation = @import("XRDepthInformation.zig");

pub const XRWebGLDepthInformation = struct {
    pub const Meta = struct {
        pub const name = "XRWebGLDepthInformation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRDepthInformation;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            texture: WebGLTexture = undefined,
            textureType: XRTextureType = undefined,
            imageIndex: ?u32 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRWebGLDepthInformation, .{
        .deinit_fn = &deinit_wrapper,

        .get_height = &get_height,
        .get_imageIndex = &get_imageIndex,
        .get_normDepthBufferFromNormView = &get_normDepthBufferFromNormView,
        .get_projectionMatrix = &get_projectionMatrix,
        .get_rawValueToMeters = &get_rawValueToMeters,
        .get_texture = &get_texture,
        .get_textureType = &get_textureType,
        .get_transform = &get_transform,
        .get_width = &get_width,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRWebGLDepthInformationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRWebGLDepthInformationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRWebGLDepthInformationImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRWebGLDepthInformationImpl.get_height(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_normDepthBufferFromNormView(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_normDepthBufferFromNormView) |cached| {
            return cached;
        }
        const value = XRWebGLDepthInformationImpl.get_normDepthBufferFromNormView(state);
        state.cached_normDepthBufferFromNormView = value;
        return value;
    }

    pub fn get_rawValueToMeters(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XRWebGLDepthInformationImpl.get_rawValueToMeters(state);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLDepthInformationImpl.get_projectionMatrix(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = XRWebGLDepthInformationImpl.get_transform(state);
        state.cached_transform = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_texture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_texture) |cached| {
            return cached;
        }
        const value = XRWebGLDepthInformationImpl.get_texture(state);
        state.cached_texture = value;
        return value;
    }

    pub fn get_textureType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLDepthInformationImpl.get_textureType(state);
    }

    pub fn get_imageIndex(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRWebGLDepthInformationImpl.get_imageIndex(state);
    }

};
