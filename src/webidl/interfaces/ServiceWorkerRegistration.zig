//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ServiceWorkerRegistrationImpl = @import("impls").ServiceWorkerRegistration;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const PushManagerAttribute = @import("mixins").PushManagerAttribute;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ContentIndex = @import("interfaces").ContentIndex;
const USVString = @import("typedefs").USVString;
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
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            PushManagerAttribute,
        };
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
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
            .{ "backgroundFetch", "get_backgroundFetch", null },
            .{ "sync", "get_sync", null },
            .{ "index", "get_index", null },
            .{ "cookies", "get_cookies", null },
            .{ "periodicSync", "get_periodicSync", null },
            .{ "paymentManager", "get_paymentManager", null },
            .{ "pushManager", "get_pushManager", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "backgroundFetch", "get_backgroundFetch", null },
            .{ "sync", "get_sync", null },
            .{ "index", "get_index", null },
            .{ "cookies", "get_cookies", null },
            .{ "periodicSync", "get_periodicSync", null },
            .{ "paymentManager", "get_paymentManager", null },
            .{ "pushManager", "get_pushManager", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "pushManager",
        };
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
            updateViaCache: enums.ServiceWorkerUpdateViaCache = undefined,
            onupdatefound: typedefs.EventHandler = undefined,
            backgroundFetch: *runtime.Instance = undefined,
            sync: *runtime.Instance = undefined,
            index: *runtime.Instance = undefined,
            cookies: *runtime.Instance = undefined,
            periodicSync: *runtime.Instance = undefined,
            paymentManager: *runtime.Instance = undefined,
            pushManager: *runtime.Instance = undefined,
            cached_navigationPreload: ?*runtime.Instance = null,
            cached_index: ?*runtime.Instance = null,
            cached_cookies: ?*runtime.Instance = null,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("ServiceWorkerRegistration has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "init") and @hasDecl(ServiceWorkerRegistrationImpl, "initOwn")) @compileError("ServiceWorkerRegistrationImpl defines both init and initOwn");
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "init")) return ServiceWorkerRegistrationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ServiceWorkerRegistrationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "init")) return false;
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "construction_args")) {
            inline for (ServiceWorkerRegistrationImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "deinit") and @hasDecl(ServiceWorkerRegistrationImpl, "deinitOwn")) @compileError("ServiceWorkerRegistrationImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "deinit")) return ServiceWorkerRegistrationImpl.deinit(instance);
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "deinitOwn")) ServiceWorkerRegistrationImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ServiceWorkerRegistration")) {
            if (comptime @hasDecl(impls.ServiceWorkerRegistration, "installHooks")) impls.ServiceWorkerRegistration.installHooks();
        }
    }

    pub fn get_installing(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_installing(instance);
    }

    pub fn get_waiting(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_waiting(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!?*runtime.Instance {
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
        @import("dom").same_object_cache.made(instance, value, "navigationPreload");
        return value;
    }

    pub fn get_scope(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ServiceWorkerRegistrationImpl.get_scope(instance);
    }

    pub fn get_updateViaCache(instance: *runtime.Instance) anyerror!ServiceWorkerUpdateViaCache {
        return try ServiceWorkerRegistrationImpl.get_updateViaCache(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onupdatefound(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "get_onupdatefound")) return try ServiceWorkerRegistrationImpl.get_onupdatefound(instance);
        return event_handlers.value(EventHandler, instance, "onupdatefound");
    }

    pub fn set_onupdatefound(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ServiceWorkerRegistrationImpl, "set_onupdatefound")) return try ServiceWorkerRegistrationImpl.set_onupdatefound(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onupdatefound", value);
    }

    pub fn get_backgroundFetch(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_backgroundFetch(instance);
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
        @import("dom").same_object_cache.made(instance, value, "index");
        return value;
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
        @import("dom").same_object_cache.made(instance, value, "cookies");
        return value;
    }

    pub fn get_periodicSync(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ServiceWorkerRegistrationImpl.get_periodicSync(instance);
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
        @import("dom").same_object_cache.made(instance, value, "paymentManager");
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub const get_pushManager = mixins.PushManagerAttribute.get_pushManager;

    /// Extended attributes: [NewObject]
    pub fn call_unregister(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerRegistrationImpl.call_unregister(instance);
    }

    pub fn call_getNotifications(instance: *runtime.Instance, filter: webidl.Opt(GetNotificationOptions)) anyerror!runtime.JSValue {
        return try ServiceWorkerRegistrationImpl.call_getNotifications(instance, filter);
    }

    /// Extended attributes: [NewObject]
    pub fn call_update(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerRegistrationImpl.call_update(instance);
    }

    pub fn call_showNotification(instance: *runtime.Instance, title: runtime.DOMString, options: webidl.Opt(NotificationOptions)) anyerror!runtime.JSValue {
        return try ServiceWorkerRegistrationImpl.call_showNotification(instance, title, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onupdatefound"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_unregister",
        "call_getNotifications",
        "call_update",
        "call_showNotification",
    };
};
