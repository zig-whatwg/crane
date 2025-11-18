//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCDtlsTransportImpl = @import("impls").RTCDtlsTransport;
const EventTarget = @import("interfaces").EventTarget;
const RTCIceTransport = @import("interfaces").RTCIceTransport;
const RTCDtlsTransportState = @import("enums").RTCDtlsTransportState;
const EventHandler = @import("typedefs").EventHandler;

pub const RTCDtlsTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCDtlsTransport";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            iceTransport: RTCIceTransport = undefined,
            state: RTCDtlsTransportState = undefined,
            onstatechange: EventHandler = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCDtlsTransport, .{
        .deinit_fn = &deinit_wrapper,

        .get_iceTransport = &get_iceTransport,
        .get_onerror = &get_onerror,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getRemoteCertificates = &call_getRemoteCertificates,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RTCDtlsTransportImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCDtlsTransportImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_iceTransport(instance: *runtime.Instance) anyerror!RTCIceTransport {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_iceTransport) |cached| {
            return cached;
        }
        const value = try RTCDtlsTransportImpl.get_iceTransport(instance);
        state.cached_iceTransport = value;
        return value;
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RTCDtlsTransportState {
        return try RTCDtlsTransportImpl.get_state(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDtlsTransportImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDtlsTransportImpl.set_onstatechange(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDtlsTransportImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDtlsTransportImpl.set_onerror(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCDtlsTransportImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getRemoteCertificates(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCDtlsTransportImpl.call_getRemoteCertificates(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCDtlsTransportImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCDtlsTransportImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCDtlsTransportImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
