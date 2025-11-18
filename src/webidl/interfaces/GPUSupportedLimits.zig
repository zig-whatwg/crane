//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUSupportedLimitsImpl = @import("impls").GPUSupportedLimits;

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
        
        // Initialize the instance (Impl receives full instance)
        GPUSupportedLimitsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUSupportedLimitsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_maxTextureDimension1D(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxTextureDimension1D(instance);
    }

    pub fn get_maxTextureDimension2D(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxTextureDimension2D(instance);
    }

    pub fn get_maxTextureDimension3D(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxTextureDimension3D(instance);
    }

    pub fn get_maxTextureArrayLayers(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxTextureArrayLayers(instance);
    }

    pub fn get_maxBindGroups(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxBindGroups(instance);
    }

    pub fn get_maxBindGroupsPlusVertexBuffers(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxBindGroupsPlusVertexBuffers(instance);
    }

    pub fn get_maxBindingsPerBindGroup(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxBindingsPerBindGroup(instance);
    }

    pub fn get_maxDynamicUniformBuffersPerPipelineLayout(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxDynamicUniformBuffersPerPipelineLayout(instance);
    }

    pub fn get_maxDynamicStorageBuffersPerPipelineLayout(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxDynamicStorageBuffersPerPipelineLayout(instance);
    }

    pub fn get_maxSampledTexturesPerShaderStage(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxSampledTexturesPerShaderStage(instance);
    }

    pub fn get_maxSamplersPerShaderStage(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxSamplersPerShaderStage(instance);
    }

    pub fn get_maxStorageBuffersPerShaderStage(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxStorageBuffersPerShaderStage(instance);
    }

    pub fn get_maxStorageTexturesPerShaderStage(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxStorageTexturesPerShaderStage(instance);
    }

    pub fn get_maxUniformBuffersPerShaderStage(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxUniformBuffersPerShaderStage(instance);
    }

    pub fn get_maxUniformBufferBindingSize(instance: *runtime.Instance) anyerror!u64 {
        return try GPUSupportedLimitsImpl.get_maxUniformBufferBindingSize(instance);
    }

    pub fn get_maxStorageBufferBindingSize(instance: *runtime.Instance) anyerror!u64 {
        return try GPUSupportedLimitsImpl.get_maxStorageBufferBindingSize(instance);
    }

    pub fn get_minUniformBufferOffsetAlignment(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_minUniformBufferOffsetAlignment(instance);
    }

    pub fn get_minStorageBufferOffsetAlignment(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_minStorageBufferOffsetAlignment(instance);
    }

    pub fn get_maxVertexBuffers(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxVertexBuffers(instance);
    }

    pub fn get_maxBufferSize(instance: *runtime.Instance) anyerror!u64 {
        return try GPUSupportedLimitsImpl.get_maxBufferSize(instance);
    }

    pub fn get_maxVertexAttributes(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxVertexAttributes(instance);
    }

    pub fn get_maxVertexBufferArrayStride(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxVertexBufferArrayStride(instance);
    }

    pub fn get_maxInterStageShaderVariables(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxInterStageShaderVariables(instance);
    }

    pub fn get_maxColorAttachments(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxColorAttachments(instance);
    }

    pub fn get_maxColorAttachmentBytesPerSample(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxColorAttachmentBytesPerSample(instance);
    }

    pub fn get_maxComputeWorkgroupStorageSize(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxComputeWorkgroupStorageSize(instance);
    }

    pub fn get_maxComputeInvocationsPerWorkgroup(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxComputeInvocationsPerWorkgroup(instance);
    }

    pub fn get_maxComputeWorkgroupSizeX(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxComputeWorkgroupSizeX(instance);
    }

    pub fn get_maxComputeWorkgroupSizeY(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxComputeWorkgroupSizeY(instance);
    }

    pub fn get_maxComputeWorkgroupSizeZ(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxComputeWorkgroupSizeZ(instance);
    }

    pub fn get_maxComputeWorkgroupsPerDimension(instance: *runtime.Instance) anyerror!u32 {
        return try GPUSupportedLimitsImpl.get_maxComputeWorkgroupsPerDimension(instance);
    }

};
