//! Generated from: streams.idl
//! Generated at: 2025-11-23T14:26:30Z
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
const WritableStream = @import("interfaces").WritableStream;

pub const ReadableStream = struct {
    pub const Meta = struct {
        pub const name = "ReadableStream";
        pub const is_mixin = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "from", "call_from", 1 },
            .{ "cancel", "call_cancel", 0 },
            .{ "getReader", "call_getReader", 0 },
            .{ "pipeThrough", "call_pipeThrough", 1 },
            .{ "pipeTo", "call_pipeTo", 1 },
            .{ "tee", "call_tee", 0 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "from",
            "cancel",
            "getReader",
            "pipeThrough",
            "pipeTo",
            "tee",
            "forEach",
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
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "*const anyopaque",
            .key_type = null,
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
        .call_forEach = &call_forEach,
        .call_from = &call_from,
        .call_getReader = &call_getReader,
        .call_pipeThrough = &call_pipeThrough,
        .call_pipeTo = &call_pipeTo,
        .call_tee = &call_tee,
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
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, underlyingSource: *const anyopaque, strategy: QueuingStrategy) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ReadableStreamImpl.call_constructor(allocator, ctx, underlyingSource, strategy);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try ReadableStreamImpl.get_locked(instance);
    }

    pub fn call_pipeTo(instance: *runtime.Instance, destination: WritableStream, options: StreamPipeOptions) anyerror!*const anyopaque {
        
        return try ReadableStreamImpl.call_pipeTo(instance, destination, options);
    }

    pub fn call_pipeThrough(instance: *runtime.Instance, transform: ReadableWritablePair, options: StreamPipeOptions) anyerror!ReadableStream {
        
        return try ReadableStreamImpl.call_pipeThrough(instance, transform, options);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try ReadableStreamImpl.call_forEach(instance, callback);
    }

    pub fn call_from(instance: *runtime.Instance, asyncIterable: *const anyopaque) anyerror!ReadableStream {
        
        return try ReadableStreamImpl.call_from(instance, asyncIterable);
    }

    pub fn call_tee(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ReadableStreamImpl.call_tee(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: *const anyopaque) anyerror!*const anyopaque {
        
        return try ReadableStreamImpl.call_cancel(instance, reason);
    }

    pub fn call_getReader(instance: *runtime.Instance, options: ReadableStreamGetReaderOptions) anyerror!ReadableStreamReader {
        
        return try ReadableStreamImpl.call_getReader(instance, options);
    }

};
