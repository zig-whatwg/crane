//! Generated from: presentation-api.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationRequestImpl = @import("impls").PresentationRequest;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const PresentationAvailability = @import("interfaces").PresentationAvailability;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const PresentationConnection = @import("interfaces").PresentationConnection;
const USVString = @import("interfaces").USVString;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const PresentationRequest = struct {
    pub const Meta = struct {
        pub const name = "PresentationRequest";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "reconnect", "call_reconnect", 1 },
            .{ "getAvailability", "call_getAvailability", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "reconnect",
            "getAvailability",
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
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
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
            onconnectionavailable: EventHandler = undefined,
            _internal: ?*PresentationRequestImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

        .call_getAvailability = &call_getAvailability,
        .call_reconnect = &call_reconnect,
        .call_start = &call_start,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PresentationRequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationRequestImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, url: runtime.USVString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PresentationRequestImpl.call_constructor(allocator, ctx, url);
    }

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationRequestImpl.get_onconnectionavailable(instance);
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationRequestImpl.set_onconnectionavailable(instance, value);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PresentationRequestImpl.call_start(instance);
    }

    pub fn call_reconnect(instance: *runtime.Instance, presentationId: runtime.USVString) anyerror!*const anyopaque {
        
        return try PresentationRequestImpl.call_reconnect(instance, presentationId);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PresentationRequestImpl.call_getAvailability(instance);
    }

};
