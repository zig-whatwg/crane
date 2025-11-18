//! Generated from: orientation-event.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeviceMotionEventRotationRateImpl = @import("../impls/DeviceMotionEventRotationRate.zig");

pub const DeviceMotionEventRotationRate = struct {
    pub const Meta = struct {
        pub const name = "DeviceMotionEventRotationRate";
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
            alpha: ?f64 = null,
            beta: ?f64 = null,
            gamma: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DeviceMotionEventRotationRate, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_beta = &get_beta,
        .get_gamma = &get_gamma,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DeviceMotionEventRotationRateImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DeviceMotionEventRotationRateImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventRotationRateImpl.get_alpha(state);
    }

    pub fn get_beta(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventRotationRateImpl.get_beta(state);
    }

    pub fn get_gamma(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DeviceMotionEventRotationRateImpl.get_gamma(state);
    }

};
