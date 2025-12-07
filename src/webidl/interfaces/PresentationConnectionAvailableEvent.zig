//! Generated from: presentation-api.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const PresentationConnectionAvailableEventImpl = @import("impls").PresentationConnectionAvailableEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const DOMString = @import("typedefs").DOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PresentationConnection = @import("interfaces").PresentationConnection;
const EventInit = @import("dictionaries").EventInit;
const PresentationConnectionAvailableEventInit = @import("dictionaries").PresentationConnectionAvailableEventInit;

pub const PresentationConnectionAvailableEvent = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnectionAvailableEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "connection", "get_connection", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "connection", "get_connection", null },
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
            connection: *runtime.Instance = undefined,
            cached_connection: ?*runtime.Instance = null,
            _internal: ?*PresentationConnectionAvailableEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_connection = &get_connection,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PresentationConnectionAvailableEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationConnectionAvailableEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PresentationConnectionAvailableEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PresentationConnectionAvailableEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_connection(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_connection) |cached| {
            return cached;
        }
        const value = try PresentationConnectionAvailableEventImpl.get_connection(instance);
        state.own.cached_connection = value;
        return value;
    }

};
