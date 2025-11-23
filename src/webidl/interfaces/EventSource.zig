//! Generated from: html.idl
//! Generated at: 2025-11-23T19:17:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EventSourceImpl = @import("impls").EventSource;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventSourceInit = @import("dictionaries").EventSourceInit;
const EventListener = @import("interfaces").EventListener;
const USVString = @import("interfaces").USVString;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const EventSource = struct {
    pub const Meta = struct {
        pub const name = "EventSource";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "url", "get_url", null },
            .{ "withCredentials", "get_withCredentials", null },
            .{ "readyState", "get_readyState", null },
            .{ "onopen", "get_onopen", "set_onopen" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "CONNECTING", "get_CONNECTING" },
            .{ "OPEN", "get_OPEN" },
            .{ "CLOSED", "get_CLOSED" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
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
            .{ "url", "get_url", null },
            .{ "withCredentials", "get_withCredentials", null },
            .{ "readyState", "get_readyState", null },
            .{ "onopen", "get_onopen", "set_onopen" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onerror", "get_onerror", "set_onerror" },
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
            url: runtime.USVString = undefined,
            withCredentials: bool = undefined,
            readyState: u16 = undefined,
            onopen: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onerror: EventHandler = undefined,
            _internal: ?*EventSourceImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short CONNECTING = 0;
    pub fn get_CONNECTING() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short OPEN = 1;
    pub fn get_OPEN() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CLOSED = 2;
    pub fn get_CLOSED() u16 {
        return 2;
    }

    const delegates = .{

        .get_CLOSED = &get_CLOSED,
        .get_CONNECTING = &get_CONNECTING,
        .get_OPEN = &get_OPEN,
        .get_onerror = &get_onerror,
        .get_onmessage = &get_onmessage,
        .get_onopen = &get_onopen,
        .get_readyState = &get_readyState,
        .get_url = &get_url,
        .get_withCredentials = &get_withCredentials,

        .set_onerror = &set_onerror,
        .set_onmessage = &set_onmessage,
        .set_onopen = &set_onopen,

        .call_close = &call_close,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EventSourceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EventSourceImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, url: runtime.USVString, eventSourceInitDict: EventSourceInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EventSourceImpl.call_constructor(allocator, ctx, url, eventSourceInitDict);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try EventSourceImpl.get_url(instance);
    }

    pub fn get_withCredentials(instance: *runtime.Instance) anyerror!bool {
        return try EventSourceImpl.get_withCredentials(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
        return try EventSourceImpl.get_readyState(instance);
    }

    pub fn get_onopen(instance: *runtime.Instance) anyerror!EventHandler {
        return try EventSourceImpl.get_onopen(instance);
    }

    pub fn set_onopen(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EventSourceImpl.set_onopen(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try EventSourceImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EventSourceImpl.set_onmessage(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try EventSourceImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EventSourceImpl.set_onerror(instance, value);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try EventSourceImpl.call_close(instance);
    }

};
