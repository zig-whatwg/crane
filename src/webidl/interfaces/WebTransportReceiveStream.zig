//! Generated from: webtransport.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportReceiveStreamImpl = @import("impls").WebTransportReceiveStream;
const ReadableStream = @import("interfaces").ReadableStream;
const ReadableWritablePair = @import("dictionaries").ReadableWritablePair;
const ReadableStreamGetReaderOptions = @import("dictionaries").ReadableStreamGetReaderOptions;
const StreamPipeOptions = @import("dictionaries").StreamPipeOptions;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;
const ReadableStreamIteratorOptions = @import("dictionaries").ReadableStreamIteratorOptions;
const ReadableStreamReader = @import("typedefs").ReadableStreamReader;
const WebTransportReceiveStreamStats = @import("dictionaries").WebTransportReceiveStreamStats;
const WritableStream = @import("interfaces").WritableStream;

pub const WebTransportReceiveStream = struct {
    pub const Meta = struct {
        pub const name = "WebTransportReceiveStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReadableStream;
        pub const MixinTypes = &.{};
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getStats", "call_getStats", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getStats",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "from",
            "cancel",
            "getReader",
            "pipeThrough",
            "pipeTo",
            "tee",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*WebTransportReceiveStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getStats = &call_getStats,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebTransportReceiveStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportReceiveStreamImpl.deinit(instance);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WebTransportReceiveStreamImpl.call_getStats(instance);
    }

};
