//! Generated from: service-workers.idl
//! Generated at: 2025-11-23T20:06:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerRegistrationImpl = @import("impls").ServiceWorkerRegistration;
const EventTarget = @import("interfaces").EventTarget;
const PushManagerAttribute = @import("interfaces").PushManagerAttribute;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ContentIndex = @import("interfaces").ContentIndex;
const USVString = @import("interfaces").USVString;
const CookieStoreManager = @import("interfaces").CookieStoreManager;
const GetNotificationOptions = @import("dictionaries").GetNotificationOptions;
const PushManager = @import("interfaces").PushManager;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const SyncManager = @import("interfaces").SyncManager;
const ServiceWorker = @import("interfaces").ServiceWorker;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const PeriodicSyncManager = @import("interfaces").PeriodicSyncManager;
const ServiceWorkerUpdateViaCache = @import("enums").ServiceWorkerUpdateViaCache;
const NotificationOptions = @import("dictionaries").NotificationOptions;
const BackgroundFetchManager = @import("interfaces").BackgroundFetchManager;
const NavigationPreloadManager = @import("interfaces").NavigationPreloadManager;
const PaymentManager = @import("interfaces").PaymentManager;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const DOMString = @import("typedefs").DOMString;

pub const ServiceWorkerRegistration = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorkerRegistration";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{
            PushManagerAttribute,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "installing", "get_installing", null },
            .{ "waiting", "get_waiting", null },
            .{ "active", "get_active", null },
            .{ "navigationPreload", "get_navigationPreload", null },
            .{ "scope", "get_scope", null },
            .{ "updateViaCache", "get_updateViaCache", null },
            .{ "onupdatefound", "get_onupdatefound", "set_onupdatefound" },
            .{ "periodicSync", "get_periodicSync", null },
            .{ "cookies", "get_cookies", null },
            .{ "sync", "get_sync", null },
            .{ "index", "get_index", null },
            .{ "backgroundFetch", "get_backgroundFetch", null },
            .{ "paymentManager", "get_paymentManager", null },
            .{ "pushManager", "get_pushManager", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "update", "call_update", 0 },
            .{ "unregister", "call_unregister", 0 },
            .{ "showNotification", "call_showNotification", 1 },
            .{ "getNotifications", "call_getNotifications", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "update",
            "unregister",
            "showNotification",
            "getNotifications",
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
            .{ "installing", "get_installing", null },
            .{ "waiting", "get_waiting", null },
            .{ "active", "get_active", null },
            .{ "navigationPreload", "get_navigationPreload", null },
            .{ "scope", "get_scope", null },
            .{ "updateViaCache", "get_updateViaCache", null },
            .{ "onupdatefound", "get_onupdatefound", "set_onupdatefound" },
            .{ "periodicSync", "get_periodicSync", null },
            .{ "cookies", "get_cookies", null },
            .{ "sync", "get_sync", null },
            .{ "index", "get_index", null },
            .{ "backgroundFetch", "get_backgroundFetch", null },
            .{ "paymentManager", "get_paymentManager", null },
            .{ "pushManager", "get_pushManager", null },
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
            installing: ?*runtime.Instance = null,
            waiting: ?*runtime.Instance = null,
            active: ?*runtime.Instance = null,
            navigationPreload: *runtime.Instance = undefined,
            scope: runtime.USVString = undefined,
            updateViaCache: ServiceWorkerUpdateViaCache = undefined,
            onupdatefound: EventHandler = undefined,
            periodicSync: *runtime.Instance = undefined,
            cookies: *runtime.Instance = undefined,
            sync: *runtime.Instance = undefined,
            index: *runtime.Instance = undefined,
            backgroundFetch: *runtime.Instance = undefined,
            paymentManager: *runtime.Instance = undefined,
            pushManager: *runtime.Instance = undefined,
            cached_navigationPreload: ?*runtime.Instance = null,
            cached_cookies: ?*runtime.Instance = null,
            cached_index: ?*runtime.Instance = null,
            cached_paymentManager: ?*runtime.Instance = null,
            _internal: ?*ServiceWorkerRegistrationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_active = &get_active,
        .get_backgroundFetch = &get_backgroundFetch,
        .get_cookies = &get_cookies,
        .get_index = &get_index,
        .get_installing = &get_installing,
        .get_navigationPreload = &get_navigationPreload,
        .get_onupdatefound = &get_onupdatefound,
        .get_paymentManager = &get_paymentManager,
        .get_periodicSync = &get_periodicSync,
        .get_pushManager = &get_pushManager,
        .get_scope = &get_scope,
        .get_sync = &get_sync,
        .get_updateViaCache = &get_updateViaCache,
        .get_waiting = &get_waiting,

        .set_onupdatefound = &set_onupdatefound,

        .call_getNotifications = &call_getNotifications,
        .call_showNotification = &call_showNotification,
        .call_unregister = &call_unregister,
        .call_update = &call_update,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ServiceWorkerRegistrationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ServiceWorkerRegistrationImpl.deinit(instance);
    }

    pub fn get_installing(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_installing(instance);
    }

    pub fn get_waiting(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_waiting(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_active(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_navigationPreload(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_navigationPreload) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_navigationPreload(instance);
        state.own.cached_navigationPreload = value;
        return value;
    }

    pub fn get_scope(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ServiceWorkerRegistrationImpl.get_scope(instance);
    }

    pub fn get_updateViaCache(instance: *runtime.Instance) anyerror!ServiceWorkerUpdateViaCache {
        return try ServiceWorkerRegistrationImpl.get_updateViaCache(instance);
    }

    pub fn get_onupdatefound(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerRegistrationImpl.get_onupdatefound(instance);
    }

    pub fn set_onupdatefound(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerRegistrationImpl.set_onupdatefound(instance, value);
    }

    pub fn get_periodicSync(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_periodicSync(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cookies(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cookies) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_cookies(instance);
        state.own.cached_cookies = value;
        return value;
    }

    pub fn get_sync(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_sync(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_index(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_index) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_index(instance);
        state.own.cached_index = value;
        return value;
    }

    pub fn get_backgroundFetch(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_backgroundFetch(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_paymentManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_paymentManager) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_paymentManager(instance);
        state.own.cached_paymentManager = value;
        return value;
    }

    pub fn get_pushManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_pushManager(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_unregister(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerRegistrationImpl.call_unregister(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerRegistrationImpl.call_update(instance);
    }

    pub fn call_showNotification(instance: *runtime.Instance, title: DOMString, options: NotificationOptions) anyerror!*const anyopaque {
        
        return try ServiceWorkerRegistrationImpl.call_showNotification(instance, title, options);
    }

    pub fn call_getNotifications(instance: *runtime.Instance, filter: GetNotificationOptions) anyerror!*const anyopaque {
        
        return try ServiceWorkerRegistrationImpl.call_getNotifications(instance, filter);
    }

};
