//! Generated from: gamepad-extensions.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GamepadPoseImpl = @import("impls").GamepadPose;
const Float32Array = @import("interfaces").Float32Array;

pub const GamepadPose = struct {
    pub const Meta = struct {
        pub const name = "GamepadPose";
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
            hasOrientation: bool = undefined,
            hasPosition: bool = undefined,
            position: ?Float32Array = null,
            linearVelocity: ?Float32Array = null,
            linearAcceleration: ?Float32Array = null,
            orientation: ?Float32Array = null,
            angularVelocity: ?Float32Array = null,
            angularAcceleration: ?Float32Array = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GamepadPose, .{
        .deinit_fn = &deinit_wrapper,

        .get_angularAcceleration = &get_angularAcceleration,
        .get_angularVelocity = &get_angularVelocity,
        .get_hasOrientation = &get_hasOrientation,
        .get_hasPosition = &get_hasPosition,
        .get_linearAcceleration = &get_linearAcceleration,
        .get_linearVelocity = &get_linearVelocity,
        .get_orientation = &get_orientation,
        .get_position = &get_position,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GamepadPoseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GamepadPoseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_hasOrientation(instance: *runtime.Instance) anyerror!bool {
        return try GamepadPoseImpl.get_hasOrientation(instance);
    }

    pub fn get_hasPosition(instance: *runtime.Instance) anyerror!bool {
        return try GamepadPoseImpl.get_hasPosition(instance);
    }

    pub fn get_position(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadPoseImpl.get_position(instance);
    }

    pub fn get_linearVelocity(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadPoseImpl.get_linearVelocity(instance);
    }

    pub fn get_linearAcceleration(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadPoseImpl.get_linearAcceleration(instance);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadPoseImpl.get_orientation(instance);
    }

    pub fn get_angularVelocity(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadPoseImpl.get_angularVelocity(instance);
    }

    pub fn get_angularAcceleration(instance: *runtime.Instance) anyerror!anyopaque {
        return try GamepadPoseImpl.get_angularAcceleration(instance);
    }

};
