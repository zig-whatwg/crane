//! Generated from: webtransport.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportReceiveStreamImpl = @import("../impls/WebTransportReceiveStream.zig");
const ReadableStream = @import("ReadableStream.zig");

pub const WebTransportReceiveStream = struct {
    pub const Meta = struct {
        pub const name = "WebTransportReceiveStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReadableStream;
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebTransportReceiveStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,

        .call_cancel = &call_cancel,
        .call_from = &call_from,
        .call_getReader = &call_getReader,
        .call_getStats = &call_getStats,
        .call_pipeThrough = &call_pipeThrough,
        .call_pipeTo = &call_pipeTo,
        .call_tee = &call_tee,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WebTransportReceiveStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebTransportReceiveStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locked(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WebTransportReceiveStreamImpl.get_locked(state);
    }

    pub fn call_pipeTo(instance: *runtime.Instance, destination: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportReceiveStreamImpl.call_pipeTo(state, destination, options);
    }

    pub fn call_pipeThrough(instance: *runtime.Instance, transform: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportReceiveStreamImpl.call_pipeThrough(state, transform, options);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportReceiveStreamImpl.call_getStats(state);
    }

    pub fn call_from(instance: *runtime.Instance, asyncIterable: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportReceiveStreamImpl.call_from(state, asyncIterable);
    }

    pub fn call_tee(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportReceiveStreamImpl.call_tee(state);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportReceiveStreamImpl.call_cancel(state, reason);
    }

    pub fn call_getReader(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportReceiveStreamImpl.call_getReader(state, options);
    }

};
