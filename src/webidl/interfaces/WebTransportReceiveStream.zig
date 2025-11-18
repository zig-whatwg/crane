//! Generated from: webtransport.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportReceiveStreamImpl = @import("impls").WebTransportReceiveStream;
const ReadableStream = @import("interfaces").ReadableStream;
const Promise<WebTransportReceiveStreamStats> = @import("interfaces").Promise<WebTransportReceiveStreamStats>;

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
        
        // Initialize the instance (Impl receives full instance)
        WebTransportReceiveStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportReceiveStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try WebTransportReceiveStreamImpl.get_locked(instance);
    }

    pub fn call_pipeTo(instance: *runtime.Instance, destination: WritableStream, options: StreamPipeOptions) anyerror!anyopaque {
        
        return try WebTransportReceiveStreamImpl.call_pipeTo(instance, destination, options);
    }

    pub fn call_pipeThrough(instance: *runtime.Instance, transform: ReadableWritablePair, options: StreamPipeOptions) anyerror!ReadableStream {
        
        return try WebTransportReceiveStreamImpl.call_pipeThrough(instance, transform, options);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportReceiveStreamImpl.call_getStats(instance);
    }

    pub fn call_from(instance: *runtime.Instance, asyncIterable: anyopaque) anyerror!ReadableStream {
        
        return try WebTransportReceiveStreamImpl.call_from(instance, asyncIterable);
    }

    pub fn call_tee(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportReceiveStreamImpl.call_tee(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try WebTransportReceiveStreamImpl.call_cancel(instance, reason);
    }

    pub fn call_getReader(instance: *runtime.Instance, options: ReadableStreamGetReaderOptions) anyerror!ReadableStreamReader {
        
        return try WebTransportReceiveStreamImpl.call_getReader(instance, options);
    }

};
