//! Generated from: webgpu.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUBindingCommandsMixinImpl = @import("impls").GPUBindingCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const Uint32Array = @import("interfaces").Uint32Array;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPUSize32 = @import("typedefs").GPUSize32;

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return GPUBindingCommandsMixinImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUBindingCommandsMixinImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_setBindGroup(instance: *runtime.Instance, index: GPUIndex32, bindGroup: GPUBindGroup, dynamicOffsets: anyopaque) anyerror!void {
        
        return try GPUBindingCommandsMixinImpl.call_setBindGroup(instance, index, bindGroup, dynamicOffsets);
    }

};
