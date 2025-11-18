//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUDebugCommandsMixinImpl = @import("../impls/GPUDebugCommandsMixin.zig");

pub const GPUDebugCommandsMixin = struct {
    pub const Meta = struct {
        pub const name = "GPUDebugCommandsMixin";
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

    pub const vtable = runtime.buildVTable(GPUDebugCommandsMixin, .{
        .deinit_fn = &deinit_wrapper,

        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUDebugCommandsMixinImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUDebugCommandsMixinImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPUDebugCommandsMixinImpl.call_insertDebugMarker(state, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return GPUDebugCommandsMixinImpl.call_pushDebugGroup(state, groupLabel);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUDebugCommandsMixinImpl.call_popDebugGroup(state);
    }

};
