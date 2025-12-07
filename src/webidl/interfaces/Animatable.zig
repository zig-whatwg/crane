//! Generated from: web-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimatableImpl = @import("impls").Animatable;
const mixins = @import("mixins");
const Animation = @import("interfaces").Animation;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;

pub const Animatable = struct {
    pub const Meta = struct {
        pub const name = "Animatable";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "animate", "call_animate", 1 },
            .{ "getAnimations", "call_getAnimations", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "animate",
            "getAnimations",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*AnimatableImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_animate = &call_animate,
        .call_getAnimations = &call_getAnimations,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AnimatableImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimatableImpl.deinit(instance);
    }

    pub fn call_animate(instance: *runtime.Instance, keyframes: ?runtime.JSValue, options: webidl.Opt(*const anyopaque)) anyerror!*runtime.Instance {
        
        return try AnimatableImpl.call_animate(instance, keyframes, options);
    }

    pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(GetAnimationsOptions)) anyerror!*const anyopaque {
        
        return try AnimatableImpl.call_getAnimations(instance, options);
    }

};
