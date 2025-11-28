//! Generated from: service-workers.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ExtendableMessageEventImpl = @import("impls").ExtendableMessageEvent;
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const ServiceWorker = @import("interfaces").ServiceWorker;
const Client = @import("interfaces").Client;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const ExtendableMessageEventInit = @import("dictionaries").ExtendableMessageEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const MessagePort = @import("interfaces").MessagePort;

pub const ExtendableMessageEvent = struct {
    pub const Meta = struct {
        pub const name = "ExtendableMessageEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", null },
            .{ "origin", "get_origin", null },
            .{ "lastEventId", "get_lastEventId", null },
            .{ "source", "get_source", null },
            .{ "ports", "get_ports", null },
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
            "waitUntil",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "data", "get_data", null },
            .{ "origin", "get_origin", null },
            .{ "lastEventId", "get_lastEventId", null },
            .{ "source", "get_source", null },
            .{ "ports", "get_ports", null },
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
            data: *const anyopaque = undefined,
            origin: runtime.USVString = undefined,
            lastEventId: runtime.DOMString = undefined,
            source: ?union(enum) {
                Client: Client,
                ServiceWorker: ServiceWorker,
                MessagePort: MessagePort,
            } = null,
            ports: runtime.FrozenArray(MessagePort) = undefined,
            cached_source: ?union(enum) {
                Client: Client,
                ServiceWorker: ServiceWorker,
                MessagePort: MessagePort,
            } = null,
            _internal: ?*ExtendableMessageEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_lastEventId = &get_lastEventId,
        .get_origin = &get_origin,
        .get_ports = &get_ports,
        .get_source = &get_source,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ExtendableMessageEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ExtendableMessageEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: ExtendableMessageEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ExtendableMessageEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ExtendableMessageEventImpl.get_data(instance);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ExtendableMessageEventImpl.get_origin(instance);
    }

    pub fn get_lastEventId(instance: *runtime.Instance) anyerror!DOMString {
        return try ExtendableMessageEventImpl.get_lastEventId(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_source(instance: *runtime.Instance) anyerror!?*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_source) |cached| {
            return cached;
        }
        const value = try ExtendableMessageEventImpl.get_source(instance);
        state.own.cached_source = value;
        return value;
    }

    pub fn get_ports(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ExtendableMessageEventImpl.get_ports(instance);
    }

};
