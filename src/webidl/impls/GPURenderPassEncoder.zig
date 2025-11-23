//! Implementation for GPURenderPassEncoder interface
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
const GPURenderPassEncoder = interfaces.GPURenderPassEncoder;

pub const State = GPURenderPassEncoder.State;

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

/// Operation: drawIndexedIndirect
pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: interfaces.GPUBuffer, indirectOffset: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
    return error.NotImplemented;
}

/// Operation: setBlendConstant
pub fn call_setBlendConstant(instance: *runtime.Instance, color: typedefs.GPUColor) ImplError!void {
    _ = instance;
    _ = color;
    return error.NotImplemented;
}

/// Operation: setBindGroup
pub fn call_setBindGroup(instance: *runtime.Instance, index: typedefs.GPUIndex32, bindGroup: interfaces.GPUBindGroup, dynamicOffsets: *const anyopaque) ImplError!void {
    _ = instance;
    _ = index;
    _ = bindGroup;
    _ = dynamicOffsets;
    return error.NotImplemented;
}

/// Operation: endOcclusionQuery
pub fn call_endOcclusionQuery(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setVertexBuffer
pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: typedefs.GPUIndex32, buffer: interfaces.GPUBuffer, offset: typedefs.GPUSize64, size: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = slot;
    _ = buffer;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: setScissorRect
pub fn call_setScissorRect(instance: *runtime.Instance, x: typedefs.GPUIntegerCoordinate, y: typedefs.GPUIntegerCoordinate, width: typedefs.GPUIntegerCoordinate, height: typedefs.GPUIntegerCoordinate) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

/// Operation: end
pub fn call_end(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: drawIndexed
pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: typedefs.GPUSize32, instanceCount: typedefs.GPUSize32, firstIndex: typedefs.GPUSize32, baseVertex: typedefs.GPUSignedOffset32, firstInstance: typedefs.GPUSize32) ImplError!void {
    _ = instance;
    _ = indexCount;
    _ = instanceCount;
    _ = firstIndex;
    _ = baseVertex;
    _ = firstInstance;
    return error.NotImplemented;
}

/// Operation: executeBundles
pub fn call_executeBundles(instance: *runtime.Instance, bundles: *const anyopaque) ImplError!void {
    _ = instance;
    _ = bundles;
    return error.NotImplemented;
}

/// Operation: draw
pub fn call_draw(instance: *runtime.Instance, vertexCount: typedefs.GPUSize32, instanceCount: typedefs.GPUSize32, firstVertex: typedefs.GPUSize32, firstInstance: typedefs.GPUSize32) ImplError!void {
    _ = instance;
    _ = vertexCount;
    _ = instanceCount;
    _ = firstVertex;
    _ = firstInstance;
    return error.NotImplemented;
}

/// Operation: popDebugGroup
pub fn call_popDebugGroup(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setStencilReference
pub fn call_setStencilReference(instance: *runtime.Instance, reference: typedefs.GPUStencilValue) ImplError!void {
    _ = instance;
    _ = reference;
    return error.NotImplemented;
}

/// Operation: insertDebugMarker
pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) ImplError!void {
    _ = instance;
    _ = markerLabel;
    return error.NotImplemented;
}

/// Operation: setIndexBuffer
pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: interfaces.GPUBuffer, indexFormat: enums.GPUIndexFormat, offset: typedefs.GPUSize64, size: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = indexFormat;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: pushDebugGroup
pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) ImplError!void {
    _ = instance;
    _ = groupLabel;
    return error.NotImplemented;
}

/// Operation: beginOcclusionQuery
pub fn call_beginOcclusionQuery(instance: *runtime.Instance, queryIndex: typedefs.GPUSize32) ImplError!void {
    _ = instance;
    _ = queryIndex;
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
    return error.NotImplemented;
}

/// Operation: drawIndirect
pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: interfaces.GPUBuffer, indirectOffset: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
    return error.NotImplemented;
}

/// Operation: setPipeline
pub fn call_setPipeline(instance: *runtime.Instance, pipeline: interfaces.GPURenderPipeline) ImplError!void {
    _ = instance;
    _ = pipeline;
    return error.NotImplemented;
}

