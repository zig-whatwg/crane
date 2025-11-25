//! Generated from: html.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MessageEventImpl = @import("impls").MessageEvent;
const Event = @import("interfaces").Event;
const MessageEventInit = @import("dictionaries").MessageEventInit;
const EventTarget = @import("interfaces").EventTarget;
const MessageEventSource = @import("typedefs").MessageEventSource;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const MessagePort = @import("interfaces").MessagePort;

pub const MessageEvent = struct {
    pub const Meta = struct {
        pub const name = "MessageEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "AudioWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .AudioWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", null },
            .{ "origin", "get_origin", null },
            .{ "lastEventId", "get_lastEventId", null },
            .{ "source", "get_source", null },
            .{ "ports", "get_ports", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "initMessageEvent", "call_initMessageEvent", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initMessageEvent",
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
            source: ?MessageEventSource = null,
            ports: runtime.FrozenArray(MessagePort) = undefined,
            _internal: ?*MessageEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_lastEventId = &get_lastEventId,
        .get_origin = &get_origin,
        .get_ports = &get_ports,
        .get_source = &get_source,

        .call_initMessageEvent = &call_initMessageEvent,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MessageEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MessageEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: MessageEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MessageEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MessageEventImpl.get_data(instance);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try MessageEventImpl.get_origin(instance);
    }

    pub fn get_lastEventId(instance: *runtime.Instance) anyerror!DOMString {
        return try MessageEventImpl.get_lastEventId(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!?MessageEventSource {
        return try MessageEventImpl.get_source(instance);
    }

    pub fn get_ports(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MessageEventImpl.get_ports(instance);
    }

    pub fn call_initMessageEvent(instance: *runtime.Instance, @"type": DOMString, bubbles: bool, cancelable: bool, data: *const anyopaque, origin: runtime.USVString, lastEventId: DOMString, source: MessageEventSource, ports: *const anyopaque) anyerror!void {
        
        return try MessageEventImpl.call_initMessageEvent(instance, @"type", bubbles, cancelable, data, origin, lastEventId, source, ports);
    }

};
