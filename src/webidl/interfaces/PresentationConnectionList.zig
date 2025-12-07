//! Generated from: presentation-api.idl
//! Generated at: 2025-12-07T20:02:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const PresentationConnectionListImpl = @import("impls").PresentationConnectionList;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const PresentationConnection = @import("interfaces").PresentationConnection;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const PresentationConnectionList = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnectionList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "connections", "get_connections", null },
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "connections", "get_connections", null },
            .{ "onconnectionavailable", "get_onconnectionavailable", "set_onconnectionavailable" },
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
            connections: runtime.FrozenArray(PresentationConnection) = undefined,
            onconnectionavailable: EventHandler = undefined,
            _internal: ?*PresentationConnectionListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_connections = &get_connections,
        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PresentationConnectionListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationConnectionListImpl.deinit(instance);
    }

    pub fn get_connections(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PresentationConnectionListImpl.get_connections(instance);
    }

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionListImpl.get_onconnectionavailable(instance);
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionListImpl.set_onconnectionavailable(instance, value);
    }

};
