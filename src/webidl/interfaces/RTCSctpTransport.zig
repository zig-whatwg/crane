//! Generated from: webrtc.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCSctpTransportImpl = @import("impls").RTCSctpTransport;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const RTCSctpTransportState = @import("enums").RTCSctpTransportState;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const RTCDtlsTransport = @import("interfaces").RTCDtlsTransport;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const RTCSctpTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCSctpTransport";
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
            transport: RTCDtlsTransport = undefined,
            state: RTCSctpTransportState = undefined,
            maxMessageSize: f64 = undefined,
            maxChannels: ?u16 = null,
            onstatechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCSctpTransport, .{
        .deinit_fn = &deinit_wrapper,

        .get_maxChannels = &get_maxChannels,
        .get_maxMessageSize = &get_maxMessageSize,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_transport = &get_transport,

        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return RTCSctpTransportImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCSctpTransportImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyerror!RTCDtlsTransport {
        return try RTCSctpTransportImpl.get_transport(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RTCSctpTransportState {
        return try RTCSctpTransportImpl.get_state(instance);
    }

    pub fn get_maxMessageSize(instance: *runtime.Instance) anyerror!f64 {
        return try RTCSctpTransportImpl.get_maxMessageSize(instance);
    }

    pub fn get_maxChannels(instance: *runtime.Instance) anyerror!u16 {
        return try RTCSctpTransportImpl.get_maxChannels(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCSctpTransportImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCSctpTransportImpl.set_onstatechange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCSctpTransportImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCSctpTransportImpl.call_when(instance, @"type", options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try RTCSctpTransportImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try RTCSctpTransportImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
