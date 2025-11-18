//! Generated from: web-animations.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationEffectImpl = @import("impls").AnimationEffect;
const GroupEffect = @import("interfaces").GroupEffect;
const ComputedEffectTiming = @import("dictionaries").ComputedEffectTiming;
const EffectTiming = @import("dictionaries").EffectTiming;
const OptionalEffectTiming = @import("dictionaries").OptionalEffectTiming;

pub const AnimationEffect = struct {
    pub const Meta = struct {
        pub const name = "AnimationEffect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            parent: ?GroupEffect = null,
            previousSibling: ?AnimationEffect = null,
            nextSibling: ?AnimationEffect = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AnimationEffect, .{
        .deinit_fn = &deinit_wrapper,

        .get_nextSibling = &get_nextSibling,
        .get_parent = &get_parent,
        .get_previousSibling = &get_previousSibling,

        .call_after = &call_after,
        .call_before = &call_before,
        .call_getComputedTiming = &call_getComputedTiming,
        .call_getTiming = &call_getTiming,
        .call_remove = &call_remove,
        .call_replace = &call_replace,
        .call_updateTiming = &call_updateTiming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AnimationEffectImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationEffectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_parent(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationEffectImpl.get_parent(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationEffectImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationEffectImpl.get_nextSibling(instance);
    }

    pub fn call_updateTiming(instance: *runtime.Instance, timing: OptionalEffectTiming) anyerror!void {
        
        return try AnimationEffectImpl.call_updateTiming(instance, timing);
    }

    pub fn call_replace(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try AnimationEffectImpl.call_replace(instance, effects);
    }

    pub fn call_before(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try AnimationEffectImpl.call_before(instance, effects);
    }

    pub fn call_after(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try AnimationEffectImpl.call_after(instance, effects);
    }

    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        return try AnimationEffectImpl.call_remove(instance);
    }

    pub fn call_getTiming(instance: *runtime.Instance) anyerror!EffectTiming {
        return try AnimationEffectImpl.call_getTiming(instance);
    }

    pub fn call_getComputedTiming(instance: *runtime.Instance) anyerror!ComputedEffectTiming {
        return try AnimationEffectImpl.call_getComputedTiming(instance);
    }

};
