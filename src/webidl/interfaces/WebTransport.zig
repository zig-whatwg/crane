//! Generated from: webtransport.idl
//! Generated at: 2025-11-23T20:06:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportImpl = @import("impls").WebTransport;
const DOMString = @import("typedefs").DOMString;
const WebTransportConnectionStats = @import("dictionaries").WebTransportConnectionStats;
const WebTransportSendStream = @import("interfaces").WebTransportSendStream;
const WebTransportDatagramDuplexStream = @import("interfaces").WebTransportDatagramDuplexStream;
const WebTransportReliabilityMode = @import("enums").WebTransportReliabilityMode;
const USVString = @import("interfaces").USVString;
const WebTransportOptions = @import("dictionaries").WebTransportOptions;
const WebTransportBidirectionalStream = @import("interfaces").WebTransportBidirectionalStream;
const ReadableStream = @import("interfaces").ReadableStream;
const BufferSource = @import("typedefs").BufferSource;
const WebTransportSendStreamOptions = @import("dictionaries").WebTransportSendStreamOptions;
const WebTransportCloseInfo = @import("dictionaries").WebTransportCloseInfo;
const WebTransportSendGroup = @import("interfaces").WebTransportSendGroup;
const WebTransportCongestionControl = @import("enums").WebTransportCongestionControl;

pub const WebTransport = struct {
    pub const Meta = struct {
        pub const name = "WebTransport";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "ready", "get_ready", null },
            .{ "reliability", "get_reliability", null },
            .{ "congestionControl", "get_congestionControl", null },
            .{ "anticipatedConcurrentIncomingUnidirectionalStreams", "get_anticipatedConcurrentIncomingUnidirectionalStreams", "set_anticipatedConcurrentIncomingUnidirectionalStreams" },
            .{ "anticipatedConcurrentIncomingBidirectionalStreams", "get_anticipatedConcurrentIncomingBidirectionalStreams", "set_anticipatedConcurrentIncomingBidirectionalStreams" },
            .{ "protocol", "get_protocol", null },
            .{ "closed", "get_closed", null },
            .{ "draining", "get_draining", null },
            .{ "datagrams", "get_datagrams", null },
            .{ "incomingBidirectionalStreams", "get_incomingBidirectionalStreams", null },
            .{ "incomingUnidirectionalStreams", "get_incomingUnidirectionalStreams", null },
            .{ "supportsReliableOnly", "get_supportsReliableOnly", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getStats", "call_getStats", 0 },
            .{ "exportKeyingMaterial", "call_exportKeyingMaterial", 1 },
            .{ "close", "call_close", 0 },
            .{ "createBidirectionalStream", "call_createBidirectionalStream", 0 },
            .{ "createUnidirectionalStream", "call_createUnidirectionalStream", 0 },
            .{ "createSendGroup", "call_createSendGroup", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getStats",
            "exportKeyingMaterial",
            "close",
            "createBidirectionalStream",
            "createUnidirectionalStream",
            "createSendGroup",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "ready", "get_ready", null },
            .{ "reliability", "get_reliability", null },
            .{ "congestionControl", "get_congestionControl", null },
            .{ "anticipatedConcurrentIncomingUnidirectionalStreams", "get_anticipatedConcurrentIncomingUnidirectionalStreams", "set_anticipatedConcurrentIncomingUnidirectionalStreams" },
            .{ "anticipatedConcurrentIncomingBidirectionalStreams", "get_anticipatedConcurrentIncomingBidirectionalStreams", "set_anticipatedConcurrentIncomingBidirectionalStreams" },
            .{ "protocol", "get_protocol", null },
            .{ "closed", "get_closed", null },
            .{ "draining", "get_draining", null },
            .{ "datagrams", "get_datagrams", null },
            .{ "incomingBidirectionalStreams", "get_incomingBidirectionalStreams", null },
            .{ "incomingUnidirectionalStreams", "get_incomingUnidirectionalStreams", null },
            .{ "supportsReliableOnly", "get_supportsReliableOnly", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ready: runtime.Promise(void) = undefined,
            reliability: WebTransportReliabilityMode = undefined,
            congestionControl: WebTransportCongestionControl = undefined,
            anticipatedConcurrentIncomingUnidirectionalStreams: ?u16 = null,
            anticipatedConcurrentIncomingBidirectionalStreams: ?u16 = null,
            protocol: runtime.DOMString = undefined,
            closed: runtime.Promise(WebTransportCloseInfo) = undefined,
            draining: runtime.Promise(void) = undefined,
            datagrams: *runtime.Instance = undefined,
            incomingBidirectionalStreams: *runtime.Instance = undefined,
            incomingUnidirectionalStreams: *runtime.Instance = undefined,
            _internal: ?*WebTransportImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_anticipatedConcurrentIncomingBidirectionalStreams = &get_anticipatedConcurrentIncomingBidirectionalStreams,
        .get_anticipatedConcurrentIncomingUnidirectionalStreams = &get_anticipatedConcurrentIncomingUnidirectionalStreams,
        .get_closed = &get_closed,
        .get_congestionControl = &get_congestionControl,
        .get_datagrams = &get_datagrams,
        .get_draining = &get_draining,
        .get_incomingBidirectionalStreams = &get_incomingBidirectionalStreams,
        .get_incomingUnidirectionalStreams = &get_incomingUnidirectionalStreams,
        .get_protocol = &get_protocol,
        .get_ready = &get_ready,
        .get_reliability = &get_reliability,
        .get_supportsReliableOnly = &get_supportsReliableOnly,

        .set_anticipatedConcurrentIncomingBidirectionalStreams = &set_anticipatedConcurrentIncomingBidirectionalStreams,
        .set_anticipatedConcurrentIncomingUnidirectionalStreams = &set_anticipatedConcurrentIncomingUnidirectionalStreams,

        .call_close = &call_close,
        .call_createBidirectionalStream = &call_createBidirectionalStream,
        .call_createSendGroup = &call_createSendGroup,
        .call_createUnidirectionalStream = &call_createUnidirectionalStream,
        .call_exportKeyingMaterial = &call_exportKeyingMaterial,
        .call_getStats = &call_getStats,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebTransportImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, url: runtime.USVString, options: WebTransportOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WebTransportImpl.call_constructor(allocator, ctx, url, options);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WebTransportImpl.get_ready(instance);
    }

    pub fn get_reliability(instance: *runtime.Instance) anyerror!WebTransportReliabilityMode {
        return try WebTransportImpl.get_reliability(instance);
    }

    pub fn get_congestionControl(instance: *runtime.Instance) anyerror!WebTransportCongestionControl {
        return try WebTransportImpl.get_congestionControl(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance) anyerror!u16 {
        return try WebTransportImpl.get_anticipatedConcurrentIncomingUnidirectionalStreams(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance, value: u16) anyerror!void {
        try WebTransportImpl.set_anticipatedConcurrentIncomingUnidirectionalStreams(instance, value);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance) anyerror!u16 {
        return try WebTransportImpl.get_anticipatedConcurrentIncomingBidirectionalStreams(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance, value: u16) anyerror!void {
        try WebTransportImpl.set_anticipatedConcurrentIncomingBidirectionalStreams(instance, value);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!DOMString {
        return try WebTransportImpl.get_protocol(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WebTransportImpl.get_closed(instance);
    }

    pub fn get_draining(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WebTransportImpl.get_draining(instance);
    }

    pub fn get_datagrams(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.get_datagrams(instance);
    }

    pub fn get_incomingBidirectionalStreams(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.get_incomingBidirectionalStreams(instance);
    }

    pub fn get_incomingUnidirectionalStreams(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.get_incomingUnidirectionalStreams(instance);
    }

    pub fn get_supportsReliableOnly(instance: *runtime.Instance) anyerror!bool {
        return try WebTransportImpl.get_supportsReliableOnly(instance);
    }

    pub fn call_createSendGroup(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.call_createSendGroup(instance);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WebTransportImpl.call_getStats(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_exportKeyingMaterial(instance: *runtime.Instance, label: BufferSource, context: BufferSource) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try WebTransportImpl.call_exportKeyingMaterial(instance, label, context);
    }

    pub fn call_close(instance: *runtime.Instance, closeInfo: WebTransportCloseInfo) anyerror!void {
        
        return try WebTransportImpl.call_close(instance, closeInfo);
    }

    pub fn call_createBidirectionalStream(instance: *runtime.Instance, options: WebTransportSendStreamOptions) anyerror!*const anyopaque {
        
        return try WebTransportImpl.call_createBidirectionalStream(instance, options);
    }

    pub fn call_createUnidirectionalStream(instance: *runtime.Instance, options: WebTransportSendStreamOptions) anyerror!*const anyopaque {
        
        return try WebTransportImpl.call_createUnidirectionalStream(instance, options);
    }

};
