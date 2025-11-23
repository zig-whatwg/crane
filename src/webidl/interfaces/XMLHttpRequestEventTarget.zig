//! Generated from: xhr.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLHttpRequestEventTargetImpl = @import("impls").XMLHttpRequestEventTarget;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const XMLHttpRequestEventTarget = struct {
    pub const Meta = struct {
        pub const name = "XMLHttpRequestEventTarget";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "ontimeout", "get_ontimeout", "set_ontimeout" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
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
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "ontimeout", "get_ontimeout", "set_ontimeout" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
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
            onloadstart: EventHandler = undefined,
            onprogress: EventHandler = undefined,
            onabort: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onload: EventHandler = undefined,
            ontimeout: EventHandler = undefined,
            onloadend: EventHandler = undefined,
            _internal: ?*XMLHttpRequestEventTargetImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onload = &get_onload,
        .get_onloadend = &get_onloadend,
        .get_onloadstart = &get_onloadstart,
        .get_onprogress = &get_onprogress,
        .get_ontimeout = &get_ontimeout,

        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onload = &set_onload,
        .set_onloadend = &set_onloadend,
        .set_onloadstart = &set_onloadstart,
        .set_onprogress = &set_onprogress,
        .set_ontimeout = &set_ontimeout,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XMLHttpRequestEventTargetImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLHttpRequestEventTargetImpl.deinit(instance);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestEventTargetImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestEventTargetImpl.set_onloadstart(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestEventTargetImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestEventTargetImpl.set_onprogress(instance, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestEventTargetImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestEventTargetImpl.set_onabort(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestEventTargetImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestEventTargetImpl.set_onerror(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestEventTargetImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestEventTargetImpl.set_onload(instance, value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestEventTargetImpl.get_ontimeout(instance);
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestEventTargetImpl.set_ontimeout(instance, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestEventTargetImpl.get_onloadend(instance);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestEventTargetImpl.set_onloadend(instance, value);
    }

};
