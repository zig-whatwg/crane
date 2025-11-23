//! Generated from: webtransport.idl
//! Generated at: 2025-11-23T19:17:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportSendStreamImpl = @import("impls").WebTransportSendStream;
const WritableStream = @import("interfaces").WritableStream;
const WebTransportSendStreamStats = @import("dictionaries").WebTransportSendStreamStats;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;
const WebTransportWriter = @import("interfaces").WebTransportWriter;
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const WebTransportSendGroup = @import("interfaces").WebTransportSendGroup;

pub const WebTransportSendStream = struct {
    pub const Meta = struct {
        pub const name = "WebTransportSendStream";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WritableStream;
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
            .{ "sendGroup", "get_sendGroup", "set_sendGroup" },
            .{ "sendOrder", "get_sendOrder", "set_sendOrder" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getStats", "call_getStats", 0 },
            .{ "getWriter", "call_getWriter", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getStats",
            "getWriter",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "abort",
            "close",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sendGroup", "get_sendGroup", "set_sendGroup" },
            .{ "sendOrder", "get_sendOrder", "set_sendOrder" },
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
            sendGroup: ?WebTransportSendGroup = null,
            sendOrder: i64 = undefined,
            _internal: ?*WebTransportSendStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_sendGroup = &get_sendGroup,
        .get_sendOrder = &get_sendOrder,

        .set_sendGroup = &set_sendGroup,
        .set_sendOrder = &set_sendOrder,

        .call_getStats = &call_getStats,
        .call_getWriter = &call_getWriter,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebTransportSendStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportSendStreamImpl.deinit(instance);
    }

    pub fn get_sendGroup(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportSendStreamImpl.get_sendGroup(instance);
    }

    pub fn set_sendGroup(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try WebTransportSendStreamImpl.set_sendGroup(instance, value);
    }

    pub fn get_sendOrder(instance: *runtime.Instance) anyerror!i64 {
        return try WebTransportSendStreamImpl.get_sendOrder(instance);
    }

    pub fn set_sendOrder(instance: *runtime.Instance, value: i64) anyerror!void {
        try WebTransportSendStreamImpl.set_sendOrder(instance, value);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportSendStreamImpl.call_getWriter(instance);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WebTransportSendStreamImpl.call_getStats(instance);
    }

};
