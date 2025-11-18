//! Generated from: web-animations.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KeyframeEffectImpl = @import("../impls/KeyframeEffect.zig");
const AnimationEffect = @import("AnimationEffect.zig");

pub const KeyframeEffect = struct {
    pub const Meta = struct {
        pub const name = "KeyframeEffect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AnimationEffect;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            target: ?Element = null,
            pseudoElement: ?CSSOMString = null,
            composite: CompositeOperation = undefined,
            iterationComposite: IterationCompositeOperation = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(KeyframeEffect, .{
        .deinit_fn = &deinit_wrapper,

        .get_composite = &get_composite,
        .get_iterationComposite = &get_iterationComposite,
        .get_nextSibling = &get_nextSibling,
        .get_parent = &get_parent,
        .get_previousSibling = &get_previousSibling,
        .get_pseudoElement = &get_pseudoElement,
        .get_target = &get_target,

        .set_composite = &set_composite,
        .set_iterationComposite = &set_iterationComposite,
        .set_pseudoElement = &set_pseudoElement,
        .set_target = &set_target,

        .call_after = &call_after,
        .call_before = &call_before,
        .call_getComputedTiming = &call_getComputedTiming,
        .call_getKeyframes = &call_getKeyframes,
        .call_getTiming = &call_getTiming,
        .call_remove = &call_remove,
        .call_replace = &call_replace,
        .call_setKeyframes = &call_setKeyframes,
        .call_updateTiming = &call_updateTiming,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        KeyframeEffectImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        KeyframeEffectImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, target: anyopaque, keyframes: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try KeyframeEffectImpl.constructor(state, target, keyframes, options);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, source: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try KeyframeEffectImpl.constructor(state, source);
        
        return instance;
    }

    pub fn get_parent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.get_parent(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.get_nextSibling(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.get_target(state);
    }

    pub fn set_target(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        KeyframeEffectImpl.set_target(state, value);
    }

    pub fn get_pseudoElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.get_pseudoElement(state);
    }

    pub fn set_pseudoElement(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        KeyframeEffectImpl.set_pseudoElement(state, value);
    }

    pub fn get_composite(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.get_composite(state);
    }

    pub fn set_composite(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        KeyframeEffectImpl.set_composite(state, value);
    }

    pub fn get_iterationComposite(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.get_iterationComposite(state);
    }

    pub fn set_iterationComposite(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        KeyframeEffectImpl.set_iterationComposite(state, value);
    }

    pub fn call_updateTiming(instance: *runtime.Instance, timing: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyframeEffectImpl.call_updateTiming(state, timing);
    }

    pub fn call_replace(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyframeEffectImpl.call_replace(state, effects);
    }

    pub fn call_before(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyframeEffectImpl.call_before(state, effects);
    }

    pub fn call_after(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyframeEffectImpl.call_after(state, effects);
    }

    pub fn call_remove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.call_remove(state);
    }

    pub fn call_getTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.call_getTiming(state);
    }

    pub fn call_getComputedTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.call_getComputedTiming(state);
    }

    pub fn call_getKeyframes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyframeEffectImpl.call_getKeyframes(state);
    }

    pub fn call_setKeyframes(instance: *runtime.Instance, keyframes: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyframeEffectImpl.call_setKeyframes(state, keyframes);
    }

};
