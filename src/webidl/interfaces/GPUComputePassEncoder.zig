//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUComputePassEncoderImpl = @import("impls").GPUComputePassEncoder;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUCommandsMixin = @import("interfaces").GPUCommandsMixin;
const GPUDebugCommandsMixin = @import("interfaces").GPUDebugCommandsMixin;
const GPUBindingCommandsMixin = @import("interfaces").GPUBindingCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUComputePipeline = @import("interfaces").GPUComputePipeline;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const Uint32Array = @import("interfaces").Uint32Array;

pub const GPUComputePassEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPUComputePassEncoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
            GPUCommandsMixin,
            GPUDebugCommandsMixin,
            GPUBindingCommandsMixin,
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

    pub const vtable = runtime.buildVTable(GPUComputePassEncoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_dispatchWorkgroups = &call_dispatchWorkgroups,
        .call_dispatchWorkgroupsIndirect = &call_dispatchWorkgroupsIndirect,
        .call_end = &call_end,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_setBindGroup = &call_setBindGroup,
        .call_setPipeline = &call_setPipeline,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUComputePassEncoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUComputePassEncoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUComputePassEncoderImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUComputePassEncoderImpl.set_label(instance, value);
    }

    pub fn call_dispatchWorkgroups(instance: *runtime.Instance, workgroupCountX: GPUSize32, workgroupCountY: GPUSize32, workgroupCountZ: GPUSize32) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_dispatchWorkgroups(instance, workgroupCountX, workgroupCountY, workgroupCountZ);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
        return try GPUComputePassEncoderImpl.call_popDebugGroup(instance);
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
            .GPUIndex32_GPUBindGroup?_sequence => |a| return try GPUComputePassEncoderImpl.GPUIndex32_GPUBindGroup?_sequence(instance, a.index, a.bindGroup, a.dynamicOffsets),
            .GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32 => |a| return try GPUComputePassEncoderImpl.GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32(instance, a.index, a.bindGroup, a.dynamicOffsetsData, a.dynamicOffsetsDataStart, a.dynamicOffsetsDataLength),
        }
    }

    pub fn call_dispatchWorkgroupsIndirect(instance: *runtime.Instance, indirectBuffer: GPUBuffer, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_dispatchWorkgroupsIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_insertDebugMarker(instance, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_pushDebugGroup(instance, groupLabel);
    }

    pub fn call_end(instance: *runtime.Instance) anyerror!void {
        return try GPUComputePassEncoderImpl.call_end(instance);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: GPUComputePipeline) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_setPipeline(instance, pipeline);
    }

};
