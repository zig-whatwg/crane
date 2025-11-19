//! Generated from: web-animations.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KeyframeEffectImpl = @import("impls").KeyframeEffect;
const AnimationEffect = @import("interfaces").AnimationEffect;
const Element = @import("interfaces").Element;
const IterationCompositeOperation = @import("enums").IterationCompositeOperation;
const CSSOMString = @import("interfaces").CSSOMString;
const GroupEffect = @import("interfaces").GroupEffect;
const EffectTiming = @import("dictionaries").EffectTiming;
const KeyframeEffectOptions = @import("dictionaries").KeyframeEffectOptions;
const ComputedEffectTiming = @import("dictionaries").ComputedEffectTiming;
const CompositeOperation = @import("enums").CompositeOperation;
const OptionalEffectTiming = @import("dictionaries").OptionalEffectTiming;

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
        return KeyframeEffectImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        KeyframeEffectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(target, keyframes, options)
        Element_object_union: struct {
            target: Element,
            keyframes: anyopaque,
            options: anyopaque,
        },
        /// constructor(source)
        KeyframeEffect: KeyframeEffect,
    };

    /// WebIDL constructor (overloaded)
    pub fn call_constructor(allocator: std.mem.Allocator, args: ConstructorArgs) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        switch (args) {
            .Element_object_union => |a| try KeyframeEffectImpl.constructor(instance, a.target, a.keyframes, a.options),
            .KeyframeEffect => |arg| try KeyframeEffectImpl.constructor(instance, arg),
        }
        
        return instance;
    }

    pub fn get_parent(instance: *runtime.Instance) anyerror!GroupEffect {
        return try KeyframeEffectImpl.get_parent(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!AnimationEffect {
        return try KeyframeEffectImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!AnimationEffect {
        return try KeyframeEffectImpl.get_nextSibling(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!Element {
        return try KeyframeEffectImpl.get_target(instance);
    }

    pub fn set_target(instance: *runtime.Instance, value: Element) anyerror!void {
        try KeyframeEffectImpl.set_target(instance, value);
    }

    pub fn get_pseudoElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try KeyframeEffectImpl.get_pseudoElement(instance);
    }

    pub fn set_pseudoElement(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try KeyframeEffectImpl.set_pseudoElement(instance, value);
    }

    pub fn get_composite(instance: *runtime.Instance) anyerror!CompositeOperation {
        return try KeyframeEffectImpl.get_composite(instance);
    }

    pub fn set_composite(instance: *runtime.Instance, value: CompositeOperation) anyerror!void {
        try KeyframeEffectImpl.set_composite(instance, value);
    }

    pub fn get_iterationComposite(instance: *runtime.Instance) anyerror!IterationCompositeOperation {
        return try KeyframeEffectImpl.get_iterationComposite(instance);
    }

    pub fn set_iterationComposite(instance: *runtime.Instance, value: IterationCompositeOperation) anyerror!void {
        try KeyframeEffectImpl.set_iterationComposite(instance, value);
    }

    pub fn call_updateTiming(instance: *runtime.Instance, timing: OptionalEffectTiming) anyerror!void {
        
        return try KeyframeEffectImpl.call_updateTiming(instance, timing);
    }

    pub fn call_replace(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try KeyframeEffectImpl.call_replace(instance, effects);
    }

    pub fn call_before(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try KeyframeEffectImpl.call_before(instance, effects);
    }

    pub fn call_after(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try KeyframeEffectImpl.call_after(instance, effects);
    }

    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        return try KeyframeEffectImpl.call_remove(instance);
    }

    pub fn call_getTiming(instance: *runtime.Instance) anyerror!EffectTiming {
        return try KeyframeEffectImpl.call_getTiming(instance);
    }

    pub fn call_getComputedTiming(instance: *runtime.Instance) anyerror!ComputedEffectTiming {
        return try KeyframeEffectImpl.call_getComputedTiming(instance);
    }

    pub fn call_getKeyframes(instance: *runtime.Instance) anyerror!anyopaque {
        return try KeyframeEffectImpl.call_getKeyframes(instance);
    }

    pub fn call_setKeyframes(instance: *runtime.Instance, keyframes: anyopaque) anyerror!void {
        
        return try KeyframeEffectImpl.call_setKeyframes(instance, keyframes);
    }

};
