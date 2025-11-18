//! Generated from: webtransport.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportSendStreamImpl = @import("../impls/WebTransportSendStream.zig");
const WritableStream = @import("WritableStream.zig");

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
        WebTransportSendStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebTransportSendStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locked(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WebTransportSendStreamImpl.get_locked(state);
    }

    pub fn get_sendGroup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportSendStreamImpl.get_sendGroup(state);
    }

    pub fn set_sendGroup(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebTransportSendStreamImpl.set_sendGroup(state, value);
    }

    pub fn get_sendOrder(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return WebTransportSendStreamImpl.get_sendOrder(state);
    }

    pub fn set_sendOrder(instance: *runtime.Instance, value: i64) void {
        const state = instance.getState(State);
        WebTransportSendStreamImpl.set_sendOrder(state, value);
    }

    /// Arguments for getWriter (WebIDL overloading)
    pub const GetWriterArgs = union(enum) {
        /// getWriter()
        no_params: void,
        /// getWriter()
        no_params: void,
    };

    pub fn call_getWriter(instance: *runtime.Instance, args: GetWriterArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return WebTransportSendStreamImpl.no_params(state),
            .no_params => return WebTransportSendStreamImpl.no_params(state),
        }
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportSendStreamImpl.call_abort(state, reason);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportSendStreamImpl.call_getStats(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportSendStreamImpl.call_close(state);
    }

};
