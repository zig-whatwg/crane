//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUComputePassEncoderImpl = @import("../impls/GPUComputePassEncoder.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");
const GPUCommandsMixin = @import("GPUCommandsMixin.zig");
const GPUDebugCommandsMixin = @import("GPUDebugCommandsMixin.zig");
const GPUBindingCommandsMixin = @import("GPUBindingCommandsMixin.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GPUComputePassEncoderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUComputePassEncoderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPUComputePassEncoderImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPUComputePassEncoderImpl.set_label(state, value);
    }

    pub fn call_dispatchWorkgroups(instance: *runtime.Instance, workgroupCountX: anyopaque, workgroupCountY: anyopaque, workgroupCountZ: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUComputePassEncoderImpl.call_dispatchWorkgroups(state, workgroupCountX, workgroupCountY, workgroupCountZ);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUComputePassEncoderImpl.call_popDebugGroup(state);
    }

    /// Arguments for setBindGroup (WebIDL overloading)
    pub const SetBindGroupArgs = union(enum) {
        /// setBindGroup(index, bindGroup, dynamicOffsets)
        GPUIndex32_GPUBindGroup?_sequence: struct {
            index: anyopaque,
            bindGroup: anyopaque,
            dynamicOffsets: anyopaque,
        },
        /// setBindGroup(index, bindGroup, dynamicOffsetsData, dynamicOffsetsDataStart, dynamicOffsetsDataLength)
        GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32: struct {
            index: anyopaque,
            bindGroup: anyopaque,
            dynamicOffsetsData: anyopaque,
            dynamicOffsetsDataStart: anyopaque,
            dynamicOffsetsDataLength: anyopaque,
        },
    };

    pub fn call_setBindGroup(instance: *runtime.Instance, args: SetBindGroupArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .GPUIndex32_GPUBindGroup?_sequence => |a| return GPUComputePassEncoderImpl.GPUIndex32_GPUBindGroup?_sequence(state, a.index, a.bindGroup, a.dynamicOffsets),
            .GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32 => |a| return GPUComputePassEncoderImpl.GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32(state, a.index, a.bindGroup, a.dynamicOffsetsData, a.dynamicOffsetsDataStart, a.dynamicOffsetsDataLength),
        }
    }

    pub fn call_dispatchWorkgroupsIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUComputePassEncoderImpl.call_dispatchWorkgroupsIndirect(state, indirectBuffer, indirectOffset);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPUComputePassEncoderImpl.call_insertDebugMarker(state, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPUComputePassEncoderImpl.call_pushDebugGroup(state, groupLabel);
    }

    pub fn call_end(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUComputePassEncoderImpl.call_end(state);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUComputePassEncoderImpl.call_setPipeline(state, pipeline);
    }

};
