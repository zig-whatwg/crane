//! Generated from: orientation-event.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeviceMotionEventAccelerationImpl = @import("../impls/DeviceMotionEventAcceleration.zig");

pub const DeviceMotionEventAcceleration = struct {
    pub const Meta = struct {
        pub const name = "DeviceMotionEventAcceleration";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            x: ?f64 = null,
            y: ?f64 = null,
            z: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DeviceMotionEventAcceleration, .{
        .deinit_fn = &deinit_wrapper,

        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DeviceMotionEventAccelerationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DeviceMotionEventAccelerationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventAccelerationImpl.get_x(state);
    }

    pub fn get_y(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventAccelerationImpl.get_y(state);
    }

    pub fn get_z(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventAccelerationImpl.get_z(state);
    }

};
