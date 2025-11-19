//! Generated from: web-app-launch.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LaunchQueueImpl = @import("impls").LaunchQueue;
const LaunchConsumer = @import("callbacks").LaunchConsumer;

pub const LaunchQueue = struct {
    pub const Meta = struct {
        pub const name = "LaunchQueue";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LaunchQueue, .{
        .deinit_fn = &deinit_wrapper,

        .call_setConsumer = &call_setConsumer,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return LaunchQueueImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LaunchQueueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_setConsumer(instance: *runtime.Instance, consumer: LaunchConsumer) anyerror!void {
        
        return try LaunchQueueImpl.call_setConsumer(instance, consumer);
    }

};
