//! Generated from: service-workers.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerRegistrationImpl = @import("impls").ServiceWorkerRegistration;
const EventTarget = @import("interfaces").EventTarget;
const PushManagerAttribute = @import("interfaces").PushManagerAttribute;
const ServiceWorker = @import("interfaces").ServiceWorker;
const PeriodicSyncManager = @import("interfaces").PeriodicSyncManager;
const ServiceWorkerUpdateViaCache = @import("enums").ServiceWorkerUpdateViaCache;
const Promise<ServiceWorkerRegistration> = @import("interfaces").Promise<ServiceWorkerRegistration>;
const ContentIndex = @import("interfaces").ContentIndex;
const Promise<sequence<Notification>> = @import("interfaces").Promise<sequence<Notification>>;
const NotificationOptions = @import("dictionaries").NotificationOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const BackgroundFetchManager = @import("interfaces").BackgroundFetchManager;
const NavigationPreloadManager = @import("interfaces").NavigationPreloadManager;
const PaymentManager = @import("interfaces").PaymentManager;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const CookieStoreManager = @import("interfaces").CookieStoreManager;
const GetNotificationOptions = @import("dictionaries").GetNotificationOptions;
const PushManager = @import("interfaces").PushManager;
const SyncManager = @import("interfaces").SyncManager;
const EventHandler = @import("typedefs").EventHandler;

pub const ServiceWorkerRegistration = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorkerRegistration";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
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
    };

    pub const State = runtime.FlattenedState(
        struct {
            installing: ?ServiceWorker = null,
            waiting: ?ServiceWorker = null,
            active: ?ServiceWorker = null,
            navigationPreload: NavigationPreloadManager = undefined,
            scope: runtime.USVString = undefined,
            updateViaCache: ServiceWorkerUpdateViaCache = undefined,
            onupdatefound: EventHandler = undefined,
            periodicSync: PeriodicSyncManager = undefined,
            cookies: CookieStoreManager = undefined,
            sync: SyncManager = undefined,
            index: ContentIndex = undefined,
            backgroundFetch: BackgroundFetchManager = undefined,
            paymentManager: PaymentManager = undefined,
            pushManager: PushManager = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ServiceWorkerRegistration, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getNotifications = &call_getNotifications,
        .call_removeEventListener = &call_removeEventListener,
        .call_showNotification = &call_showNotification,
        .call_unregister = &call_unregister,
        .call_update = &call_update,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ServiceWorkerRegistrationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ServiceWorkerRegistrationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_installing(instance: *runtime.Instance) anyerror!anyopaque {
        return try ServiceWorkerRegistrationImpl.get_installing(instance);
    }

    pub fn get_waiting(instance: *runtime.Instance) anyerror!anyopaque {
        return try ServiceWorkerRegistrationImpl.get_waiting(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!anyopaque {
        return try ServiceWorkerRegistrationImpl.get_active(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_navigationPreload(instance: *runtime.Instance) anyerror!NavigationPreloadManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_navigationPreload) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_navigationPreload(instance);
        state.cached_navigationPreload = value;
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

    pub fn get_periodicSync(instance: *runtime.Instance) anyerror!PeriodicSyncManager {
        return try ServiceWorkerRegistrationImpl.get_periodicSync(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cookies(instance: *runtime.Instance) anyerror!CookieStoreManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cookies) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_cookies(instance);
        state.cached_cookies = value;
        return value;
    }

    pub fn get_sync(instance: *runtime.Instance) anyerror!SyncManager {
        return try ServiceWorkerRegistrationImpl.get_sync(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_index(instance: *runtime.Instance) anyerror!ContentIndex {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_index) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_index(instance);
        state.cached_index = value;
        return value;
    }

    pub fn get_backgroundFetch(instance: *runtime.Instance) anyerror!BackgroundFetchManager {
        return try ServiceWorkerRegistrationImpl.get_backgroundFetch(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_paymentManager(instance: *runtime.Instance) anyerror!PaymentManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_paymentManager) |cached| {
            return cached;
        }
        const value = try ServiceWorkerRegistrationImpl.get_paymentManager(instance);
        state.cached_paymentManager = value;
        return value;
    }

    pub fn get_pushManager(instance: *runtime.Instance) anyerror!PushManager {
        return try ServiceWorkerRegistrationImpl.get_pushManager(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_unregister(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerRegistrationImpl.call_unregister(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerRegistrationImpl.call_update(instance);
    }

    pub fn call_showNotification(instance: *runtime.Instance, title: DOMString, options: NotificationOptions) anyerror!anyopaque {
        
        return try ServiceWorkerRegistrationImpl.call_showNotification(instance, title, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ServiceWorkerRegistrationImpl.call_when(instance, type_, options);
    }

    pub fn call_getNotifications(instance: *runtime.Instance, filter: GetNotificationOptions) anyerror!anyopaque {
        
        return try ServiceWorkerRegistrationImpl.call_getNotifications(instance, filter);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ServiceWorkerRegistrationImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerRegistrationImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerRegistrationImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
