//! Generated from: web-animations.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimatableImpl = @import("impls").Animatable;
const object = @import("interfaces").object;
const Animation = @import("interfaces").Animation;
const (unrestricted double or KeyframeAnimationOptions) = @import("interfaces").(unrestricted double or KeyframeAnimationOptions);
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AnimatableImpl.init(instance);
        
        return instance;
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
