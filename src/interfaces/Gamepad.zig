//! Generated from: gamepad.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadImpl = @import("../impls/Gamepad.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GamepadImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GamepadImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return GamepadImpl.get_id(state);
    }

    pub fn get_index(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return GamepadImpl.get_index(state);
    }

    pub fn get_connected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return GamepadImpl.get_connected(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_timestamp(state);
    }

    pub fn get_mapping(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_mapping(state);
    }

    pub fn get_axes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_axes(state);
    }

    pub fn get_buttons(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_buttons(state);
    }

    pub fn get_touches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_touches(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_vibrationActuator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_vibrationActuator) |cached| {
            return cached;
        }
        const value = GamepadImpl.get_vibrationActuator(state);
        state.cached_vibrationActuator = value;
        return value;
    }

    pub fn get_hand(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_hand(state);
    }

    pub fn get_hapticActuators(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_hapticActuators(state);
    }

    pub fn get_pose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GamepadImpl.get_pose(state);
    }

};
