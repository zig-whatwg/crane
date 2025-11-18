//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerRegistrationImpl = @import("../impls/ServiceWorkerRegistration.zig");
const EventTarget = @import("EventTarget.zig");
const PushManagerAttribute = @import("PushManagerAttribute.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ServiceWorkerRegistrationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ServiceWorkerRegistrationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_installing(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_installing(state);
    }

    pub fn get_waiting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_waiting(state);
    }

    pub fn get_active(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_active(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_navigationPreload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_navigationPreload) |cached| {
            return cached;
        }
        const value = ServiceWorkerRegistrationImpl.get_navigationPreload(state);
        state.cached_navigationPreload = value;
        return value;
    }

    pub fn get_scope(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_scope(state);
    }

    pub fn get_updateViaCache(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_updateViaCache(state);
    }

    pub fn get_onupdatefound(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_onupdatefound(state);
    }

    pub fn set_onupdatefound(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerRegistrationImpl.set_onupdatefound(state, value);
    }

    pub fn get_periodicSync(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_periodicSync(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cookies(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cookies) |cached| {
            return cached;
        }
        const value = ServiceWorkerRegistrationImpl.get_cookies(state);
        state.cached_cookies = value;
        return value;
    }

    pub fn get_sync(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_sync(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_index(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_index) |cached| {
            return cached;
        }
        const value = ServiceWorkerRegistrationImpl.get_index(state);
        state.cached_index = value;
        return value;
    }

    pub fn get_backgroundFetch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_backgroundFetch(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_paymentManager(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_paymentManager) |cached| {
            return cached;
        }
        const value = ServiceWorkerRegistrationImpl.get_paymentManager(state);
        state.cached_paymentManager = value;
        return value;
    }

    pub fn get_pushManager(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerRegistrationImpl.get_pushManager(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_unregister(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ServiceWorkerRegistrationImpl.call_unregister(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ServiceWorkerRegistrationImpl.call_update(state);
    }

    pub fn call_showNotification(instance: *runtime.Instance, title: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerRegistrationImpl.call_showNotification(state, title, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerRegistrationImpl.call_when(state, type_, options);
    }

    pub fn call_getNotifications(instance: *runtime.Instance, filter: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerRegistrationImpl.call_getNotifications(state, filter);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ServiceWorkerRegistrationImpl.call_dispatchEvent(state, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerRegistrationImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerRegistrationImpl.call_removeEventListener(state, type_, callback, options);
    }

};
