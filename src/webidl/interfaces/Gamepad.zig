//! Generated from: gamepad.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadImpl = @import("impls").Gamepad;
const GamepadHapticActuator = @import("interfaces").GamepadHapticActuator;
const GamepadPose = @import("interfaces").GamepadPose;
const GamepadButton = @import("interfaces").GamepadButton;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const GamepadMappingType = @import("enums").GamepadMappingType;
const GamepadHand = @import("enums").GamepadHand;
const DOMString = @import("typedefs").DOMString;
const GamepadTouch = @import("dictionaries").GamepadTouch;

pub const Gamepad = struct {
    pub const Meta = struct {
        pub const name = "Gamepad";
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
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "connected", "get_connected", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "mapping", "get_mapping", null },
            .{ "axes", "get_axes", null },
            .{ "buttons", "get_buttons", null },
            .{ "touches", "get_touches", null },
            .{ "vibrationActuator", "get_vibrationActuator", null },
            .{ "hand", "get_hand", null },
            .{ "hapticActuators", "get_hapticActuators", null },
            .{ "pose", "get_pose", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "index", "get_index", null },
            .{ "connected", "get_connected", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "mapping", "get_mapping", null },
            .{ "axes", "get_axes", null },
            .{ "buttons", "get_buttons", null },
            .{ "touches", "get_touches", null },
            .{ "vibrationActuator", "get_vibrationActuator", null },
            .{ "hand", "get_hand", null },
            .{ "hapticActuators", "get_hapticActuators", null },
            .{ "pose", "get_pose", null },
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
            id: runtime.DOMString = undefined,
            index: i32 = undefined,
            connected: bool = undefined,
            timestamp: DOMHighResTimeStamp = undefined,
            mapping: GamepadMappingType = undefined,
            axes: runtime.FrozenArray(f64) = undefined,
            buttons: runtime.FrozenArray(GamepadButton) = undefined,
            touches: runtime.FrozenArray(GamepadTouch) = undefined,
            vibrationActuator: GamepadHapticActuator = undefined,
            hand: GamepadHand = undefined,
            hapticActuators: runtime.FrozenArray(GamepadHapticActuator) = undefined,
            pose: ?GamepadPose = null,
            cached_vibrationActuator: ?GamepadHapticActuator = null,
        },
    );

    const delegates = .{

        .get_axes = &get_axes,
        .get_buttons = &get_buttons,
        .get_connected = &get_connected,
        .get_hand = &get_hand,
        .get_hapticActuators = &get_hapticActuators,
        .get_id = &get_id,
        .get_index = &get_index,
        .get_mapping = &get_mapping,
        .get_pose = &get_pose,
        .get_timestamp = &get_timestamp,
        .get_touches = &get_touches,
        .get_vibrationActuator = &get_vibrationActuator,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GamepadImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try GamepadImpl.get_id(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!i32 {
        return try GamepadImpl.get_index(instance);
    }

    pub fn get_connected(instance: *runtime.Instance) anyerror!bool {
        return try GamepadImpl.get_connected(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try GamepadImpl.get_timestamp(instance);
    }

    pub fn get_mapping(instance: *runtime.Instance) anyerror!GamepadMappingType {
        return try GamepadImpl.get_mapping(instance);
    }

    pub fn get_axes(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GamepadImpl.get_axes(instance);
    }

    pub fn get_buttons(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GamepadImpl.get_buttons(instance);
    }

    pub fn get_touches(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GamepadImpl.get_touches(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vibrationActuator(instance: *runtime.Instance) anyerror!GamepadHapticActuator {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_vibrationActuator) |cached| {
            return cached;
        }
        const value = try GamepadImpl.get_vibrationActuator(instance);
        state.own.cached_vibrationActuator = value;
        return value;
    }

    pub fn get_hand(instance: *runtime.Instance) anyerror!GamepadHand {
        return try GamepadImpl.get_hand(instance);
    }

    pub fn get_hapticActuators(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GamepadImpl.get_hapticActuators(instance);
    }

    pub fn get_pose(instance: *runtime.Instance) anyerror!GamepadPose {
        return try GamepadImpl.get_pose(instance);
    }

};
