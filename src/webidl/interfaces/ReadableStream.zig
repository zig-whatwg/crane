//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamImpl = @import("impls").ReadableStream;
const ReadableWritablePair = @import("dictionaries").ReadableWritablePair;
const ReadableStreamGetReaderOptions = @import("dictionaries").ReadableStreamGetReaderOptions;
const StreamPipeOptions = @import("dictionaries").StreamPipeOptions;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;
const ReadableStreamReader = @import("typedefs").ReadableStreamReader;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const WritableStream = @import("interfaces").WritableStream;

pub const ReadableStream = struct {
    pub const Meta = struct {
        pub const name = "ReadableStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            locked: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,

        .call_cancel = &call_cancel,
        .call_from = &call_from,
        .call_getReader = &call_getReader,
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
        ReadableStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, underlyingSource: anyopaque, strategy: QueuingStrategy) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ReadableStreamImpl.constructor(instance, underlyingSource, strategy);
        
        return instance;
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try ReadableStreamImpl.get_locked(instance);
    }

    pub fn call_from(instance: *runtime.Instance, asyncIterable: anyopaque) anyerror!ReadableStream {
        
        return try ReadableStreamImpl.call_from(instance, asyncIterable);
    }

    pub fn call_pipeThrough(instance: *runtime.Instance, transform: ReadableWritablePair, options: StreamPipeOptions) anyerror!ReadableStream {
        
        return try ReadableStreamImpl.call_pipeThrough(instance, transform, options);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try ReadableStreamImpl.call_cancel(instance, reason);
    }

    pub fn call_getReader(instance: *runtime.Instance, options: ReadableStreamGetReaderOptions) anyerror!ReadableStreamReader {
        
        return try ReadableStreamImpl.call_getReader(instance, options);
    }

    pub fn call_pipeTo(instance: *runtime.Instance, destination: WritableStream, options: StreamPipeOptions) anyerror!anyopaque {
        
        return try ReadableStreamImpl.call_pipeTo(instance, destination, options);
    }

    pub fn call_tee(instance: *runtime.Instance) anyerror!anyopaque {
        return try ReadableStreamImpl.call_tee(instance);
    }

};
