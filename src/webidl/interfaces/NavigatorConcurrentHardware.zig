//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorConcurrentHardwareImpl = @import("impls").NavigatorConcurrentHardware;

pub const NavigatorConcurrentHardware = struct {
    pub const Meta = struct {
        pub const name = "NavigatorConcurrentHardware";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            hardwareConcurrency: u64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorConcurrentHardware, .{
        .deinit_fn = &deinit_wrapper,

        .get_hardwareConcurrency = &get_hardwareConcurrency,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return NavigatorConcurrentHardwareImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorConcurrentHardwareImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
        return try NavigatorConcurrentHardwareImpl.get_hardwareConcurrency(instance);
    }

};
