//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerGlobalScopeImpl = @import("../impls/ServiceWorkerGlobalScope.zig");
const WorkerGlobalScope = @import("WorkerGlobalScope.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ServiceWorkerGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_self(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_self(state);
    }

    pub fn get_location(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_location(state);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_navigator(state);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onerror(state, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onlanguagechange(state);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onlanguagechange(state, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onoffline(state);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onoffline(state, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_ononline(state);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_ononline(state, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onrejectionhandled(state);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onrejectionhandled(state, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onunhandledrejection(state);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onunhandledrejection(state, value);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_fonts(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_origin(state);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_isSecureContext(state);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_crossOriginIsolated(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = ServiceWorkerGlobalScopeImpl.get_indexedDB(state);
        state.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_trustedTypes(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_performance(state);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = ServiceWorkerGlobalScopeImpl.get_caches(state);
        state.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_scheduler(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_crypto) |cached| {
            return cached;
        }
        const value = ServiceWorkerGlobalScopeImpl.get_crypto(state);
        state.cached_crypto = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_clients(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_clients) |cached| {
            return cached;
        }
        const value = ServiceWorkerGlobalScopeImpl.get_clients(state);
        state.cached_clients = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_registration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_registration) |cached| {
            return cached;
        }
        const value = ServiceWorkerGlobalScopeImpl.get_registration(state);
        state.cached_registration = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serviceWorker(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceWorker) |cached| {
            return cached;
        }
        const value = ServiceWorkerGlobalScopeImpl.get_serviceWorker(state);
        state.cached_serviceWorker = value;
        return value;
    }

    pub fn get_oninstall(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_oninstall(state);
    }

    pub fn set_oninstall(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_oninstall(state, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onactivate(state);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onactivate(state, value);
    }

    pub fn get_onfetch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onfetch(state);
    }

    pub fn set_onfetch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onfetch(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onmessage(state, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onmessageerror(state);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onmessageerror(state, value);
    }

    pub fn get_onperiodicsync(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onperiodicsync(state);
    }

    pub fn set_onperiodicsync(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onperiodicsync(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cookieStore(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cookieStore) |cached| {
            return cached;
        }
        const value = ServiceWorkerGlobalScopeImpl.get_cookieStore(state);
        state.cached_cookieStore = value;
        return value;
    }

    pub fn get_oncookiechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_oncookiechange(state);
    }

    pub fn set_oncookiechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_oncookiechange(state, value);
    }

    pub fn get_onsync(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onsync(state);
    }

    pub fn set_onsync(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onsync(state, value);
    }

    pub fn get_oncontentdelete(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_oncontentdelete(state);
    }

    pub fn set_oncontentdelete(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_oncontentdelete(state, value);
    }

    pub fn get_onbackgroundfetchsuccess(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchsuccess(state);
    }

    pub fn set_onbackgroundfetchsuccess(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchsuccess(state, value);
    }

    pub fn get_onbackgroundfetchfail(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchfail(state);
    }

    pub fn set_onbackgroundfetchfail(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchfail(state, value);
    }

    pub fn get_onbackgroundfetchabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchabort(state);
    }

    pub fn set_onbackgroundfetchabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchabort(state, value);
    }

    pub fn get_onbackgroundfetchclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onbackgroundfetchclick(state);
    }

    pub fn set_onbackgroundfetchclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onbackgroundfetchclick(state, value);
    }

    pub fn get_onpush(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onpush(state);
    }

    pub fn set_onpush(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onpush(state, value);
    }

    pub fn get_onpushsubscriptionchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onpushsubscriptionchange(state);
    }

    pub fn set_onpushsubscriptionchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onpushsubscriptionchange(state, value);
    }

    pub fn get_oncanmakepayment(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_oncanmakepayment(state);
    }

    pub fn set_oncanmakepayment(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_oncanmakepayment(state, value);
    }

    pub fn get_onpaymentrequest(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onpaymentrequest(state);
    }

    pub fn set_onpaymentrequest(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onpaymentrequest(state, value);
    }

    pub fn get_onnotificationclick(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onnotificationclick(state);
    }

    pub fn set_onnotificationclick(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onnotificationclick(state, value);
    }

    pub fn get_onnotificationclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerGlobalScopeImpl.get_onnotificationclose(state);
    }

    pub fn set_onnotificationclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerGlobalScopeImpl.set_onnotificationclose(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_when(state, type_, options);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_reportError(state, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_setInterval(state, handler, timeout, arguments);
    }

    /// Extended attributes: [NewObject]
    pub fn call_skipWaiting(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ServiceWorkerGlobalScopeImpl.call_skipWaiting(state);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_clearInterval(state, id);
    }

    pub fn call_importScripts(instance: *runtime.Instance, urls: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_importScripts(state, urls);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_setTimeout(state, handler, timeout, arguments);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ServiceWorkerGlobalScopeImpl.call_fetch(state, input, init);
    }

    pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) runtime.ByteString {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_atob(state, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_btoa(state, data);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_dispatchEvent(state, event);
    }

    /// Arguments for createImageBitmap (WebIDL overloading)
    pub const CreateImageBitmapArgs = union(enum) {
        /// createImageBitmap(image, options)
        ImageBitmapSource_ImageBitmapOptions: struct {
            image: anyopaque,
            options: anyopaque,
        },
        /// createImageBitmap(image, sx, sy, sw, sh, options)
        ImageBitmapSource_long_long_long_long_ImageBitmapOptions: struct {
            image: anyopaque,
            sx: i32,
            sy: i32,
            sw: i32,
            sh: i32,
            options: anyopaque,
        },
    };

    pub fn call_createImageBitmap(instance: *runtime.Instance, args: CreateImageBitmapArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .ImageBitmapSource_ImageBitmapOptions => |a| return ServiceWorkerGlobalScopeImpl.ImageBitmapSource_ImageBitmapOptions(state, a.image, a.options),
            .ImageBitmapSource_long_long_long_long_ImageBitmapOptions => |a| return ServiceWorkerGlobalScopeImpl.ImageBitmapSource_long_long_long_long_ImageBitmapOptions(state, a.image, a.sx, a.sy, a.sw, a.sh, a.options),
        }
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_queueMicrotask(state, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_structuredClone(state, value, options);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerGlobalScopeImpl.call_clearTimeout(state, id);
    }

};
