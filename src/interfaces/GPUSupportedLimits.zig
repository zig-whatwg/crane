//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUSupportedLimitsImpl = @import("../impls/GPUSupportedLimits.zig");

pub const GPUSupportedLimits = struct {
    pub const Meta = struct {
        pub const name = "GPUSupportedLimits";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
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
            maxTextureDimension1D: u32 = undefined,
            maxTextureDimension2D: u32 = undefined,
            maxTextureDimension3D: u32 = undefined,
            maxTextureArrayLayers: u32 = undefined,
            maxBindGroups: u32 = undefined,
            maxBindGroupsPlusVertexBuffers: u32 = undefined,
            maxBindingsPerBindGroup: u32 = undefined,
            maxDynamicUniformBuffersPerPipelineLayout: u32 = undefined,
            maxDynamicStorageBuffersPerPipelineLayout: u32 = undefined,
            maxSampledTexturesPerShaderStage: u32 = undefined,
            maxSamplersPerShaderStage: u32 = undefined,
            maxStorageBuffersPerShaderStage: u32 = undefined,
            maxStorageTexturesPerShaderStage: u32 = undefined,
            maxUniformBuffersPerShaderStage: u32 = undefined,
            maxUniformBufferBindingSize: u64 = undefined,
            maxStorageBufferBindingSize: u64 = undefined,
            minUniformBufferOffsetAlignment: u32 = undefined,
            minStorageBufferOffsetAlignment: u32 = undefined,
            maxVertexBuffers: u32 = undefined,
            maxBufferSize: u64 = undefined,
            maxVertexAttributes: u32 = undefined,
            maxVertexBufferArrayStride: u32 = undefined,
            maxInterStageShaderVariables: u32 = undefined,
            maxColorAttachments: u32 = undefined,
            maxColorAttachmentBytesPerSample: u32 = undefined,
            maxComputeWorkgroupStorageSize: u32 = undefined,
            maxComputeInvocationsPerWorkgroup: u32 = undefined,
            maxComputeWorkgroupSizeX: u32 = undefined,
            maxComputeWorkgroupSizeY: u32 = undefined,
            maxComputeWorkgroupSizeZ: u32 = undefined,
            maxComputeWorkgroupsPerDimension: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUSupportedLimits, .{
        .deinit_fn = &deinit_wrapper,

        .get_maxBindGroups = &get_maxBindGroups,
        .get_maxBindGroupsPlusVertexBuffers = &get_maxBindGroupsPlusVertexBuffers,
        .get_maxBindingsPerBindGroup = &get_maxBindingsPerBindGroup,
        .get_maxBufferSize = &get_maxBufferSize,
        .get_maxColorAttachmentBytesPerSample = &get_maxColorAttachmentBytesPerSample,
        .get_maxColorAttachments = &get_maxColorAttachments,
        .get_maxComputeInvocationsPerWorkgroup = &get_maxComputeInvocationsPerWorkgroup,
        .get_maxComputeWorkgroupSizeX = &get_maxComputeWorkgroupSizeX,
        .get_maxComputeWorkgroupSizeY = &get_maxComputeWorkgroupSizeY,
        .get_maxComputeWorkgroupSizeZ = &get_maxComputeWorkgroupSizeZ,
        .get_maxComputeWorkgroupStorageSize = &get_maxComputeWorkgroupStorageSize,
        .get_maxComputeWorkgroupsPerDimension = &get_maxComputeWorkgroupsPerDimension,
        .get_maxDynamicStorageBuffersPerPipelineLayout = &get_maxDynamicStorageBuffersPerPipelineLayout,
        .get_maxDynamicUniformBuffersPerPipelineLayout = &get_maxDynamicUniformBuffersPerPipelineLayout,
        .get_maxInterStageShaderVariables = &get_maxInterStageShaderVariables,
        .get_maxSampledTexturesPerShaderStage = &get_maxSampledTexturesPerShaderStage,
        .get_maxSamplersPerShaderStage = &get_maxSamplersPerShaderStage,
        .get_maxStorageBufferBindingSize = &get_maxStorageBufferBindingSize,
        .get_maxStorageBuffersPerShaderStage = &get_maxStorageBuffersPerShaderStage,
        .get_maxStorageTexturesPerShaderStage = &get_maxStorageTexturesPerShaderStage,
        .get_maxTextureArrayLayers = &get_maxTextureArrayLayers,
        .get_maxTextureDimension1D = &get_maxTextureDimension1D,
        .get_maxTextureDimension2D = &get_maxTextureDimension2D,
        .get_maxTextureDimension3D = &get_maxTextureDimension3D,
        .get_maxUniformBufferBindingSize = &get_maxUniformBufferBindingSize,
        .get_maxUniformBuffersPerShaderStage = &get_maxUniformBuffersPerShaderStage,
        .get_maxVertexAttributes = &get_maxVertexAttributes,
        .get_maxVertexBufferArrayStride = &get_maxVertexBufferArrayStride,
        .get_maxVertexBuffers = &get_maxVertexBuffers,
        .get_minStorageBufferOffsetAlignment = &get_minStorageBufferOffsetAlignment,
        .get_minUniformBufferOffsetAlignment = &get_minUniformBufferOffsetAlignment,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUSupportedLimitsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUSupportedLimitsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_maxTextureDimension1D(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxTextureDimension1D(state);
    }

    pub fn get_maxTextureDimension2D(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxTextureDimension2D(state);
    }

    pub fn get_maxTextureDimension3D(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxTextureDimension3D(state);
    }

    pub fn get_maxTextureArrayLayers(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxTextureArrayLayers(state);
    }

    pub fn get_maxBindGroups(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxBindGroups(state);
    }

    pub fn get_maxBindGroupsPlusVertexBuffers(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxBindGroupsPlusVertexBuffers(state);
    }

    pub fn get_maxBindingsPerBindGroup(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxBindingsPerBindGroup(state);
    }

    pub fn get_maxDynamicUniformBuffersPerPipelineLayout(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxDynamicUniformBuffersPerPipelineLayout(state);
    }

    pub fn get_maxDynamicStorageBuffersPerPipelineLayout(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxDynamicStorageBuffersPerPipelineLayout(state);
    }

    pub fn get_maxSampledTexturesPerShaderStage(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxSampledTexturesPerShaderStage(state);
    }

    pub fn get_maxSamplersPerShaderStage(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxSamplersPerShaderStage(state);
    }

    pub fn get_maxStorageBuffersPerShaderStage(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxStorageBuffersPerShaderStage(state);
    }

    pub fn get_maxStorageTexturesPerShaderStage(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxStorageTexturesPerShaderStage(state);
    }

    pub fn get_maxUniformBuffersPerShaderStage(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxUniformBuffersPerShaderStage(state);
    }

    pub fn get_maxUniformBufferBindingSize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxUniformBufferBindingSize(state);
    }

    pub fn get_maxStorageBufferBindingSize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxStorageBufferBindingSize(state);
    }

    pub fn get_minUniformBufferOffsetAlignment(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_minUniformBufferOffsetAlignment(state);
    }

    pub fn get_minStorageBufferOffsetAlignment(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_minStorageBufferOffsetAlignment(state);
    }

    pub fn get_maxVertexBuffers(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxVertexBuffers(state);
    }

    pub fn get_maxBufferSize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxBufferSize(state);
    }

    pub fn get_maxVertexAttributes(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxVertexAttributes(state);
    }

    pub fn get_maxVertexBufferArrayStride(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxVertexBufferArrayStride(state);
    }

    pub fn get_maxInterStageShaderVariables(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxInterStageShaderVariables(state);
    }

    pub fn get_maxColorAttachments(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxColorAttachments(state);
    }

    pub fn get_maxColorAttachmentBytesPerSample(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxColorAttachmentBytesPerSample(state);
    }

    pub fn get_maxComputeWorkgroupStorageSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxComputeWorkgroupStorageSize(state);
    }

    pub fn get_maxComputeInvocationsPerWorkgroup(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxComputeInvocationsPerWorkgroup(state);
    }

    pub fn get_maxComputeWorkgroupSizeX(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxComputeWorkgroupSizeX(state);
    }

    pub fn get_maxComputeWorkgroupSizeY(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxComputeWorkgroupSizeY(state);
    }

    pub fn get_maxComputeWorkgroupSizeZ(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxComputeWorkgroupSizeZ(state);
    }

    pub fn get_maxComputeWorkgroupsPerDimension(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUSupportedLimitsImpl.get_maxComputeWorkgroupsPerDimension(state);
    }

};
