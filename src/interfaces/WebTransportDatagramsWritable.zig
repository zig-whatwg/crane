//! Generated from: webtransport.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportDatagramsWritableImpl = @import("../impls/WebTransportDatagramsWritable.zig");
const WritableStream = @import("WritableStream.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        WebTransportDatagramsWritableImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebTransportDatagramsWritableImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locked(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WebTransportDatagramsWritableImpl.get_locked(state);
    }

    pub fn get_sendGroup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportDatagramsWritableImpl.get_sendGroup(state);
    }

    pub fn set_sendGroup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebTransportDatagramsWritableImpl.set_sendGroup(state, value);
    }

    pub fn get_sendOrder(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return WebTransportDatagramsWritableImpl.get_sendOrder(state);
    }

    pub fn set_sendOrder(instance: *runtime.Instance, value: i64) void {
        const state = instance.getState(State);
        WebTransportDatagramsWritableImpl.set_sendOrder(state, value);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportDatagramsWritableImpl.call_getWriter(state);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportDatagramsWritableImpl.call_abort(state, reason);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportDatagramsWritableImpl.call_close(state);
    }

};
