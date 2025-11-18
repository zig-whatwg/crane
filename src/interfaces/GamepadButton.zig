//! Generated from: gamepad.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadButtonImpl = @import("../impls/GamepadButton.zig");

pub const GamepadButton = struct {
    pub const Meta = struct {
        pub const name = "GamepadButton";
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
            pressed: bool = undefined,
            touched: bool = undefined,
            value: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GamepadButton, .{
        .deinit_fn = &deinit_wrapper,

        .get_pressed = &get_pressed,
        .get_touched = &get_touched,
        .get_value = &get_value,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GamepadButtonImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GamepadButtonImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_pressed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return GamepadButtonImpl.get_pressed(state);
    }

    pub fn get_touched(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return GamepadButtonImpl.get_touched(state);
    }

    pub fn get_value(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return GamepadButtonImpl.get_value(state);
    }

};
