//! Generated from: requestidlecallback.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdleDeadlineImpl = @import("impls").IdleDeadline;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;

pub const IdleDeadline = struct {
    pub const Meta = struct {
        pub const name = "IdleDeadline";
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
            didTimeout: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IdleDeadline, .{
        .deinit_fn = &deinit_wrapper,

        .get_didTimeout = &get_didTimeout,

        .call_timeRemaining = &call_timeRemaining,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return IdleDeadlineImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdleDeadlineImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_didTimeout(instance: *runtime.Instance) anyerror!bool {
        return try IdleDeadlineImpl.get_didTimeout(instance);
    }

    pub fn call_timeRemaining(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try IdleDeadlineImpl.call_timeRemaining(instance);
    }

};
