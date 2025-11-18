//! Generated from: service-workers.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerGlobalScopeImpl = @import("impls").ServiceWorkerGlobalScope;
const WorkerGlobalScope = @import("interfaces").WorkerGlobalScope;
const ServiceWorkerRegistration = @import("interfaces").ServiceWorkerRegistration;
const ServiceWorker = @import("interfaces").ServiceWorker;
const CookieStore = @import("interfaces").CookieStore;
const Clients = @import("interfaces").Clients;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;

pub const ServiceWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorkerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkerGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
            .{ .name = "SecureContext" },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "ServiceWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            clients: Clients = undefined,
            registration: ServiceWorkerRegistration = undefined,
            serviceWorker: ServiceWorker = undefined,
            oninstall: EventHandler = undefined,
            onactivate: EventHandler = undefined,
            onfetch: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            onperiodicsync: EventHandler = undefined,
            cookieStore: CookieStore = undefined,
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ServiceWorkerGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_caches = &get_caches,
        .get_clients = &get_clients,
        .get_cookieStore = &get_cookieStore,
        .get_crossOriginIsolated = &get_crossOriginIsolated,
        .get_crypto = &get_crypto,
        .get_fonts = &get_fonts,
        .get_indexedDB = &get_indexedDB,
        .get_isSecureContext = &get_isSecureContext,
        .get_location = &get_location,
        .get_navigator = &get_navigator,
        .get_onactivate = &get_onactivate,
        .get_onbackgroundfetchabort = &get_onbackgroundfetchabort,
        .get_onbackgroundfetchclick = &get_onbackgroundfetchclick,
        .get_onbackgroundfetchfail = &get_onbackgroundfetchfail,
        .get_onbackgroundfetchsuccess = &get_onbackgroundfetchsuccess,
        .get_oncanmakepayment = &get_oncanmakepayment,
        .get_oncontentdelete = &get_oncontentdelete,
        .get_oncookiechange = &get_oncookiechange,
        .get_onerror = &get_onerror,
        .get_onfetch = &get_onfetch,
        .get_oninstall = &get_oninstall,
        .get_onlanguagechange = &get_onlanguagechange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onnotificationclick = &get_onnotificationclick,
        .get_onnotificationclose = &get_onnotificationclose,
        .get_onoffline = &get_onoffline,
        .get_ononline = &get_ononline,
        .get_onpaymentrequest = &get_onpaymentrequest,
        .get_onperiodicsync = &get_onperiodicsync,
        .get_onpush = &get_onpush,
        .get_onpushsubscriptionchange = &get_onpushsubscriptionchange,
        .get_onrejectionhandled = &get_onrejectionhandled,
        .get_onsync = &get_onsync,
        .get_onunhandledrejection = &get_onunhandledrejection,
        .get_origin = &get_origin,
        .get_performance = &get_performance,
        .get_registration = &get_registration,
        .get_scheduler = &get_scheduler,
        .get_self = &get_self,
        .get_serviceWorker = &get_serviceWorker,
        .get_trustedTypes = &get_trustedTypes,

        .set_onactivate = &set_onactivate,
        .set_onbackgroundfetchabort = &set_onbackgroundfetchabort,
        .set_onbackgroundfetchclick = &set_onbackgroundfetchclick,
        .set_onbackgroundfetchfail = &set_onbackgroundfetchfail,
        .set_onbackgroundfetchsuccess = &set_onbackgroundfetchsuccess,
        .set_oncanmakepayment = &set_oncanmakepayment,
        .set_oncontentdelete = &set_oncontentdelete,
        .set_oncookiechange = &set_oncookiechange,
        .set_onerror = &set_onerror,
        .set_onfetch = &set_onfetch,
        .set_oninstall = &set_oninstall,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onnotificationclick = &set_onnotificationclick,
        .set_onnotificationclose = &set_onnotificationclose,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onpaymentrequest = &set_onpaymentrequest,
        .set_onperiodicsync = &set_onperiodicsync,
        .set_onpush = &set_onpush,
        .set_onpushsubscriptionchange = &set_onpushsubscriptionchange,
        .set_onrejectionhandled = &set_onrejectionhandled,
        .set_onsync = &set_onsync,
        .set_onunhandledrejection = &set_onunhandledrejection,

        .call_addEventListener = &call_addEventListener,
        .call_atob = &call_atob,
        .call_btoa = &call_btoa,
        .call_clearInterval = &call_clearInterval,
        .call_clearTimeout = &call_clearTimeout,
        .call_createImageBitmap = &call_createImageBitmap,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_fetch = &call_fetch,
        .call_importScripts = &call_importScripts,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_removeEventListener = &call_removeEventListener,
        .call_reportError = &call_reportError,
        .call_setInterval = &call_setInterval,
        .call_setTimeout = &call_setTimeout,
        .call_skipWaiting = &call_skipWaiting,
        .call_structuredClone = &call_structuredClone,
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
        ServiceWorkerGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ServiceWorkerGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_self(instance: *runtime.Instance) anyerror!WorkerGlobalScope {
        return try ServiceWorkerGlobalScopeImpl.get_self(instance);
    }

    pub fn get_location(instance: *runtime.Instance) anyerror!WorkerLocation {
        return try ServiceWorkerGlobalScopeImpl.get_location(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!WorkerNavigator {
        return try ServiceWorkerGlobalScopeImpl.get_navigator(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!OnErrorEventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: OnErrorEventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onerror(instance, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onlanguagechange(instance);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onlanguagechange(instance, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onoffline(instance);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onoffline(instance, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_ononline(instance);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_ononline(instance, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onrejectionhandled(instance);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onrejectionhandled(instance, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerGlobalScopeImpl.get_onunhandledrejection(instance);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerGlobalScopeImpl.set_onunhandledrejection(instance, value);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!FontFaceSet {
        return try ServiceWorkerGlobalScopeImpl.get_fonts(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ServiceWorkerGlobalScopeImpl.get_origin(instance);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
        return try ServiceWorkerGlobalScopeImpl.get_isSecureContext(instance);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
        return try ServiceWorkerGlobalScopeImpl.get_crossOriginIsolated(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!IDBFactory {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_indexedDB(instance);
        state.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!TrustedTypePolicyFactory {
        return try ServiceWorkerGlobalScopeImpl.get_trustedTypes(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyerror!Performance {
        return try ServiceWorkerGlobalScopeImpl.get_performance(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!CacheStorage {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_caches(instance);
        state.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyerror!Scheduler {
        return try ServiceWorkerGlobalScopeImpl.get_scheduler(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyerror!Crypto {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_crypto) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_crypto(instance);
        state.cached_crypto = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_clients(instance: *runtime.Instance) anyerror!Clients {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_clients) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_clients(instance);
        state.cached_clients = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_registration(instance: *runtime.Instance) anyerror!ServiceWorkerRegistration {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_registration) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_registration(instance);
        state.cached_registration = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!ServiceWorker {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_serviceWorker(instance);
        state.cached_serviceWorker = value;
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
    pub fn get_cookieStore(instance: *runtime.Instance) anyerror!CookieStore {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cookieStore) |cached| {
            return cached;
        }
        const value = try ServiceWorkerGlobalScopeImpl.get_cookieStore(instance);
        state.cached_cookieStore = value;
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

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ServiceWorkerGlobalScopeImpl.call_when(instance, type_, options);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) anyerror!void {
        
        return try ServiceWorkerGlobalScopeImpl.call_reportError(instance, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: anyopaque) anyerror!i32 {
        
        return try ServiceWorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skipWaiting(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerGlobalScopeImpl.call_skipWaiting(instance);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try ServiceWorkerGlobalScopeImpl.call_clearInterval(instance, id);
    }

    pub fn call_importScripts(instance: *runtime.Instance, urls: anyopaque) anyerror!void {
        
        return try ServiceWorkerGlobalScopeImpl.call_importScripts(instance, urls);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: anyopaque) anyerror!i32 {
        
        return try ServiceWorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerGlobalScopeImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerGlobalScopeImpl.call_removeEventListener(instance, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init: RequestInit) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ServiceWorkerGlobalScopeImpl.call_fetch(instance, input, init);
    }

    pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
        
        return try ServiceWorkerGlobalScopeImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
        
        return try ServiceWorkerGlobalScopeImpl.call_btoa(instance, data);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ServiceWorkerGlobalScopeImpl.call_dispatchEvent(instance, event);
    }

    /// Arguments for createImageBitmap (WebIDL overloading)
    pub const CreateImageBitmapArgs = union(enum) {
        /// createImageBitmap(image, options)
        ImageBitmapSource_ImageBitmapOptions: struct {
            image: ImageBitmapSource,
            options: ImageBitmapOptions,
        },
        /// createImageBitmap(image, sx, sy, sw, sh, options)
        ImageBitmapSource_long_long_long_long_ImageBitmapOptions: struct {
            image: ImageBitmapSource,
            sx: i32,
            sy: i32,
            sw: i32,
            sh: i32,
            options: ImageBitmapOptions,
        },
    };

    pub fn call_createImageBitmap(instance: *runtime.Instance, args: CreateImageBitmapArgs) anyerror!anyopaque {
        switch (args) {
            .ImageBitmapSource_ImageBitmapOptions => |a| return try ServiceWorkerGlobalScopeImpl.ImageBitmapSource_ImageBitmapOptions(instance, a.image, a.options),
            .ImageBitmapSource_long_long_long_long_ImageBitmapOptions => |a| return try ServiceWorkerGlobalScopeImpl.ImageBitmapSource_long_long_long_long_ImageBitmapOptions(instance, a.image, a.sx, a.sy, a.sw, a.sh, a.options),
        }
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        
        return try ServiceWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: StructuredSerializeOptions) anyerror!anyopaque {
        
        return try ServiceWorkerGlobalScopeImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try ServiceWorkerGlobalScopeImpl.call_clearTimeout(instance, id);
    }

};
