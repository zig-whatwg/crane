//! Generated from: gamepad.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadHapticActuatorImpl = @import("impls").GamepadHapticActuator;
const GamepadHapticEffectType = @import("enums").GamepadHapticEffectType;
const GamepadHapticsResult = @import("enums").GamepadHapticsResult;
const GamepadEffectParameters = @import("dictionaries").GamepadEffectParameters;

pub const GamepadHapticActuator = struct {
    pub const Meta = struct {
        pub const name = "GamepadHapticActuator";
        pub const is_mixin = false;
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
            .{ "effects", "get_effects", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "playEffect", "call_playEffect", 1 },
            .{ "reset", "call_reset", 0 },
            .{ "pulse", "call_pulse", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "playEffect",
            "reset",
            "pulse",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "effects", "get_effects", null },
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
            effects: runtime.FrozenArray(GamepadHapticEffectType) = undefined,
            cached_effects: ?runtime.FrozenArray(GamepadHapticEffectType) = null,
        },
    );

    const delegates = .{

        .get_effects = &get_effects,

        .call_playEffect = &call_playEffect,
        .call_pulse = &call_pulse,
        .call_reset = &call_reset,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GamepadHapticActuatorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadHapticActuatorImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_effects(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_effects) |cached| {
            return cached;
        }
        const value = try GamepadHapticActuatorImpl.get_effects(instance);
        state.own.cached_effects = value;
        return value;
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GamepadHapticActuatorImpl.call_reset(instance);
    }

    pub fn call_pulse(instance: *runtime.Instance, value: f64, duration: f64) anyerror!*const anyopaque {
        
        return try GamepadHapticActuatorImpl.call_pulse(instance, value, duration);
    }

    pub fn call_playEffect(instance: *runtime.Instance, @"type": GamepadHapticEffectType, params: GamepadEffectParameters) anyerror!*const anyopaque {
        
        return try GamepadHapticActuatorImpl.call_playEffect(instance, @"type", params);
    }

};
