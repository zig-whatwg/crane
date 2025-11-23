//! Implementation for GPUDevice interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GPUDevice = interfaces.GPUDevice;

pub const State = GPUDevice.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for features
pub fn get_features(instance: *runtime.Instance) ImplError!interfaces.GPUSupportedFeatures {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for limits
pub fn get_limits(instance: *runtime.Instance) ImplError!interfaces.GPUSupportedLimits {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for adapterInfo
pub fn get_adapterInfo(instance: *runtime.Instance) ImplError!interfaces.GPUAdapterInfo {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for queue
pub fn get_queue(instance: *runtime.Instance) ImplError!interfaces.GPUQueue {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lost
pub fn get_lost(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onuncapturederror
pub fn get_onuncapturederror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for label
pub fn get_label(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onuncapturederror
pub fn set_onuncapturederror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for label
pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: createQuerySet
pub fn call_createQuerySet(instance: *runtime.Instance, descriptor: dictionaries.GPUQuerySetDescriptor) ImplError!interfaces.GPUQuerySet {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createTexture
pub fn call_createTexture(instance: *runtime.Instance, descriptor: dictionaries.GPUTextureDescriptor) ImplError!interfaces.GPUTexture {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createRenderPipeline
pub fn call_createRenderPipeline(instance: *runtime.Instance, descriptor: dictionaries.GPURenderPipelineDescriptor) ImplError!interfaces.GPURenderPipeline {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createRenderPipelineAsync
pub fn call_createRenderPipelineAsync(instance: *runtime.Instance, descriptor: dictionaries.GPURenderPipelineDescriptor) ImplError!*const anyopaque {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createPipelineLayout
pub fn call_createPipelineLayout(instance: *runtime.Instance, descriptor: dictionaries.GPUPipelineLayoutDescriptor) ImplError!interfaces.GPUPipelineLayout {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createShaderModule
pub fn call_createShaderModule(instance: *runtime.Instance, descriptor: dictionaries.GPUShaderModuleDescriptor) ImplError!interfaces.GPUShaderModule {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createCommandEncoder
pub fn call_createCommandEncoder(instance: *runtime.Instance, descriptor: dictionaries.GPUCommandEncoderDescriptor) ImplError!interfaces.GPUCommandEncoder {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createComputePipelineAsync
pub fn call_createComputePipelineAsync(instance: *runtime.Instance, descriptor: dictionaries.GPUComputePipelineDescriptor) ImplError!*const anyopaque {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createBindGroupLayout
pub fn call_createBindGroupLayout(instance: *runtime.Instance, descriptor: dictionaries.GPUBindGroupLayoutDescriptor) ImplError!interfaces.GPUBindGroupLayout {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createSampler
pub fn call_createSampler(instance: *runtime.Instance, descriptor: dictionaries.GPUSamplerDescriptor) ImplError!interfaces.GPUSampler {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: importExternalTexture
pub fn call_importExternalTexture(instance: *runtime.Instance, descriptor: dictionaries.GPUExternalTextureDescriptor) ImplError!interfaces.GPUExternalTexture {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createComputePipeline
pub fn call_createComputePipeline(instance: *runtime.Instance, descriptor: dictionaries.GPUComputePipelineDescriptor) ImplError!interfaces.GPUComputePipeline {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: destroy
pub fn call_destroy(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: createRenderBundleEncoder
pub fn call_createRenderBundleEncoder(instance: *runtime.Instance, descriptor: dictionaries.GPURenderBundleEncoderDescriptor) ImplError!interfaces.GPURenderBundleEncoder {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: pushErrorScope
pub fn call_pushErrorScope(instance: *runtime.Instance, filter: enums.GPUErrorFilter) ImplError!void {
    _ = instance;
    _ = filter;
    return error.NotImplemented;
}

/// Operation: createBuffer
pub fn call_createBuffer(instance: *runtime.Instance, descriptor: dictionaries.GPUBufferDescriptor) ImplError!interfaces.GPUBuffer {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: createBindGroup
pub fn call_createBindGroup(instance: *runtime.Instance, descriptor: dictionaries.GPUBindGroupDescriptor) ImplError!interfaces.GPUBindGroup {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: popErrorScope
pub fn call_popErrorScope(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

