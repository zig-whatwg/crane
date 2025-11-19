//! Generated from: webtransport.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportSendStreamImpl = @import("impls").WebTransportSendStream;
const WritableStream = @import("interfaces").WritableStream;
const WebTransportSendStreamStats = @import("dictionaries").WebTransportSendStreamStats;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;
const WebTransportWriter = @import("interfaces").WebTransportWriter;
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const WebTransportSendGroup = @import("interfaces").WebTransportSendGroup;

pub const WebTransportSendStream = struct {
    pub const Meta = struct {
        pub const name = "WebTransportSendStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WritableStream;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sendGroup: ?WebTransportSendGroup = null,
            sendOrder: i64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebTransportSendStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,
        .get_sendGroup = &get_sendGroup,
        .get_sendOrder = &get_sendOrder,

        .set_sendGroup = &set_sendGroup,
        .set_sendOrder = &set_sendOrder,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_getStats = &call_getStats,
        .call_getWriter = &call_getWriter,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return WebTransportSendStreamImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportSendStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try WebTransportSendStreamImpl.get_locked(instance);
    }

    pub fn get_sendGroup(instance: *runtime.Instance) anyerror!WebTransportSendGroup {
        return try WebTransportSendStreamImpl.get_sendGroup(instance);
    }

    pub fn set_sendGroup(instance: *runtime.Instance, value: WebTransportSendGroup) anyerror!void {
        try WebTransportSendStreamImpl.set_sendGroup(instance, value);
    }

    pub fn get_sendOrder(instance: *runtime.Instance) anyerror!i64 {
        return try WebTransportSendStreamImpl.get_sendOrder(instance);
    }

    pub fn set_sendOrder(instance: *runtime.Instance, value: i64) anyerror!void {
        try WebTransportSendStreamImpl.set_sendOrder(instance, value);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyerror!WritableStreamDefaultWriter {
        return try WebTransportSendStreamImpl.call_getWriter(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try WebTransportSendStreamImpl.call_abort(instance, reason);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportSendStreamImpl.call_getStats(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportSendStreamImpl.call_close(instance);
    }

};
