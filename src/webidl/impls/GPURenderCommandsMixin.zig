//! Implementation for GPURenderCommandsMixin interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderCommandsMixin = @import("interfaces").GPURenderCommandsMixin;

pub const State = GPURenderCommandsMixin.State;

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

