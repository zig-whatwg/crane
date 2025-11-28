//! Generated from: web-animations.idl
//! Generated at: 2025-11-28T18:57:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationEffectImpl = @import("impls").AnimationEffect;
const mixins = @import("mixins");
const GroupEffect = @import("interfaces").GroupEffect;
const ComputedEffectTiming = @import("dictionaries").ComputedEffectTiming;
const EffectTiming = @import("dictionaries").EffectTiming;
const OptionalEffectTiming = @import("dictionaries").OptionalEffectTiming;

pub const AnimationEffect = struct {
    pub const Meta = struct {
        pub const name = "AnimationEffect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "parent", "get_parent", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTiming", "call_getTiming", 0 },
            .{ "getComputedTiming", "call_getComputedTiming", 0 },
            .{ "updateTiming", "call_updateTiming", 0 },
            .{ "before", "call_before", 1 },
            .{ "after", "call_after", 1 },
            .{ "replace", "call_replace", 1 },
            .{ "remove", "call_remove", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTiming",
            "getComputedTiming",
            "updateTiming",
            "before",
            "after",
            "replace",
            "remove",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "parent", "get_parent", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
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
            parent: ?*runtime.Instance = null,
            previousSibling: ?*runtime.Instance = null,
            nextSibling: ?*runtime.Instance = null,
            _internal: ?*AnimationEffectImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AnimationEffectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationEffectImpl.deinit(instance);
    }

    pub fn get_parent(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationEffectImpl.get_parent(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationEffectImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try AnimationEffectImpl.get_nextSibling(instance);
    }

    pub fn call_updateTiming(instance: *runtime.Instance, timing: webidl.Opt(OptionalEffectTiming)) anyerror!void {
        
        return try AnimationEffectImpl.call_updateTiming(instance, timing);
    }

    pub fn call_replace(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        
        return try AnimationEffectImpl.call_replace(instance, effects);
    }

    pub fn call_before(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        
        return try AnimationEffectImpl.call_before(instance, effects);
    }

    pub fn call_after(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
        
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
