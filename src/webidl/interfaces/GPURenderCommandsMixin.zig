//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderCommandsMixinImpl = @import("impls").GPURenderCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUSignedOffset32 = @import("typedefs").GPUSignedOffset32;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPUIndexFormat = @import("enums").GPUIndexFormat;

pub const GPURenderCommandsMixin = struct {
    pub const Meta = struct {
        pub const name = "GPURenderCommandsMixin";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPURenderCommandsMixin, .{
        .deinit_fn = &deinit_wrapper,

        .call_draw = &call_draw,
        .call_drawIndexed = &call_drawIndexed,
        .call_drawIndexedIndirect = &call_drawIndexedIndirect,
        .call_drawIndirect = &call_drawIndirect,
        .call_setIndexBuffer = &call_setIndexBuffer,
        .call_setPipeline = &call_setPipeline,
        .call_setVertexBuffer = &call_setVertexBuffer,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPURenderCommandsMixinImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPURenderCommandsMixinImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: GPUBuffer, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_drawIndexedIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_draw(instance: *runtime.Instance, vertexCount: GPUSize32, instanceCount: GPUSize32, firstVertex: GPUSize32, firstInstance: GPUSize32) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_draw(instance, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: GPUIndex32, buffer: anyopaque, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_setVertexBuffer(instance, slot, buffer, offset, size);
    }

    pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: GPUBuffer, indexFormat: GPUIndexFormat, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_setIndexBuffer(instance, buffer, indexFormat, offset, size);
    }

    pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: GPUBuffer, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_drawIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: GPUSize32, instanceCount: GPUSize32, firstIndex: GPUSize32, baseVertex: GPUSignedOffset32, firstInstance: GPUSize32) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_drawIndexed(instance, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: GPURenderPipeline) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_setPipeline(instance, pipeline);
    }

};
