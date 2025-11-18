//! Generated from: webtransport.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportImpl = @import("impls").WebTransport;
const Promise<WebTransportConnectionStats> = @import("interfaces").Promise<WebTransportConnectionStats>;
const WebTransportDatagramDuplexStream = @import("interfaces").WebTransportDatagramDuplexStream;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const WebTransportReliabilityMode = @import("enums").WebTransportReliabilityMode;
const WebTransportOptions = @import("dictionaries").WebTransportOptions;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const unsigned short = @import("interfaces").unsigned short;
const ReadableStream = @import("interfaces").ReadableStream;
const BufferSource = @import("typedefs").BufferSource;
const WebTransportSendStreamOptions = @import("dictionaries").WebTransportSendStreamOptions;
const Promise<WebTransportCloseInfo> = @import("interfaces").Promise<WebTransportCloseInfo>;
const Promise<WebTransportSendStream> = @import("interfaces").Promise<WebTransportSendStream>;
const WebTransportCloseInfo = @import("dictionaries").WebTransportCloseInfo;
const Promise<WebTransportBidirectionalStream> = @import("interfaces").Promise<WebTransportBidirectionalStream>;
const WebTransportCongestionControl = @import("enums").WebTransportCongestionControl;
const WebTransportSendGroup = @import("interfaces").WebTransportSendGroup;

pub const WebTransport = struct {
    pub const Meta = struct {
        pub const name = "WebTransport";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            ready: Promise<undefined> = undefined,
            reliability: WebTransportReliabilityMode = undefined,
            congestionControl: WebTransportCongestionControl = undefined,
            anticipatedConcurrentIncomingUnidirectionalStreams: ?u16 = null,
            anticipatedConcurrentIncomingBidirectionalStreams: ?u16 = null,
            protocol: runtime.DOMString = undefined,
            closed: Promise<WebTransportCloseInfo> = undefined,
            draining: Promise<undefined> = undefined,
            datagrams: WebTransportDatagramDuplexStream = undefined,
            incomingBidirectionalStreams: ReadableStream = undefined,
            incomingUnidirectionalStreams: ReadableStream = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebTransport, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebTransportImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString, options: WebTransportOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try WebTransportImpl.constructor(instance, url, options);
        
        return instance;
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportImpl.get_ready(instance);
    }

    pub fn get_reliability(instance: *runtime.Instance) anyerror!WebTransportReliabilityMode {
        return try WebTransportImpl.get_reliability(instance);
    }

    pub fn get_congestionControl(instance: *runtime.Instance) anyerror!WebTransportCongestionControl {
        return try WebTransportImpl.get_congestionControl(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportImpl.get_anticipatedConcurrentIncomingUnidirectionalStreams(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try WebTransportImpl.set_anticipatedConcurrentIncomingUnidirectionalStreams(instance, value);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportImpl.get_anticipatedConcurrentIncomingBidirectionalStreams(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try WebTransportImpl.set_anticipatedConcurrentIncomingBidirectionalStreams(instance, value);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!DOMString {
        return try WebTransportImpl.get_protocol(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportImpl.get_closed(instance);
    }

    pub fn get_draining(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportImpl.get_draining(instance);
    }

    pub fn get_datagrams(instance: *runtime.Instance) anyerror!WebTransportDatagramDuplexStream {
        return try WebTransportImpl.get_datagrams(instance);
    }

    pub fn get_incomingBidirectionalStreams(instance: *runtime.Instance) anyerror!ReadableStream {
        return try WebTransportImpl.get_incomingBidirectionalStreams(instance);
    }

    pub fn get_incomingUnidirectionalStreams(instance: *runtime.Instance) anyerror!ReadableStream {
        return try WebTransportImpl.get_incomingUnidirectionalStreams(instance);
    }

    pub fn get_supportsReliableOnly(instance: *runtime.Instance) anyerror!bool {
        return try WebTransportImpl.get_supportsReliableOnly(instance);
    }

    pub fn call_createSendGroup(instance: *runtime.Instance) anyerror!WebTransportSendGroup {
        return try WebTransportImpl.call_createSendGroup(instance);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportImpl.call_getStats(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_exportKeyingMaterial(instance: *runtime.Instance, label: BufferSource, context: BufferSource) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try WebTransportImpl.call_exportKeyingMaterial(instance, label, context);
    }

    pub fn call_close(instance: *runtime.Instance, closeInfo: WebTransportCloseInfo) anyerror!void {
        
        return try WebTransportImpl.call_close(instance, closeInfo);
    }

    pub fn call_createBidirectionalStream(instance: *runtime.Instance, options: WebTransportSendStreamOptions) anyerror!anyopaque {
        
        return try WebTransportImpl.call_createBidirectionalStream(instance, options);
    }

    pub fn call_createUnidirectionalStream(instance: *runtime.Instance, options: WebTransportSendStreamOptions) anyerror!anyopaque {
        
        return try WebTransportImpl.call_createUnidirectionalStream(instance, options);
    }

};
