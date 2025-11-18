//! Generated from: webxr-depth-sensing.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRWebGLDepthInformationImpl = @import("impls").XRWebGLDepthInformation;
const XRDepthInformation = @import("interfaces").XRDepthInformation;
const unsigned long = @import("interfaces").unsigned long;
const XRTextureType = @import("enums").XRTextureType;
const WebGLTexture = @import("interfaces").WebGLTexture;

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
        
        // Initialize the instance (Impl receives full instance)
        XRWebGLDepthInformationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRWebGLDepthInformationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLDepthInformationImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try XRWebGLDepthInformationImpl.get_height(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_normDepthBufferFromNormView(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_normDepthBufferFromNormView) |cached| {
            return cached;
        }
        const value = try XRWebGLDepthInformationImpl.get_normDepthBufferFromNormView(instance);
        state.cached_normDepthBufferFromNormView = value;
        return value;
    }

    pub fn get_rawValueToMeters(instance: *runtime.Instance) anyerror!f32 {
        return try XRWebGLDepthInformationImpl.get_rawValueToMeters(instance);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRWebGLDepthInformationImpl.get_projectionMatrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transform) |cached| {
            return cached;
        }
        const value = try XRWebGLDepthInformationImpl.get_transform(instance);
        state.cached_transform = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_texture(instance: *runtime.Instance) anyerror!WebGLTexture {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_texture) |cached| {
            return cached;
        }
        const value = try XRWebGLDepthInformationImpl.get_texture(instance);
        state.cached_texture = value;
        return value;
    }

    pub fn get_textureType(instance: *runtime.Instance) anyerror!XRTextureType {
        return try XRWebGLDepthInformationImpl.get_textureType(instance);
    }

    pub fn get_imageIndex(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRWebGLDepthInformationImpl.get_imageIndex(instance);
    }

};
