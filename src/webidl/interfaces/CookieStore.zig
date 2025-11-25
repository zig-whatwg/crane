//! Generated from: cookiestore.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CookieStoreImpl = @import("impls").CookieStore;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CookieStoreGetOptions = @import("dictionaries").CookieStoreGetOptions;
const CookieStoreDeleteOptions = @import("dictionaries").CookieStoreDeleteOptions;
const USVString = @import("interfaces").USVString;
const CookieListItem = @import("dictionaries").CookieListItem;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const CookieList = @import("typedefs").CookieList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const CookieInit = @import("dictionaries").CookieInit;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const CookieStore = struct {
    pub const Meta = struct {
        pub const name = "CookieStore";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "ServiceWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .ServiceWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onchange", "get_onchange", "set_onchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
            .{ "get", "call_get", 0 },
            .{ "getAll", "call_getAll", 1 },
            .{ "getAll", "call_getAll", 0 },
            .{ "set", "call_set", 2 },
            .{ "set", "call_set", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "delete", "call_delete", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
            "get",
            "getAll",
            "getAll",
            "set",
            "set",
            "delete",
            "delete",
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
            .{ "onchange", "get_onchange", "set_onchange" },
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
            onchange: EventHandler = undefined,
            _internal: ?*CookieStoreImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onchange = &get_onchange,

        .set_onchange = &set_onchange,

        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_set = &call_set,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CookieStoreImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CookieStoreImpl.deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try CookieStoreImpl.get_onchange(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CookieStoreImpl.set_onchange(instance, value);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!*const anyopaque {
        
        return try CookieStoreImpl.call_delete(instance, name);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!*const anyopaque {
        
        return try CookieStoreImpl.call_get(instance, name);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!*const anyopaque {
        
        return try CookieStoreImpl.call_getAll(instance, name);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!*const anyopaque {
        
        return try CookieStoreImpl.call_set(instance, name, value);
    }

};
