//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUDeviceLostInfoImpl = @import("../impls/GPUDeviceLostInfo.zig");

pub const GPUDeviceLostInfo = struct {
    pub const Meta = struct {
        pub const name = "GPUDeviceLostInfo";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
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
            reason: GPUDeviceLostReason = undefined,
            message: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUDeviceLostInfo, .{
        .deinit_fn = &deinit_wrapper,

        .get_message = &get_message,
        .get_reason = &get_reason,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUDeviceLostInfoImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUDeviceLostInfoImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_reason(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUDeviceLostInfoImpl.get_reason(state);
    }

    pub fn get_message(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return GPUDeviceLostInfoImpl.get_message(state);
    }

};
