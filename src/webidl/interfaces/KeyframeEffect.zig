//! Generated from: web-animations.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KeyframeEffectImpl = @import("impls").KeyframeEffect;
const AnimationEffect = @import("interfaces").AnimationEffect;
const Element = @import("interfaces").Element;
const IterationCompositeOperation = @import("enums").IterationCompositeOperation;
const CSSOMString = @import("typedefs").CSSOMString;
const GroupEffect = @import("interfaces").GroupEffect;
const EffectTiming = @import("dictionaries").EffectTiming;
const KeyframeEffectOptions = @import("dictionaries").KeyframeEffectOptions;
const ComputedEffectTiming = @import("dictionaries").ComputedEffectTiming;
const CompositeOperation = @import("enums").CompositeOperation;
const OptionalEffectTiming = @import("dictionaries").OptionalEffectTiming;

pub const KeyframeEffect = struct {
    pub const Meta = struct {
        pub const name = "KeyframeEffect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AnimationEffect;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "target", "get_target", "set_target" },
            .{ "pseudoElement", "get_pseudoElement", "set_pseudoElement" },
            .{ "composite", "get_composite", "set_composite" },
            .{ "iterationComposite", "get_iterationComposite", "set_iterationComposite" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getKeyframes", "call_getKeyframes", 0 },
            .{ "setKeyframes", "call_setKeyframes", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getKeyframes",
            "setKeyframes",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "getTiming",
            "getComputedTiming",
            "updateTiming",
            "before",
            "after",
            "replace",
            "remove",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "target", "get_target", "set_target" },
            .{ "pseudoElement", "get_pseudoElement", "set_pseudoElement" },
            .{ "composite", "get_composite", "set_composite" },
            .{ "iterationComposite", "get_iterationComposite", "set_iterationComposite" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            target: ?*runtime.Instance = null,
            pseudoElement: ?CSSOMString = null,
            composite: CompositeOperation = undefined,
            iterationComposite: IterationCompositeOperation = undefined,
            _internal: ?*KeyframeEffectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_composite = &get_composite,
        .get_iterationComposite = &get_iterationComposite,
        .get_pseudoElement = &get_pseudoElement,
        .get_target = &get_target,

        .set_composite = &set_composite,
        .set_iterationComposite = &set_iterationComposite,
        .set_pseudoElement = &set_pseudoElement,
        .set_target = &set_target,

        .call_getKeyframes = &call_getKeyframes,
        .call_setKeyframes = &call_setKeyframes,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return KeyframeEffectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        KeyframeEffectImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(target, keyframes, options)
        Element_object_union: struct {
            target: Element,
            keyframes: *const anyopaque,
            options: *const anyopaque,
        },
        /// constructor(source)
        KeyframeEffect: KeyframeEffect,
    };

    /// WebIDL constructor (overloaded)
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try KeyframeEffectImpl.call_constructor(allocator, ctx, args);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try KeyframeEffectImpl.get_target(instance);
    }

    pub fn set_target(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try KeyframeEffectImpl.set_target(instance, value);
    }

    pub fn get_pseudoElement(instance: *runtime.Instance) anyerror!?CSSOMString {
        return try KeyframeEffectImpl.get_pseudoElement(instance);
    }

    pub fn set_pseudoElement(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
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

    pub fn call_setKeyframes(instance: *runtime.Instance, keyframes: *const anyopaque) anyerror!void {
        
        return try KeyframeEffectImpl.call_setKeyframes(instance, keyframes);
    }

    pub fn call_getKeyframes(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try KeyframeEffectImpl.call_getKeyframes(instance);
    }

};
