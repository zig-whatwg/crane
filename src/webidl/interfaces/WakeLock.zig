//! Generated from: screen-wake-lock.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WakeLockImpl = @import("impls").WakeLock;
const WakeLockSentinel = @import("interfaces").WakeLockSentinel;
const WakeLockType = @import("enums").WakeLockType;

pub const WakeLock = struct {
    pub const Meta = struct {
        pub const name = "WakeLock";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WakeLock, .{
        .deinit_fn = &deinit_wrapper,

        .call_request = &call_request,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return WakeLockImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WakeLockImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_request(instance: *runtime.Instance, @"type": WakeLockType) anyerror!anyopaque {
        
        return try WakeLockImpl.call_request(instance, @"type");
    }

};
