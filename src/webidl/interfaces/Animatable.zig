//! Generated from: web-animations.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimatableImpl = @import("impls").Animatable;
const Animation = @import("interfaces").Animation;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;

pub const Animatable = struct {
    pub const Meta = struct {
        pub const name = "Animatable";
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

    pub const vtable = runtime.buildVTable(Animatable, .{
        .deinit_fn = &deinit_wrapper,

        .call_animate = &call_animate,
        .call_getAnimations = &call_getAnimations,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return AnimatableImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimatableImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_animate(instance: *runtime.Instance, keyframes: anyopaque, options: anyopaque) anyerror!Animation {
        
        return try AnimatableImpl.call_animate(instance, keyframes, options);
    }

    pub fn call_getAnimations(instance: *runtime.Instance, options: GetAnimationsOptions) anyerror!anyopaque {
        
        return try AnimatableImpl.call_getAnimations(instance, options);
    }

};
