//! Auto-generated mixin: GPURenderCommandsMixin
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GPURenderCommandsMixinImpl = @import("impls").GPURenderCommandsMixin;

// Re-export types from impl
pub const impl = @import("impls").GPURenderCommandsMixin;

pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: typedefs.GPUIndex32, buffer: ?*runtime.Instance, offset: typedefs.GPUSize64, size: typedefs.GPUSize64) anyerror!void {
    return GPURenderCommandsMixinImpl.call_setVertexBuffer(instance, slot, buffer, offset, size);
}

pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, indexFormat: enums.GPUIndexFormat, offset: typedefs.GPUSize64, size: typedefs.GPUSize64) anyerror!void {
    return GPURenderCommandsMixinImpl.call_setIndexBuffer(instance, buffer, indexFormat, offset, size);
}

pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: typedefs.GPUSize64) anyerror!void {
    return GPURenderCommandsMixinImpl.call_drawIndexedIndirect(instance, indirectBuffer, indirectOffset);
}

pub fn call_draw(instance: *runtime.Instance, vertexCount: typedefs.GPUSize32, instanceCount: typedefs.GPUSize32, firstVertex: typedefs.GPUSize32, firstInstance: typedefs.GPUSize32) anyerror!void {
    return GPURenderCommandsMixinImpl.call_draw(instance, vertexCount, instanceCount, firstVertex, firstInstance);
}

pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: typedefs.GPUSize32, instanceCount: typedefs.GPUSize32, firstIndex: typedefs.GPUSize32, baseVertex: typedefs.GPUSignedOffset32, firstInstance: typedefs.GPUSize32) anyerror!void {
    return GPURenderCommandsMixinImpl.call_drawIndexed(instance, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
}

pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: typedefs.GPUSize64) anyerror!void {
    return GPURenderCommandsMixinImpl.call_drawIndirect(instance, indirectBuffer, indirectOffset);
}

pub fn call_setPipeline(instance: *runtime.Instance, pipeline: *runtime.Instance) anyerror!void {
    return GPURenderCommandsMixinImpl.call_setPipeline(instance, pipeline);
}

