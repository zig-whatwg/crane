//! Generated from: gamepad-extensions.idl
//! Generated at: 2025-12-07T19:33:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const GamepadPoseImpl = @import("impls").GamepadPose;
const mixins = @import("mixins");

pub const GamepadPose = struct {
    pub const Meta = struct {
        pub const name = "GamepadPose";
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
            .{ "hasOrientation", "get_hasOrientation", null },
            .{ "hasPosition", "get_hasPosition", null },
            .{ "position", "get_position", null },
            .{ "linearVelocity", "get_linearVelocity", null },
            .{ "linearAcceleration", "get_linearAcceleration", null },
            .{ "orientation", "get_orientation", null },
            .{ "angularVelocity", "get_angularVelocity", null },
            .{ "angularAcceleration", "get_angularAcceleration", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "hasOrientation", "get_hasOrientation", null },
            .{ "hasPosition", "get_hasPosition", null },
            .{ "position", "get_position", null },
            .{ "linearVelocity", "get_linearVelocity", null },
            .{ "linearAcceleration", "get_linearAcceleration", null },
            .{ "orientation", "get_orientation", null },
            .{ "angularVelocity", "get_angularVelocity", null },
            .{ "angularAcceleration", "get_angularAcceleration", null },
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
            hasOrientation: bool = undefined,
            hasPosition: bool = undefined,
            position: ?runtime.Float32Array = null,
            linearVelocity: ?runtime.Float32Array = null,
            linearAcceleration: ?runtime.Float32Array = null,
            orientation: ?runtime.Float32Array = null,
            angularVelocity: ?runtime.Float32Array = null,
            angularAcceleration: ?runtime.Float32Array = null,
            _internal: ?*GamepadPoseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_angularAcceleration = &get_angularAcceleration,
        .get_angularVelocity = &get_angularVelocity,
        .get_hasOrientation = &get_hasOrientation,
        .get_hasPosition = &get_hasPosition,
        .get_linearAcceleration = &get_linearAcceleration,
        .get_linearVelocity = &get_linearVelocity,
        .get_orientation = &get_orientation,
        .get_position = &get_position,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GamepadPoseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadPoseImpl.deinit(instance);
    }

    pub fn get_hasOrientation(instance: *runtime.Instance) anyerror!bool {
        return try GamepadPoseImpl.get_hasOrientation(instance);
    }

    pub fn get_hasPosition(instance: *runtime.Instance) anyerror!bool {
        return try GamepadPoseImpl.get_hasPosition(instance);
    }

    pub fn get_position(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try GamepadPoseImpl.get_position(instance);
    }

    pub fn get_linearVelocity(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try GamepadPoseImpl.get_linearVelocity(instance);
    }

    pub fn get_linearAcceleration(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try GamepadPoseImpl.get_linearAcceleration(instance);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try GamepadPoseImpl.get_orientation(instance);
    }

    pub fn get_angularVelocity(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try GamepadPoseImpl.get_angularVelocity(instance);
    }

    pub fn get_angularAcceleration(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try GamepadPoseImpl.get_angularAcceleration(instance);
    }

};
