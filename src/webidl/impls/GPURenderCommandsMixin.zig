//! Implementation for GPURenderCommandsMixin interface
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
const GPURenderCommandsMixin = interfaces.GPURenderCommandsMixin;

pub const State = GPURenderCommandsMixin.State;

pub const ImplError = error{
    NotImplemented,
};

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

/// Operation: drawIndexedIndirect
pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
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

/// Operation: setVertexBuffer
pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: typedefs.GPUIndex32, buffer: *runtime.Instance, offset: typedefs.GPUSize64, size: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = slot;
    _ = buffer;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: setIndexBuffer
pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, indexFormat: enums.GPUIndexFormat, offset: typedefs.GPUSize64, size: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = buffer;
    _ = indexFormat;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: drawIndirect
pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: typedefs.GPUSize64) ImplError!void {
    _ = instance;
    _ = indirectBuffer;
    _ = indirectOffset;
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

/// Operation: setPipeline
pub fn call_setPipeline(instance: *runtime.Instance, pipeline: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = pipeline;
    return error.NotImplemented;
}

