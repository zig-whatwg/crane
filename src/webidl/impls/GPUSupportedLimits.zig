//! Implementation for GPUSupportedLimits interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPUSupportedLimits = @import("interfaces").GPUSupportedLimits;

pub const State = GPUSupportedLimits.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for maxTextureDimension1D
pub fn get_maxTextureDimension1D(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxTextureDimension2D
pub fn get_maxTextureDimension2D(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxTextureDimension3D
pub fn get_maxTextureDimension3D(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxTextureArrayLayers
pub fn get_maxTextureArrayLayers(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxBindGroups
pub fn get_maxBindGroups(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxBindGroupsPlusVertexBuffers
pub fn get_maxBindGroupsPlusVertexBuffers(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxBindingsPerBindGroup
pub fn get_maxBindingsPerBindGroup(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxDynamicUniformBuffersPerPipelineLayout
pub fn get_maxDynamicUniformBuffersPerPipelineLayout(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxDynamicStorageBuffersPerPipelineLayout
pub fn get_maxDynamicStorageBuffersPerPipelineLayout(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxSampledTexturesPerShaderStage
pub fn get_maxSampledTexturesPerShaderStage(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxSamplersPerShaderStage
pub fn get_maxSamplersPerShaderStage(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxStorageBuffersPerShaderStage
pub fn get_maxStorageBuffersPerShaderStage(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxStorageTexturesPerShaderStage
pub fn get_maxStorageTexturesPerShaderStage(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxUniformBuffersPerShaderStage
pub fn get_maxUniformBuffersPerShaderStage(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxUniformBufferBindingSize
pub fn get_maxUniformBufferBindingSize(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxStorageBufferBindingSize
pub fn get_maxStorageBufferBindingSize(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for minUniformBufferOffsetAlignment
pub fn get_minUniformBufferOffsetAlignment(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for minStorageBufferOffsetAlignment
pub fn get_minStorageBufferOffsetAlignment(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxVertexBuffers
pub fn get_maxVertexBuffers(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxBufferSize
pub fn get_maxBufferSize(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxVertexAttributes
pub fn get_maxVertexAttributes(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxVertexBufferArrayStride
pub fn get_maxVertexBufferArrayStride(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxInterStageShaderVariables
pub fn get_maxInterStageShaderVariables(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxColorAttachments
pub fn get_maxColorAttachments(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxColorAttachmentBytesPerSample
pub fn get_maxColorAttachmentBytesPerSample(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxComputeWorkgroupStorageSize
pub fn get_maxComputeWorkgroupStorageSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxComputeInvocationsPerWorkgroup
pub fn get_maxComputeInvocationsPerWorkgroup(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxComputeWorkgroupSizeX
pub fn get_maxComputeWorkgroupSizeX(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxComputeWorkgroupSizeY
pub fn get_maxComputeWorkgroupSizeY(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxComputeWorkgroupSizeZ
pub fn get_maxComputeWorkgroupSizeZ(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for maxComputeWorkgroupsPerDimension
pub fn get_maxComputeWorkgroupsPerDimension(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

