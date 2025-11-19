//! Generated from: css-animation-worklet.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkletAnimationEffectImpl = @import("impls").WorkletAnimationEffect;
const ComputedEffectTiming = @import("dictionaries").ComputedEffectTiming;
const EffectTiming = @import("dictionaries").EffectTiming;

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
        return WorkletAnimationEffectImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkletAnimationEffectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_localTime(instance: *runtime.Instance) anyerror!f64 {
        return try WorkletAnimationEffectImpl.get_localTime(instance);
    }

    pub fn set_localTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try WorkletAnimationEffectImpl.set_localTime(instance, value);
    }

    pub fn call_getTiming(instance: *runtime.Instance) anyerror!EffectTiming {
        return try WorkletAnimationEffectImpl.call_getTiming(instance);
    }

    pub fn call_getComputedTiming(instance: *runtime.Instance) anyerror!ComputedEffectTiming {
        return try WorkletAnimationEffectImpl.call_getComputedTiming(instance);
    }

};
