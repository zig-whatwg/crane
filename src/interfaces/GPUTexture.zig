//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUTextureImpl = @import("../impls/GPUTexture.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GPUTextureImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUTextureImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_height(state);
    }

    pub fn get_depthOrArrayLayers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_depthOrArrayLayers(state);
    }

    pub fn get_mipLevelCount(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_mipLevelCount(state);
    }

    pub fn get_sampleCount(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_sampleCount(state);
    }

    pub fn get_dimension(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_dimension(state);
    }

    pub fn get_format(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_format(state);
    }

    pub fn get_usage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.get_usage(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPUTextureImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPUTextureImpl.set_label(state, value);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUTextureImpl.call_destroy(state);
    }

    pub fn call_createView(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUTextureImpl.call_createView(state, descriptor);
    }

};
