//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderBundleEncoderImpl = @import("impls").GPURenderBundleEncoder;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUCommandsMixin = @import("interfaces").GPUCommandsMixin;
const GPUDebugCommandsMixin = @import("interfaces").GPUDebugCommandsMixin;
const GPUBindingCommandsMixin = @import("interfaces").GPUBindingCommandsMixin;
const GPURenderCommandsMixin = @import("interfaces").GPURenderCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const Uint32Array = @import("interfaces").Uint32Array;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPURenderBundle = @import("interfaces").GPURenderBundle;
const GPUIndexFormat = @import("enums").GPUIndexFormat;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUSignedOffset32 = @import("typedefs").GPUSignedOffset32;
const GPURenderBundleDescriptor = @import("dictionaries").GPURenderBundleDescriptor;

pub const GPURenderBundleEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPURenderBundleEncoder";
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

    pub const vtable = runtime.buildVTable(GPURenderBundleEncoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_draw = &call_draw,
        .call_drawIndexed = &call_drawIndexed,
        .call_drawIndexedIndirect = &call_drawIndexedIndirect,
        .call_drawIndirect = &call_drawIndirect,
        .call_finish = &call_finish,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_setBindGroup = &call_setBindGroup,
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
        GPURenderBundleEncoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPURenderBundleEncoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPURenderBundleEncoderImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPURenderBundleEncoderImpl.set_label(instance, value);
    }

    pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: GPUBuffer, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_drawIndexedIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_draw(instance: *runtime.Instance, vertexCount: GPUSize32, instanceCount: GPUSize32, firstVertex: GPUSize32, firstInstance: GPUSize32) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_draw(instance, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
        return try GPURenderBundleEncoderImpl.call_popDebugGroup(instance);
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
            .GPUIndex32_GPUBindGroup?_sequence => |a| return try GPURenderBundleEncoderImpl.GPUIndex32_GPUBindGroup?_sequence(instance, a.index, a.bindGroup, a.dynamicOffsets),
            .GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32 => |a| return try GPURenderBundleEncoderImpl.GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32(instance, a.index, a.bindGroup, a.dynamicOffsetsData, a.dynamicOffsetsDataStart, a.dynamicOffsetsDataLength),
        }
    }

    pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: GPUIndex32, buffer: anyopaque, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_setVertexBuffer(instance, slot, buffer, offset, size);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_insertDebugMarker(instance, markerLabel);
    }

    pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: GPUBuffer, indexFormat: GPUIndexFormat, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_setIndexBuffer(instance, buffer, indexFormat, offset, size);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_pushDebugGroup(instance, groupLabel);
    }

    pub fn call_finish(instance: *runtime.Instance, descriptor: GPURenderBundleDescriptor) anyerror!GPURenderBundle {
        
        return try GPURenderBundleEncoderImpl.call_finish(instance, descriptor);
    }

    pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: GPUBuffer, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_drawIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: GPUSize32, instanceCount: GPUSize32, firstIndex: GPUSize32, baseVertex: GPUSignedOffset32, firstInstance: GPUSize32) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_drawIndexed(instance, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: GPURenderPipeline) anyerror!void {
        
        return try GPURenderBundleEncoderImpl.call_setPipeline(instance, pipeline);
    }

};
