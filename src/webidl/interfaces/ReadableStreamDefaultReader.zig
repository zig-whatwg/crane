//! Generated from: streams.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamDefaultReaderImpl = @import("impls").ReadableStreamDefaultReader;
const ReadableStreamGenericReader = @import("interfaces").ReadableStreamGenericReader;
const ReadableStream = @import("interfaces").ReadableStream;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<ReadableStreamReadResult> = @import("interfaces").Promise<ReadableStreamReadResult>;

pub const ReadableStreamDefaultReader = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamDefaultReader";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            ReadableStreamGenericReader,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            closed: Promise<undefined> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableStreamDefaultReader, .{
        .deinit_fn = &deinit_wrapper,

        .get_closed = &get_closed,

        .call_cancel = &call_cancel,
        .call_read = &call_read,
        .call_releaseLock = &call_releaseLock,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ReadableStreamDefaultReaderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamDefaultReaderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, stream: ReadableStream) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ReadableStreamDefaultReaderImpl.constructor(instance, stream);
        
        return instance;
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!anyopaque {
        return try ReadableStreamDefaultReaderImpl.get_closed(instance);
    }

    pub fn call_read(instance: *runtime.Instance) anyerror!anyopaque {
        return try ReadableStreamDefaultReaderImpl.call_read(instance);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
        return try ReadableStreamDefaultReaderImpl.call_releaseLock(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try ReadableStreamDefaultReaderImpl.call_cancel(instance, reason);
    }

};
