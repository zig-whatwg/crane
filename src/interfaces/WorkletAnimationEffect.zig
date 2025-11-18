//! Generated from: css-animation-worklet.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkletAnimationEffectImpl = @import("../impls/WorkletAnimationEffect.zig");

pub const WorkletAnimationEffect = struct {
    pub const Meta = struct {
        pub const name = "WorkletAnimationEffect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "AnimationWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AnimationWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            localTime: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WorkletAnimationEffect, .{
        .deinit_fn = &deinit_wrapper,

        .get_localTime = &get_localTime,

        .set_localTime = &set_localTime,

        .call_getComputedTiming = &call_getComputedTiming,
        .call_getTiming = &call_getTiming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WorkletAnimationEffectImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WorkletAnimationEffectImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_localTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkletAnimationEffectImpl.get_localTime(state);
    }

    pub fn set_localTime(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WorkletAnimationEffectImpl.set_localTime(state, value);
    }

    pub fn call_getTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkletAnimationEffectImpl.call_getTiming(state);
    }

    pub fn call_getComputedTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkletAnimationEffectImpl.call_getComputedTiming(state);
    }

};
