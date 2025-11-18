//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUBindingCommandsMixinImpl = @import("../impls/GPUBindingCommandsMixin.zig");

pub const GPUBindingCommandsMixin = struct {
    pub const Meta = struct {
        pub const name = "GPUBindingCommandsMixin";
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

    pub const vtable = runtime.buildVTable(GPUBindingCommandsMixin, .{
        .deinit_fn = &deinit_wrapper,

        .call_setBindGroup = &call_setBindGroup,
        .call_setBindGroup = &call_setBindGroup,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUBindingCommandsMixinImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUBindingCommandsMixinImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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
            .GPUIndex32_GPUBindGroup?_sequence => |a| return GPUBindingCommandsMixinImpl.GPUIndex32_GPUBindGroup?_sequence(state, a.index, a.bindGroup, a.dynamicOffsets),
            .GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32 => |a| return GPUBindingCommandsMixinImpl.GPUIndex32_GPUBindGroup?_Uint32Array_GPUSize64_GPUSize32(state, a.index, a.bindGroup, a.dynamicOffsetsData, a.dynamicOffsetsDataStart, a.dynamicOffsetsDataLength),
        }
    }

};
