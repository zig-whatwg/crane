//! Generated from: streams.idl
//! Generated at: 2025-11-29T11:15:57Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ReadableStreamImpl = @import("impls").ReadableStream;
const mixins = @import("mixins");
const ReadableWritablePair = @import("dictionaries").ReadableWritablePair;
const ReadableStreamGetReaderOptions = @import("dictionaries").ReadableStreamGetReaderOptions;
const StreamPipeOptions = @import("dictionaries").StreamPipeOptions;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;
const ReadableStreamIteratorOptions = @import("dictionaries").ReadableStreamIteratorOptions;
const ReadableStreamReader = @import("typedefs").ReadableStreamReader;
const WritableStream = @import("interfaces").WritableStream;

pub const ReadableStream = struct {
    pub const Meta = struct {
        pub const name = "ReadableStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "locked", "get_locked", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "cancel", "call_cancel", 0 },
            .{ "getReader", "call_getReader", 0 },
            .{ "pipeThrough", "call_pipeThrough", 1 },
            .{ "pipeTo", "call_pipeTo", 1 },
            .{ "tee", "call_tee", 0 },
            .{ "values", "call_values", 0 },
            .{ "getAsyncIterator", "call_getAsyncIterator", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "from", "call_from", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "from",
            "cancel",
            "getReader",
            "pipeThrough",
            "pipeTo",
            "tee",
            "values",
            "getAsyncIterator",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "locked", "get_locked", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
        
        /// Async iterable declaration (for Symbol.asyncIterator support)
        pub const async_iterable = .{
            .value_type = "*const anyopaque",
            .key_type = null,
            .options_type = "ReadableStreamIteratorOptions",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            locked: bool = undefined,
            _internal: ?*ReadableStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_locked = &get_locked,

        .call_cancel = &call_cancel,
        .call_getAsyncIterator = &call_getAsyncIterator,
        .call_getReader = &call_getReader,
        .call_pipeThrough = &call_pipeThrough,
        .call_pipeTo = &call_pipeTo,
        .call_tee = &call_tee,
        .call_values = &call_values,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ReadableStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ReadableStreamImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, underlyingSource: webidl.Opt(*const anyopaque), strategy: webidl.Opt(QueuingStrategy)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ReadableStreamImpl.call_constructor(allocator, ctx, underlyingSource, strategy);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try ReadableStreamImpl.get_locked(instance);
    }

    pub fn call_pipeTo(instance: *runtime.Instance, destination: *runtime.Instance, options: webidl.Opt(StreamPipeOptions)) anyerror!*const anyopaque {
        
        return try ReadableStreamImpl.call_pipeTo(instance, destination, options);
    }

    pub fn call_pipeThrough(instance: *runtime.Instance, transform: ReadableWritablePair, options: webidl.Opt(StreamPipeOptions)) anyerror!*runtime.Instance {
        
        return try ReadableStreamImpl.call_pipeThrough(instance, transform, options);
    }

    pub fn call_from(instance: *runtime.Instance, asyncIterable: *const anyopaque) anyerror!*runtime.Instance {
        
        return try ReadableStreamImpl.call_from(instance, asyncIterable);
    }

    pub fn call_tee(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ReadableStreamImpl.call_tee(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
        
        return try ReadableStreamImpl.call_cancel(instance, reason);
    }

    pub fn call_getReader(instance: *runtime.Instance, options: webidl.Opt(ReadableStreamGetReaderOptions)) anyerror!ReadableStreamReader {
        
        return try ReadableStreamImpl.call_getReader(instance, options);
    }

    pub fn call_values(instance: *runtime.Instance, options: webidl.Opt(ReadableStreamIteratorOptions)) anyerror!*const anyopaque {
        
        return try ReadableStreamImpl.call_values(instance, options);
    }

    pub fn call_getAsyncIterator(instance: *runtime.Instance, options: webidl.Opt(ReadableStreamIteratorOptions)) anyerror!*const anyopaque {
        
        return try ReadableStreamImpl.call_getAsyncIterator(instance, options);
    }

};
