//! Generated from: webrtc.idl
//! Generated at: 2025-11-23T19:57:38Z
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
        pub const is_mixin = false;
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
            .{ "transport", "get_transport", null },
            .{ "state", "get_state", null },
            .{ "maxMessageSize", "get_maxMessageSize", null },
            .{ "maxChannels", "get_maxChannels", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "transport", "get_transport", null },
            .{ "state", "get_state", null },
            .{ "maxMessageSize", "get_maxMessageSize", null },
            .{ "maxChannels", "get_maxChannels", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
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
            transport: *runtime.Instance = undefined,
            state: RTCSctpTransportState = undefined,
            maxMessageSize: f64 = undefined,
            maxChannels: ?u16 = null,
            onstatechange: EventHandler = undefined,
            _internal: ?*RTCSctpTransportImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_maxChannels = &get_maxChannels,
        .get_maxMessageSize = &get_maxMessageSize,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_transport = &get_transport,

        .set_onstatechange = &set_onstatechange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCSctpTransportImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCSctpTransportImpl.deinit(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

};
