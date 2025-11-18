//! Generated from: gamepad.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadHapticActuatorImpl = @import("impls").GamepadHapticActuator;
const Promise<GamepadHapticsResult> = @import("interfaces").Promise<GamepadHapticsResult>;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const GamepadHapticEffectType = @import("enums").GamepadHapticEffectType;
const FrozenArray<GamepadHapticEffectType> = @import("interfaces").FrozenArray<GamepadHapticEffectType>;
const GamepadEffectParameters = @import("dictionaries").GamepadEffectParameters;

pub const GamepadHapticActuator = struct {
    pub const Meta = struct {
        pub const name = "GamepadHapticActuator";
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
            effects: FrozenArray<GamepadHapticEffectType> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GamepadHapticActuator, .{
        .deinit_fn = &deinit_wrapper,

        .get_effects = &get_effects,

        .call_playEffect = &call_playEffect,
        .call_pulse = &call_pulse,
        .call_reset = &call_reset,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GamepadHapticActuatorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadHapticActuatorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_effects(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_effects) |cached| {
            return cached;
        }
        const value = try GamepadHapticActuatorImpl.get_effects(instance);
        state.cached_effects = value;
        return value;
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadHapticActuatorImpl.call_reset(instance);
    }

    pub fn call_pulse(instance: *runtime.Instance, value: f64, duration: f64) anyerror!anyopaque {
        
        return try GamepadHapticActuatorImpl.call_pulse(instance, value, duration);
    }

    pub fn call_playEffect(instance: *runtime.Instance, type_: GamepadHapticEffectType, params: GamepadEffectParameters) anyerror!anyopaque {
        
        return try GamepadHapticActuatorImpl.call_playEffect(instance, type_, params);
    }

};
