//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderPassEncoderImpl = @import("impls").GPURenderPassEncoder;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUCommandsMixin = @import("interfaces").GPUCommandsMixin;
const GPUDebugCommandsMixin = @import("interfaces").GPUDebugCommandsMixin;
const GPUBindingCommandsMixin = @import("interfaces").GPUBindingCommandsMixin;
const GPURenderCommandsMixin = @import("interfaces").GPURenderCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const Uint32Array = @import("interfaces").Uint32Array;
const GPUIntegerCoordinate = @import("typedefs").GPUIntegerCoordinate;
const GPUStencilValue = @import("typedefs").GPUStencilValue;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUIndexFormat = @import("enums").GPUIndexFormat;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUSignedOffset32 = @import("typedefs").GPUSignedOffset32;
const GPUColor = @import("typedefs").GPUColor;

pub const GPURenderPassEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPURenderPassEncoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
            GPUCommandsMixin,
            GPUDebugCommandsMixin,
            GPUBindingCommandsMixin,
            GPURenderCommandsMixin,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPURenderPassEncoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_beginOcclusionQuery = &call_beginOcclusionQuery,
        .call_draw = &call_draw,
        .call_drawIndexed = &call_drawIndexed,
        .call_drawIndexedIndirect = &call_drawIndexedIndirect,
        .call_drawIndirect = &call_drawIndirect,
        .call_end = &call_end,
        .call_endOcclusionQuery = &call_endOcclusionQuery,
        .call_executeBundles = &call_executeBundles,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_setBindGroup = &call_setBindGroup,
        .call_setBlendConstant = &call_setBlendConstant,
        .call_setIndexBuffer = &call_setIndexBuffer,
        .call_setPipeline = &call_setPipeline,
        .call_setScissorRect = &call_setScissorRect,
        .call_setStencilReference = &call_setStencilReference,
        .call_setVertexBuffer = &call_setVertexBuffer,
        .call_setViewport = &call_setViewport,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPURenderPassEncoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPURenderPassEncoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPURenderPassEncoderImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPURenderPassEncoderImpl.set_label(instance, value);
    }

    pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: GPUBuffer, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_drawIndexedIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_setBlendConstant(instance: *runtime.Instance, color: GPUColor) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_setBlendConstant(instance, color);
    }

    /// Arguments for setBindGroup (WebIDL overloading)
    pub const SetBindGroupArgs = union(enum) {
        /// setBindGroup(index, bindGroup, dynamicOffsets)
        GPUIndex32_GPUBindGroup?_sequence: struct {
            index: GPUIndex32,
            bindGroup: anyopaque,
            dynamicOffsets: anyopaque,
        },
        /// setBindGroup(index, bindGroup, dynamicOffsetsData, dynamicOffsetsDataStart, dynamicOffsetsDataLength)
        GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32: struct {
            index: GPUIndex32,
            bindGroup: anyopaque,
            dynamicOffsetsData: anyopaque,
            dynamicOffsetsDataStart: GPUSize64,
            dynamicOffsetsDataLength: GPUSize32,
        },
    };

    pub fn call_setBindGroup(instance: *runtime.Instance, args: SetBindGroupArgs) anyerror!void {
        switch (args) {
            .GPUIndex32_GPUBindGroup?_sequence => |a| return try GPURenderPassEncoderImpl.GPUIndex32_GPUBindGroup?_sequence(instance, a.index, a.bindGroup, a.dynamicOffsets),
            .GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32 => |a| return try GPURenderPassEncoderImpl.GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32(instance, a.index, a.bindGroup, a.dynamicOffsetsData, a.dynamicOffsetsDataStart, a.dynamicOffsetsDataLength),
        }
    }

    pub fn call_endOcclusionQuery(instance: *runtime.Instance) anyerror!void {
        return try GPURenderPassEncoderImpl.call_endOcclusionQuery(instance);
    }

    pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: GPUIndex32, buffer: anyopaque, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_setVertexBuffer(instance, slot, buffer, offset, size);
    }

    pub fn call_setScissorRect(instance: *runtime.Instance, x: GPUIntegerCoordinate, y: GPUIntegerCoordinate, width: GPUIntegerCoordinate, height: GPUIntegerCoordinate) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_setScissorRect(instance, x, y, width, height);
    }

    pub fn call_end(instance: *runtime.Instance) anyerror!void {
        return try GPURenderPassEncoderImpl.call_end(instance);
    }

    pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: GPUSize32, instanceCount: GPUSize32, firstIndex: GPUSize32, baseVertex: GPUSignedOffset32, firstInstance: GPUSize32) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_drawIndexed(instance, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
    }

    pub fn call_executeBundles(instance: *runtime.Instance, bundles: anyopaque) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_executeBundles(instance, bundles);
    }

    pub fn call_draw(instance: *runtime.Instance, vertexCount: GPUSize32, instanceCount: GPUSize32, firstVertex: GPUSize32, firstInstance: GPUSize32) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_draw(instance, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
        return try GPURenderPassEncoderImpl.call_popDebugGroup(instance);
    }

    pub fn call_setStencilReference(instance: *runtime.Instance, reference: GPUStencilValue) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_setStencilReference(instance, reference);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_insertDebugMarker(instance, markerLabel);
    }

    pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: GPUBuffer, indexFormat: GPUIndexFormat, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_setIndexBuffer(instance, buffer, indexFormat, offset, size);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_pushDebugGroup(instance, groupLabel);
    }

    pub fn call_beginOcclusionQuery(instance: *runtime.Instance, queryIndex: GPUSize32) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_beginOcclusionQuery(instance, queryIndex);
    }

    pub fn call_setViewport(instance: *runtime.Instance, x: f32, y: f32, width: f32, height: f32, minDepth: f32, maxDepth: f32) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_setViewport(instance, x, y, width, height, minDepth, maxDepth);
    }

    pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: GPUBuffer, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_drawIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: GPURenderPipeline) anyerror!void {
        
        return try GPURenderPassEncoderImpl.call_setPipeline(instance, pipeline);
    }

};
