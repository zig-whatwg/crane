//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderBundleEncoderImpl = @import("../impls/GPURenderBundleEncoder.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");
const GPUCommandsMixin = @import("GPUCommandsMixin.zig");
const GPUDebugCommandsMixin = @import("GPUDebugCommandsMixin.zig");
const GPUBindingCommandsMixin = @import("GPUBindingCommandsMixin.zig");
const GPURenderCommandsMixin = @import("GPURenderCommandsMixin.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GPURenderBundleEncoderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPURenderBundleEncoderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPURenderBundleEncoderImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPURenderBundleEncoderImpl.set_label(state, value);
    }

    pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_drawIndexedIndirect(state, indirectBuffer, indirectOffset);
    }

    pub fn call_draw(instance: *runtime.Instance, vertexCount: anyopaque, instanceCount: anyopaque, firstVertex: anyopaque, firstInstance: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_draw(state, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPURenderBundleEncoderImpl.call_popDebugGroup(state);
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
            .GPUIndex32_GPUBindGroup?_sequence => |a| return GPURenderBundleEncoderImpl.GPUIndex32_GPUBindGroup?_sequence(state, a.index, a.bindGroup, a.dynamicOffsets),
            .GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32 => |a| return GPURenderBundleEncoderImpl.GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32(state, a.index, a.bindGroup, a.dynamicOffsetsData, a.dynamicOffsetsDataStart, a.dynamicOffsetsDataLength),
        }
    }

    pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: anyopaque, buffer: anyopaque, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_setVertexBuffer(state, slot, buffer, offset, size);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_insertDebugMarker(state, markerLabel);
    }

    pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: anyopaque, indexFormat: anyopaque, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_setIndexBuffer(state, buffer, indexFormat, offset, size);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_pushDebugGroup(state, groupLabel);
    }

    pub fn call_finish(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_finish(state, descriptor);
    }

    pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_drawIndirect(state, indirectBuffer, indirectOffset);
    }

    pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: anyopaque, instanceCount: anyopaque, firstIndex: anyopaque, baseVertex: anyopaque, firstInstance: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_drawIndexed(state, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderBundleEncoderImpl.call_setPipeline(state, pipeline);
    }

};
