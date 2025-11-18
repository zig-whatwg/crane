//! Implementation for GPURenderPassEncoder interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderPassEncoder = @import("interfaces").GPURenderPassEncoder;

pub const State = GPURenderPassEncoder.State;

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

/// Operation: setViewport
pub fn call_setViewport(instance: *runtime.Instance, x: f32, y: f32, width: f32, height: f32, minDepth: f32, maxDepth: f32) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    _ = minDepth;
    _ = maxDepth;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setScissorRect
pub fn call_setScissorRect(instance: *runtime.Instance, x: anyopaque, y: anyopaque, width: anyopaque, height: anyopaque) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setBlendConstant
pub fn call_setBlendConstant(instance: *runtime.Instance, color: anyopaque) ImplError!void {
    _ = instance;
    _ = color;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setStencilReference
pub fn call_setStencilReference(instance: *runtime.Instance, reference: anyopaque) ImplError!void {
    _ = instance;
    _ = reference;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: beginOcclusionQuery
pub fn call_beginOcclusionQuery(instance: *runtime.Instance, queryIndex: anyopaque) ImplError!void {
    _ = instance;
    _ = queryIndex;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: endOcclusionQuery
pub fn call_endOcclusionQuery(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: executeBundles
pub fn call_executeBundles(instance: *runtime.Instance, bundles: anyopaque) ImplError!void {
    _ = instance;
    _ = bundles;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: end
pub fn call_end(instance: *runtime.Instance) ImplError!void {
    _ = instance;
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

/// Operation: setBindGroup
pub fn call_setBindGroup(instance: *runtime.Instance, index: anyopaque, bindGroup: anyopaque, dynamicOffsets: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = bindGroup;
    _ = dynamicOffsets;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setBindGroup
pub fn call_setBindGroup(instance: *runtime.Instance, index: anyopaque, bindGroup: anyopaque, dynamicOffsetsData: anyopaque, dynamicOffsetsDataStart: anyopaque, dynamicOffsetsDataLength: anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = bindGroup;
    _ = dynamicOffsetsData;
    _ = dynamicOffsetsDataStart;
    _ = dynamicOffsetsDataLength;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setPipeline
pub fn call_setPipeline(instance: *runtime.Instance, pipeline: anyopaque) ImplError!void {
    _ = instance;
    _ = pipeline;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setIndexBuffer
pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: anyopaque, indexFormat: anyopaque, offset: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = indexFormat;
    _ = offset;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setVertexBuffer
pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: anyopaque, buffer: anyopaque, offset: anyopaque, size: anyopaque) ImplError!void {
    _ = instance;
    _ = slot;
    _ = buffer;
    _ = offset;
    _ = size;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: draw
pub fn call_draw(instance: *runtime.Instance, vertexCount: anyopaque, instanceCount: anyopaque, firstVertex: anyopaque, firstInstance: anyopaque) ImplError!void {
    _ = instance;
    _ = vertexCount;
    _ = instanceCount;
    _ = firstVertex;
    _ = firstInstance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawIndexed
pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: anyopaque, instanceCount: anyopaque, firstIndex: anyopaque, baseVertex: anyopaque, firstInstance: anyopaque) ImplError!void {
    _ = instance;
    _ = indexCount;
    _ = instanceCount;
    _ = firstIndex;
    _ = baseVertex;
    _ = firstInstance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawIndirect
pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: drawIndexedIndirect
pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

