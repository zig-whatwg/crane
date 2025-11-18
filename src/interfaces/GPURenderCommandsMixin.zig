//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderCommandsMixinImpl = @import("../impls/GPURenderCommandsMixin.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GPURenderCommandsMixinImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPURenderCommandsMixinImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderCommandsMixinImpl.call_drawIndexedIndirect(state, indirectBuffer, indirectOffset);
    }

    pub fn call_draw(instance: *runtime.Instance, vertexCount: anyopaque, instanceCount: anyopaque, firstVertex: anyopaque, firstInstance: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderCommandsMixinImpl.call_draw(state, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: anyopaque, buffer: anyopaque, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderCommandsMixinImpl.call_setVertexBuffer(state, slot, buffer, offset, size);
    }

    pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: anyopaque, indexFormat: anyopaque, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderCommandsMixinImpl.call_setIndexBuffer(state, buffer, indexFormat, offset, size);
    }

    pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: anyopaque, indirectOffset: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderCommandsMixinImpl.call_drawIndirect(state, indirectBuffer, indirectOffset);
    }

    pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: anyopaque, instanceCount: anyopaque, firstIndex: anyopaque, baseVertex: anyopaque, firstInstance: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderCommandsMixinImpl.call_drawIndexed(state, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPURenderCommandsMixinImpl.call_setPipeline(state, pipeline);
    }

};
