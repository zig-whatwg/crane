//! Generated from: webrtc.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCDtlsTransportImpl = @import("impls").RTCDtlsTransport;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const RTCIceTransport = @import("interfaces").RTCIceTransport;
const RTCDtlsTransportState = @import("enums").RTCDtlsTransportState;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const RTCDtlsTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCDtlsTransport";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "iceTransport", "get_iceTransport", null },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRemoteCertificates", "call_getRemoteCertificates", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRemoteCertificates",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "iceTransport", "get_iceTransport", null },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "onerror", "get_onerror", "set_onerror" },
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
            iceTransport: *runtime.Instance = undefined,
            state: RTCDtlsTransportState = undefined,
            onstatechange: EventHandler = undefined,
            onerror: EventHandler = undefined,
            cached_iceTransport: ?*runtime.Instance = null,
            _internal: ?*RTCDtlsTransportImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_iceTransport = &get_iceTransport,
        .get_onerror = &get_onerror,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_onstatechange = &set_onstatechange,

        .call_getRemoteCertificates = &call_getRemoteCertificates,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCDtlsTransportImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCDtlsTransportImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_iceTransport(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_iceTransport) |cached| {
            return cached;
        }
        const value = try RTCDtlsTransportImpl.get_iceTransport(instance);
        state.own.cached_iceTransport = value;
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

    pub fn call_getRemoteCertificates(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCDtlsTransportImpl.call_getRemoteCertificates(instance);
    }

};
