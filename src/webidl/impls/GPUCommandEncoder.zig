//! Implementation for GPUCommandEncoder interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPUCommandEncoder = @import("interfaces").GPUCommandEncoder;

pub const State = GPUCommandEncoder.State;

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

/// Getter for label
pub fn get_label(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for label
pub fn set_label(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: beginRenderPass
pub fn call_beginRenderPass(instance: *runtime.Instance, descriptor: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = descriptor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: beginComputePass
pub fn call_beginComputePass(instance: *runtime.Instance, descriptor: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = descriptor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyBufferToBuffer
pub fn call_copyBufferToBuffer(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyBufferToBuffer
pub fn call_copyBufferToBuffer(instance: *runtime.Instance, source: anyopaque, sourceOffset: anyopaque, destination: anyopaque, destinationOffset: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = source;
    _ = sourceOffset;
    _ = destination;
    _ = destinationOffset;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyBufferToTexture
pub fn call_copyBufferToTexture(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyTextureToBuffer
pub fn call_copyTextureToBuffer(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: copyTextureToTexture
pub fn call_copyTextureToTexture(instance: *runtime.Instance, source: anyopaque, destination: anyopaque, copySize: anyopaque) ImplError!void {
    _ = instance;
    _ = source;
    _ = destination;
    _ = copySize;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearBuffer
pub fn call_clearBuffer(instance: *runtime.Instance, buffer: anyopaque, offset: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = offset;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: resolveQuerySet
pub fn call_resolveQuerySet(instance: *runtime.Instance, querySet: anyopaque, firstQuery: anyopaque, queryCount: anyopaque, destination: anyopaque, destinationOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = querySet;
    _ = firstQuery;
    _ = queryCount;
    _ = destination;
    _ = destinationOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: finish
pub fn call_finish(instance: *runtime.Instance, descriptor: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = descriptor;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: pushDebugGroup
pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = groupLabel;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: popDebugGroup
pub fn call_popDebugGroup(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertDebugMarker
pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = markerLabel;
    // TODO: Implement operation
    return error.NotImplemented;
}

