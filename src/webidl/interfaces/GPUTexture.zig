//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUTextureImpl = @import("impls").GPUTexture;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUTextureDimension = @import("enums").GPUTextureDimension;
const GPUSize32Out = @import("typedefs").GPUSize32Out;
const GPUFlagsConstant = @import("typedefs").GPUFlagsConstant;
const GPUTextureFormat = @import("enums").GPUTextureFormat;
const GPUTextureViewDescriptor = @import("dictionaries").GPUTextureViewDescriptor;
const GPUIntegerCoordinateOut = @import("typedefs").GPUIntegerCoordinateOut;
const GPUTextureView = @import("interfaces").GPUTextureView;

pub const GPUTexture = struct {
    pub const Meta = struct {
        pub const name = "GPUTexture";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            width: GPUIntegerCoordinateOut = undefined,
            height: GPUIntegerCoordinateOut = undefined,
            depthOrArrayLayers: GPUIntegerCoordinateOut = undefined,
            mipLevelCount: GPUIntegerCoordinateOut = undefined,
            sampleCount: GPUSize32Out = undefined,
            dimension: GPUTextureDimension = undefined,
            format: GPUTextureFormat = undefined,
            usage: GPUFlagsConstant = undefined,
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUTexture, .{
        .deinit_fn = &deinit_wrapper,

        .get_depthOrArrayLayers = &get_depthOrArrayLayers,
        .get_dimension = &get_dimension,
        .get_format = &get_format,
        .get_height = &get_height,
        .get_label = &get_label,
        .get_mipLevelCount = &get_mipLevelCount,
        .get_sampleCount = &get_sampleCount,
        .get_usage = &get_usage,
        .get_width = &get_width,

        .set_label = &set_label,

        .call_createView = &call_createView,
        .call_destroy = &call_destroy,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUTextureImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUTextureImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_height(instance);
    }

    pub fn get_depthOrArrayLayers(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_depthOrArrayLayers(instance);
    }

    pub fn get_mipLevelCount(instance: *runtime.Instance) anyerror!GPUIntegerCoordinateOut {
        return try GPUTextureImpl.get_mipLevelCount(instance);
    }

    pub fn get_sampleCount(instance: *runtime.Instance) anyerror!GPUSize32Out {
        return try GPUTextureImpl.get_sampleCount(instance);
    }

    pub fn get_dimension(instance: *runtime.Instance) anyerror!GPUTextureDimension {
        return try GPUTextureImpl.get_dimension(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!GPUTextureFormat {
        return try GPUTextureImpl.get_format(instance);
    }

    pub fn get_usage(instance: *runtime.Instance) anyerror!GPUFlagsConstant {
        return try GPUTextureImpl.get_usage(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUTextureImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUTextureImpl.set_label(instance, value);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUTextureImpl.call_destroy(instance);
    }

    pub fn call_createView(instance: *runtime.Instance, descriptor: GPUTextureViewDescriptor) anyerror!GPUTextureView {
        
        return try GPUTextureImpl.call_createView(instance, descriptor);
    }

};
