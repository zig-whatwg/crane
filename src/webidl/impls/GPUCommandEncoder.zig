//! Implementation for GPUCommandEncoder interface
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
const GPUCommandEncoder = interfaces.GPUCommandEncoder;

pub const State = GPUCommandEncoder.State;

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

/// Getter for label
pub fn get_label(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for label
pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: copyBufferToBuffer
pub fn call_copyBufferToBuffer(instance: *runtime.Instance, source: interfaces.GPUBuffer, destination: interfaces.GPUBuffer, size: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = size;
    return error.NotImplemented;
}

/// Operation: copyTextureToBuffer
pub fn call_copyTextureToBuffer(instance: *runtime.Instance, source: dictionaries.GPUTexelCopyTextureInfo, destination: dictionaries.GPUTexelCopyBufferInfo, copySize: typedefs.GPUExtent3D) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    return error.NotImplemented;
}

/// Operation: copyBufferToTexture
pub fn call_copyBufferToTexture(instance: *runtime.Instance, source: dictionaries.GPUTexelCopyBufferInfo, destination: dictionaries.GPUTexelCopyTextureInfo, copySize: typedefs.GPUExtent3D) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    return error.NotImplemented;
}

/// Operation: popDebugGroup
pub fn call_popDebugGroup(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: copyTextureToTexture
pub fn call_copyTextureToTexture(instance: *runtime.Instance, source: dictionaries.GPUTexelCopyTextureInfo, destination: dictionaries.GPUTexelCopyTextureInfo, copySize: typedefs.GPUExtent3D) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    return error.NotImplemented;
}

/// Operation: resolveQuerySet
pub fn call_resolveQuerySet(instance: *runtime.Instance, querySet: interfaces.GPUQuerySet, firstQuery: typedefs.GPUSize32, queryCount: typedefs.GPUSize32, destination: interfaces.GPUBuffer, destinationOffset: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = querySet;
    _ = firstQuery;
    _ = queryCount;
    _ = destination;
    _ = destinationOffset;
    return error.NotImplemented;
}

/// Operation: insertDebugMarker
pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) ImplError!void {
    _ = instance;
    _ = markerLabel;
    return error.NotImplemented;
}

/// Operation: pushDebugGroup
pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) ImplError!void {
    _ = instance;
    _ = groupLabel;
    return error.NotImplemented;
}

/// Operation: finish
pub fn call_finish(instance: *runtime.Instance, descriptor: dictionaries.GPUCommandBufferDescriptor) ImplError!interfaces.GPUCommandBuffer {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: beginComputePass
pub fn call_beginComputePass(instance: *runtime.Instance, descriptor: dictionaries.GPUComputePassDescriptor) ImplError!interfaces.GPUComputePassEncoder {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: beginRenderPass
pub fn call_beginRenderPass(instance: *runtime.Instance, descriptor: dictionaries.GPURenderPassDescriptor) ImplError!interfaces.GPURenderPassEncoder {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: clearBuffer
pub fn call_clearBuffer(instance: *runtime.Instance, buffer: interfaces.GPUBuffer, offset: typedefs.GPUSize64, size: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

