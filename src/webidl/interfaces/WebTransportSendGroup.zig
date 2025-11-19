//! Generated from: webtransport.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportSendGroupImpl = @import("impls").WebTransportSendGroup;
const WebTransportSendStreamStats = @import("dictionaries").WebTransportSendStreamStats;

pub const WebTransportSendGroup = struct {
    pub const Meta = struct {
        pub const name = "WebTransportSendGroup";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebTransportSendGroup, .{
        .deinit_fn = &deinit_wrapper,

        .call_getStats = &call_getStats,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return WebTransportSendGroupImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportSendGroupImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportSendGroupImpl.call_getStats(instance);
    }

};
