//! Generated from: webtransport.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportDatagramsWritableImpl = @import("impls").WebTransportDatagramsWritable;
const WritableStream = @import("interfaces").WritableStream;
const WebTransportSendGroup = @import("interfaces").WebTransportSendGroup;

pub const WebTransportDatagramsWritable = struct {
    pub const Meta = struct {
        pub const name = "WebTransportDatagramsWritable";
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

    pub const vtable = runtime.buildVTable(WebTransportDatagramsWritable, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,
        .get_sendGroup = &get_sendGroup,
        .get_sendOrder = &get_sendOrder,

        .set_sendGroup = &set_sendGroup,
        .set_sendOrder = &set_sendOrder,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_getWriter = &call_getWriter,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebTransportDatagramsWritableImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportDatagramsWritableImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try WebTransportDatagramsWritableImpl.get_locked(instance);
    }

    pub fn get_sendGroup(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportDatagramsWritableImpl.get_sendGroup(instance);
    }

    pub fn set_sendGroup(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try WebTransportDatagramsWritableImpl.set_sendGroup(instance, value);
    }

    pub fn get_sendOrder(instance: *runtime.Instance) anyerror!i64 {
        return try WebTransportDatagramsWritableImpl.get_sendOrder(instance);
    }

    pub fn set_sendOrder(instance: *runtime.Instance, value: i64) anyerror!void {
        try WebTransportDatagramsWritableImpl.set_sendOrder(instance, value);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyerror!WritableStreamDefaultWriter {
        return try WebTransportDatagramsWritableImpl.call_getWriter(instance);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try WebTransportDatagramsWritableImpl.call_abort(instance, reason);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportDatagramsWritableImpl.call_close(instance);
    }

};
