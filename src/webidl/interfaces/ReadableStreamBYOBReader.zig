//! Generated from: streams.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamBYOBReaderImpl = @import("impls").ReadableStreamBYOBReader;
const ReadableStreamGenericReader = @import("interfaces").ReadableStreamGenericReader;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const ReadableStream = @import("interfaces").ReadableStream;
const ReadableStreamBYOBReaderReadOptions = @import("dictionaries").ReadableStreamBYOBReaderReadOptions;
const ReadableStreamReadResult = @import("dictionaries").ReadableStreamReadResult;

pub const ReadableStreamBYOBReader = struct {
    pub const Meta = struct {
        pub const name = "ReadableStreamBYOBReader";
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
            closed: runtime.Promise(undefined) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableStreamBYOBReader, .{
        .deinit_fn = &deinit_wrapper,

        .get_closed = &get_closed,

        .call_cancel = &call_cancel,
        .call_read = &call_read,
        .call_releaseLock = &call_releaseLock,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ReadableStreamBYOBReaderImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamBYOBReaderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, stream: ReadableStream) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ReadableStreamBYOBReaderImpl.constructor(instance, stream);
        
        return instance;
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!anyopaque {
        return try ReadableStreamBYOBReaderImpl.get_closed(instance);
    }

    pub fn call_read(instance: *runtime.Instance, view: ArrayBufferView, options: ReadableStreamBYOBReaderReadOptions) anyerror!anyopaque {
        
        return try ReadableStreamBYOBReaderImpl.call_read(instance, view, options);
    }

    pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
        return try ReadableStreamBYOBReaderImpl.call_releaseLock(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try ReadableStreamBYOBReaderImpl.call_cancel(instance, reason);
    }

};
