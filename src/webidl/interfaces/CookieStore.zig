//! Generated from: cookiestore.idl
//! Generated at: 2025-11-19T20:02:02Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "ServiceWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .ServiceWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CookieStore, .{
        .deinit_fn = &deinit_wrapper,

        .get_onchange = &get_onchange,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_delete = &call_delete,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_removeEventListener = &call_removeEventListener,
        .call_set = &call_set,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CookieStoreImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CookieStoreImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try CookieStoreImpl.get_onchange(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CookieStoreImpl.set_onchange(instance, value);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!anyopaque {
        
        return try CookieStoreImpl.call_delete(instance, name);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!anyopaque {
        
        return try CookieStoreImpl.call_getAll(instance, name);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try CookieStoreImpl.call_when(instance, @"type", options);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!anyopaque {
        
        return try CookieStoreImpl.call_set(instance, name, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try CookieStoreImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!anyopaque {
        
        return try CookieStoreImpl.call_get(instance, name);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try CookieStoreImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try CookieStoreImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
