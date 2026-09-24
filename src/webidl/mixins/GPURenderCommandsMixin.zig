//! Auto-generated mixin: GPURenderCommandsMixin
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPURenderCommandsMixinImpl = @import("impls").GPURenderCommandsMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUSignedOffset32 = @import("typedefs").GPUSignedOffset32;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPUIndexFormat = @import("enums").GPUIndexFormat;

pub const impl = @import("impls").GPURenderCommandsMixin;

pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: GPUIndex32, buffer: ?*runtime.Instance, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!void {
    return try GPURenderCommandsMixinImpl.call_setVertexBuffer(instance, slot, buffer, offset, size);
}

pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, indexFormat: GPUIndexFormat, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!void {
    return try GPURenderCommandsMixinImpl.call_setIndexBuffer(instance, buffer, indexFormat, offset, size);
}

pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
    return try GPURenderCommandsMixinImpl.call_drawIndexedIndirect(instance, indirectBuffer, indirectOffset);
}

pub fn call_draw(instance: *runtime.Instance, vertexCount: GPUSize32, instanceCount: webidl.Opt(GPUSize32), firstVertex: webidl.Opt(GPUSize32), firstInstance: webidl.Opt(GPUSize32)) anyerror!void {
    return try GPURenderCommandsMixinImpl.call_draw(instance, vertexCount, instanceCount, firstVertex, firstInstance);
}

pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: GPUSize32, instanceCount: webidl.Opt(GPUSize32), firstIndex: webidl.Opt(GPUSize32), baseVertex: webidl.Opt(GPUSignedOffset32), firstInstance: webidl.Opt(GPUSize32)) anyerror!void {
    return try GPURenderCommandsMixinImpl.call_drawIndexed(instance, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
}

pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
    return try GPURenderCommandsMixinImpl.call_drawIndirect(instance, indirectBuffer, indirectOffset);
}

pub fn call_setPipeline(instance: *runtime.Instance, pipeline: *runtime.Instance) anyerror!void {
    return try GPURenderCommandsMixinImpl.call_setPipeline(instance, pipeline);
}
