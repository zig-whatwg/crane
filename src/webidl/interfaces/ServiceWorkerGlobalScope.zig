//! Generated from: service-workers.idl
//! Generated at: 2025-11-28T22:33:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ServiceWorkerGlobalScopeImpl = @import("impls").ServiceWorkerGlobalScope;
const mixins = @import("mixins");
const WorkerGlobalScope = @import("interfaces").WorkerGlobalScope;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ByteString = @import("interfaces").ByteString;
const FontFaceSet = @import("interfaces").FontFaceSet;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const WorkerNavigator = @import("interfaces").WorkerNavigator;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TimerHandler = @import("typedefs").TimerHandler;
const USVString = @import("interfaces").USVString;
const Scheduler = @import("interfaces").Scheduler;
const Crypto = @import("interfaces").Crypto;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ImageBitmapOptions = @import("dictionaries").ImageBitmapOptions;
const WorkerLocation = @import("interfaces").WorkerLocation;
const EventHandler = @import("typedefs").EventHandler;
const ImageBitmap = @import("interfaces").ImageBitmap;
const ServiceWorker = @import("interfaces").ServiceWorker;
const CookieStore = @import("interfaces").CookieStore;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Clients = @import("interfaces").Clients;
const VoidFunction = @import("callbacks").VoidFunction;
const Performance = @import("interfaces").Performance;
const IDBFactory = @import("interfaces").IDBFactory;
const CacheStorage = @import("interfaces").CacheStorage;
const RequestInfo = @import("typedefs").RequestInfo;
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;
const RequestInit = @import("dictionaries").RequestInit;
const Observable = @import("interfaces").Observable;
const ServiceWorkerRegistration = @import("interfaces").ServiceWorkerRegistration;
const Event = @import("interfaces").Event;
const Response = @import("interfaces").Response;
const DOMString = @import("typedefs").DOMString;

pub const ServiceWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorkerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
            .{ .name = "SecureContext" },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "ServiceWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "clients", "get_clients", null },
            .{ "registration", "get_registration", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "oninstall", "get_oninstall", "set_oninstall" },
            .{ "onactivate", "get_onactivate", "set_onactivate" },
            .{ "onfetch", "get_onfetch", "set_onfetch" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
            .{ "onperiodicsync", "get_onperiodicsync", "set_onperiodicsync" },
            .{ "cookieStore", "get_cookieStore", null },
            .{ "oncookiechange", "get_oncookiechange", "set_oncookiechange" },
            .{ "onsync", "get_onsync", "set_onsync" },
            .{ "oncontentdelete", "get_oncontentdelete", "set_oncontentdelete" },
            .{ "onbackgroundfetchsuccess", "get_onbackgroundfetchsuccess", "set_onbackgroundfetchsuccess" },
            .{ "onbackgroundfetchfail", "get_onbackgroundfetchfail", "set_onbackgroundfetchfail" },
            .{ "onbackgroundfetchabort", "get_onbackgroundfetchabort", "set_onbackgroundfetchabort" },
            .{ "onbackgroundfetchclick", "get_onbackgroundfetchclick", "set_onbackgroundfetchclick" },
            .{ "onpush", "get_onpush", "set_onpush" },
            .{ "onpushsubscriptionchange", "get_onpushsubscriptionchange", "set_onpushsubscriptionchange" },
            .{ "oncanmakepayment", "get_oncanmakepayment", "set_oncanmakepayment" },
            .{ "onpaymentrequest", "get_onpaymentrequest", "set_onpaymentrequest" },
            .{ "onnotificationclick", "get_onnotificationclick", "set_onnotificationclick" },
            .{ "onnotificationclose", "get_onnotificationclose", "set_onnotificationclose" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "skipWaiting", "call_skipWaiting", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "skipWaiting",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "importScripts",
            "reportError",
            "btoa",
            "atob",
            "setTimeout",
            "clearTimeout",
            "setInterval",
            "clearInterval",
            "queueMicrotask",
            "createImageBitmap",
            "createImageBitmap",
            "structuredClone",
            "fetch",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "clients", "get_clients", null },
            .{ "registration", "get_registration", null },
            .{ "serviceWorker", "get_serviceWorker", null },
            .{ "oninstall", "get_oninstall", "set_oninstall" },
            .{ "onactivate", "get_onactivate", "set_onactivate" },
            .{ "onfetch", "get_onfetch", "set_onfetch" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
            .{ "onperiodicsync", "get_onperiodicsync", "set_onperiodicsync" },
            .{ "cookieStore", "get_cookieStore", null },
            .{ "oncookiechange", "get_oncookiechange", "set_oncookiechange" },
            .{ "onsync", "get_onsync", "set_onsync" },
            .{ "oncontentdelete", "get_oncontentdelete", "set_oncontentdelete" },
            .{ "onbackgroundfetchsuccess", "get_onbackgroundfetchsuccess", "set_onbackgroundfetchsuccess" },
            .{ "onbackgroundfetchfail", "get_onbackgroundfetchfail", "set_onbackgroundfetchfail" },
            .{ "onbackgroundfetchabort", "get_onbackgroundfetchabort", "set_onbackgroundfetchabort" },
            .{ "onbackgroundfetchclick", "get_onbackgroundfetchclick", "set_onbackgroundfetchclick" },
            .{ "onpush", "get_onpush", "set_onpush" },
            .{ "onpushsubscriptionchange", "get_onpushsubscriptionchange", "set_onpushsubscriptionchange" },
            .{ "oncanmakepayment", "get_oncanmakepayment", "set_oncanmakepayment" },
            .{ "onpaymentrequest", "get_onpaymentrequest", "set_onpaymentrequest" },
            .{ "onnotificationclick", "get_onnotificationclick", "set_onnotificationclick" },
            .{ "onnotificationclose", "get_onnotificationclose", "set_onnotificationclose" },
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
            clients: *runtime.Instance = undefined,
            registration: *runtime.Instance = undefined,
            serviceWorker: *runtime.Instance = undefined,
            oninstall: EventHandler = undefined,
            onactivate: EventHandler = undefined,
            onfetch: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            onperiodicsync: EventHandler = undefined,
            cookieStore: *runtime.Instance = undefined,
            oncookiechange: EventHandler = undefined,
            onsync: EventHandler = undefined,
            oncontentdelete: EventHandler = undefined,
            onbackgroundfetchsuccess: EventHandler = undefined,
            onbackgroundfetchfail: EventHandler = undefined,
            onbackgroundfetchabort: EventHandler = undefined,
            onbackgroundfetchclick: EventHandler = undefined,
            onpush: EventHandler = undefined,
            onpushsubscriptionchange: EventHandler = undefined,
            oncanmakepayment: EventHandler = undefined,
            onpaymentrequest: EventHandler = undefined,
            onnotificationclick: EventHandler = undefined,
            onnotificationclose: EventHandler = undefined,
            cached_clients: ?*runtime.Instance = null,
            cached_registration: ?*runtime.Instance = null,
            cached_serviceWorker: ?*runtime.Instance = null,
            cached_cookieStore: ?*runtime.Instance = null,
            _internal: ?*ServiceWorkerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_clients = &get_clients,
        .get_cookieStore = &get_cookieStore,
        .get_onactivate = &get_onactivate,
        .get_onbackgroundfetchabort = &get_onbackgroundfetchabort,
        .get_onbackgroundfetchclick = &get_onbackgroundfetchclick,
        .get_onbackgroundfetchfail = &get_onbackgroundfetchfail,
        .get_onbackgroundfetchsuccess = &get_onbackgroundfetchsuccess,
        .get_oncanmakepayment = &get_oncanmakepayment,
        .get_oncontentdelete = &get_oncontentdelete,
        .get_oncookiechange = &get_oncookiechange,
        .get_onfetch = &get_onfetch,
        .get_oninstall = &get_oninstall,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onnotificationclick = &get_onnotificationclick,
        .get_onnotificationclose = &get_onnotificationclose,
        .get_onpaymentrequest = &get_onpaymentrequest,
        .get_onperiodicsync = &get_onperiodicsync,
        .get_onpush = &get_onpush,
        .get_onpushsubscriptionchange = &get_onpushsubscriptionchange,
        .get_onsync = &get_onsync,
        .get_registration = &get_registration,
        .get_serviceWorker = &get_serviceWorker,

        .set_onactivate = &set_onactivate,
        .set_onbackgroundfetchabort = &set_onbackgroundfetchabort,
        .set_onbackgroundfetchclick = &set_onbackgroundfetchclick,
        .set_onbackgroundfetchfail = &set_onbackgroundfetchfail,
        .set_onbackgroundfetchsuccess = &set_onbackgroundfetchsuccess,
        .set_oncanmakepayment = &set_oncanmakepayment,
        .set_oncontentdelete = &set_oncontentdelete,
        .set_oncookiechange = &set_oncookiechange,
        .set_onfetch = &set_onfetch,
        .set_oninstall = &set_oninstall,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onnotificationclick = &set_onnotificationclick,
        .set_onnotificationclose = &set_onnotificationclose,
        .set_onpaymentrequest = &set_onpaymentrequest,
        .set_onperiodicsync = &set_onperiodicsync,
        .set_onpush = &set_onpush,
        .set_onpushsubscriptionchange = &set_onpushsubscriptionchange,
        .set_onsync = &set_onsync,

        .call_skipWaiting = &call_skipWaiting,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ServiceWorkerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ServiceWorkerGlobalScopeImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_clients(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_clients) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_clients(instance);
        state.own.cached_clients = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_registration(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_registration) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_registration(instance);
        state.own.cached_registration = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_serviceWorker(instance);
        state.own.cached_serviceWorker = value;
        return value;
    }

    pub fn get_oninstall(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_oninstall(instance);
    }

    pub fn set_oninstall(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_oninstall(instance, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onactivate(instance);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onactivate(instance, value);
    }

    pub fn get_onfetch(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onfetch(instance);
    }

    pub fn set_onfetch(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onfetch(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onmessageerror(instance, value);
    }

    pub fn get_onperiodicsync(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onperiodicsync(instance);
    }

    pub fn set_onperiodicsync(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onperiodicsync(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cookieStore(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cookieStore) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_cookieStore(instance);
        state.own.cached_cookieStore = value;
        return value;
    }

    pub fn get_oncookiechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_oncookiechange(instance);
    }

    pub fn set_oncookiechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_oncookiechange(instance, value);
    }

    pub fn get_onsync(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onsync(instance);
    }

    pub fn set_onsync(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onsync(instance, value);
    }

    pub fn get_oncontentdelete(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_oncontentdelete(instance);
    }

    pub fn set_oncontentdelete(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_oncontentdelete(instance, value);
    }

    pub fn get_onbackgroundfetchsuccess(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchsuccess(instance);
    }

    pub fn set_onbackgroundfetchsuccess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchsuccess(instance, value);
    }

    pub fn get_onbackgroundfetchfail(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchfail(instance);
    }

    pub fn set_onbackgroundfetchfail(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchfail(instance, value);
    }

    pub fn get_onbackgroundfetchabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchabort(instance);
    }

    pub fn set_onbackgroundfetchabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchabort(instance, value);
    }

    pub fn get_onbackgroundfetchclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchclick(instance);
    }

    pub fn set_onbackgroundfetchclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchclick(instance, value);
    }

    pub fn get_onpush(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onpush(instance);
    }

    pub fn set_onpush(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onpush(instance, value);
    }

    pub fn get_onpushsubscriptionchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onpushsubscriptionchange(instance);
    }

    pub fn set_onpushsubscriptionchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onpushsubscriptionchange(instance, value);
    }

    pub fn get_oncanmakepayment(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_oncanmakepayment(instance);
    }

    pub fn set_oncanmakepayment(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_oncanmakepayment(instance, value);
    }

    pub fn get_onpaymentrequest(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onpaymentrequest(instance);
    }

    pub fn set_onpaymentrequest(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onpaymentrequest(instance, value);
    }

    pub fn get_onnotificationclick(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onnotificationclick(instance);
    }

    pub fn set_onnotificationclick(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onnotificationclick(instance, value);
    }

    pub fn get_onnotificationclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onnotificationclose(instance);
    }

    pub fn set_onnotificationclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onnotificationclose(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skipWaiting(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerGlobalScopeImpl.call_skipWaiting(instance);
    }

};
