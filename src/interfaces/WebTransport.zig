//! Generated from: webtransport.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportImpl = @import("../impls/WebTransport.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        WebTransportImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebTransportImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try WebTransportImpl.constructor(state, url, options);
        
        return instance;
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_ready(state);
    }

    pub fn get_reliability(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_reliability(state);
    }

    pub fn get_congestionControl(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_congestionControl(state);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_anticipatedConcurrentIncomingUnidirectionalStreams(state);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebTransportImpl.set_anticipatedConcurrentIncomingUnidirectionalStreams(state, value);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_anticipatedConcurrentIncomingBidirectionalStreams(state);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebTransportImpl.set_anticipatedConcurrentIncomingBidirectionalStreams(state, value);
    }

    pub fn get_protocol(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WebTransportImpl.get_protocol(state);
    }

    pub fn get_closed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_closed(state);
    }

    pub fn get_draining(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_draining(state);
    }

    pub fn get_datagrams(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_datagrams(state);
    }

    pub fn get_incomingBidirectionalStreams(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_incomingBidirectionalStreams(state);
    }

    pub fn get_incomingUnidirectionalStreams(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.get_incomingUnidirectionalStreams(state);
    }

    pub fn get_supportsReliableOnly(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WebTransportImpl.get_supportsReliableOnly(state);
    }

    pub fn call_createSendGroup(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.call_createSendGroup(state);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportImpl.call_getStats(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_exportKeyingMaterial(instance: *runtime.Instance, label: anyopaque, context: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return WebTransportImpl.call_exportKeyingMaterial(state, label, context);
    }

    pub fn call_close(instance: *runtime.Instance, closeInfo: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportImpl.call_close(state, closeInfo);
    }

    pub fn call_createBidirectionalStream(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportImpl.call_createBidirectionalStream(state, options);
    }

    pub fn call_createUnidirectionalStream(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportImpl.call_createUnidirectionalStream(state, options);
    }

};
