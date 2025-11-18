//! Generated from: gamepad.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadImpl = @import("impls").Gamepad;
const FrozenArray<GamepadTouch> = @import("interfaces").FrozenArray<GamepadTouch>;
const GamepadHapticActuator = @import("interfaces").GamepadHapticActuator;
const FrozenArray<GamepadHapticActuator> = @import("interfaces").FrozenArray<GamepadHapticActuator>;
const GamepadPose = @import("interfaces").GamepadPose;
const FrozenArray<GamepadButton> = @import("interfaces").FrozenArray<GamepadButton>;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const GamepadMappingType = @import("enums").GamepadMappingType;
const FrozenArray<double> = @import("interfaces").FrozenArray<double>;
const GamepadHand = @import("enums").GamepadHand;

pub const Gamepad = struct {
    pub const Meta = struct {
        pub const name = "Gamepad";
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
            id: runtime.DOMString = undefined,
            index: i32 = undefined,
            connected: bool = undefined,
            timestamp: DOMHighResTimeStamp = undefined,
            mapping: GamepadMappingType = undefined,
            axes: FrozenArray<double> = undefined,
            buttons: FrozenArray<GamepadButton> = undefined,
            touches: FrozenArray<GamepadTouch> = undefined,
            vibrationActuator: GamepadHapticActuator = undefined,
            hand: GamepadHand = undefined,
            hapticActuators: FrozenArray<GamepadHapticActuator> = undefined,
            pose: ?GamepadPose = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Gamepad, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GamepadImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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

    pub fn get_axes(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadImpl.get_axes(instance);
    }

    pub fn get_buttons(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadImpl.get_buttons(instance);
    }

    pub fn get_touches(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadImpl.get_touches(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vibrationActuator(instance: *runtime.Instance) anyerror!GamepadHapticActuator {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_vibrationActuator) |cached| {
            return cached;
        }
        const value = try GamepadImpl.get_vibrationActuator(instance);
        state.cached_vibrationActuator = value;
        return value;
    }

    pub fn get_hand(instance: *runtime.Instance) anyerror!GamepadHand {
        return try GamepadImpl.get_hand(instance);
    }

    pub fn get_hapticActuators(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadImpl.get_hapticActuators(instance);
    }

    pub fn get_pose(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadImpl.get_pose(instance);
    }

};
