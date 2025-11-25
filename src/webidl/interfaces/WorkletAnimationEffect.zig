//! Generated from: css-animation-worklet.idl
//! Generated at: 2025-11-25T13:07:11Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "AnimationWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AnimationWorklet = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "localTime", "get_localTime", "set_localTime" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getTiming", "call_getTiming", 0 },
            .{ "getComputedTiming", "call_getComputedTiming", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTiming",
            "getComputedTiming",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "localTime", "get_localTime", "set_localTime" },
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
            localTime: ?f64 = null,
            _internal: ?*WorkletAnimationEffectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_localTime = &get_localTime,

        .set_localTime = &set_localTime,

        .call_getComputedTiming = &call_getComputedTiming,
        .call_getTiming = &call_getTiming,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkletAnimationEffectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkletAnimationEffectImpl.deinit(instance);
    }

    pub fn get_localTime(instance: *runtime.Instance) anyerror!?f64 {
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
