//! Generated from: webrtc-identity.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIdentityProviderGlobalScopeImpl = @import("impls").RTCIdentityProviderGlobalScope;
const WorkerGlobalScope = @import("interfaces").WorkerGlobalScope;
const RTCIdentityProviderRegistrar = @import("interfaces").RTCIdentityProviderRegistrar;

pub const RTCIdentityProviderGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "RTCIdentityProviderGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkerGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "RTCIdentityProvider" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "RTCIdentityProvider" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .RTCIdentityProvider = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            rtcIdentityProvider: RTCIdentityProviderRegistrar = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCIdentityProviderGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_caches = &get_caches,
        .get_crossOriginIsolated = &get_crossOriginIsolated,
        .get_crypto = &get_crypto,
        .get_fonts = &get_fonts,
        .get_indexedDB = &get_indexedDB,
        .get_isSecureContext = &get_isSecureContext,
        .get_location = &get_location,
        .get_navigator = &get_navigator,
        .get_onerror = &get_onerror,
        .get_onlanguagechange = &get_onlanguagechange,
        .get_onoffline = &get_onoffline,
        .get_ononline = &get_ononline,
        .get_onrejectionhandled = &get_onrejectionhandled,
        .get_onunhandledrejection = &get_onunhandledrejection,
        .get_origin = &get_origin,
        .get_performance = &get_performance,
        .get_rtcIdentityProvider = &get_rtcIdentityProvider,
        .get_scheduler = &get_scheduler,
        .get_self = &get_self,
        .get_trustedTypes = &get_trustedTypes,

        .set_onerror = &set_onerror,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onrejectionhandled = &set_onrejectionhandled,
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
        RTCIdentityProviderGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIdentityProviderGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_self(instance: *runtime.Instance) anyerror!WorkerGlobalScope {
        return try RTCIdentityProviderGlobalScopeImpl.get_self(instance);
    }

    pub fn get_location(instance: *runtime.Instance) anyerror!WorkerLocation {
        return try RTCIdentityProviderGlobalScopeImpl.get_location(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!WorkerNavigator {
        return try RTCIdentityProviderGlobalScopeImpl.get_navigator(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!OnErrorEventHandler {
        return try RTCIdentityProviderGlobalScopeImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: OnErrorEventHandler) anyerror!void {
        try RTCIdentityProviderGlobalScopeImpl.set_onerror(instance, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIdentityProviderGlobalScopeImpl.get_onlanguagechange(instance);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIdentityProviderGlobalScopeImpl.set_onlanguagechange(instance, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIdentityProviderGlobalScopeImpl.get_onoffline(instance);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIdentityProviderGlobalScopeImpl.set_onoffline(instance, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIdentityProviderGlobalScopeImpl.get_ononline(instance);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIdentityProviderGlobalScopeImpl.set_ononline(instance, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIdentityProviderGlobalScopeImpl.get_onrejectionhandled(instance);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIdentityProviderGlobalScopeImpl.set_onrejectionhandled(instance, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCIdentityProviderGlobalScopeImpl.get_onunhandledrejection(instance);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCIdentityProviderGlobalScopeImpl.set_onunhandledrejection(instance, value);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!FontFaceSet {
        return try RTCIdentityProviderGlobalScopeImpl.get_fonts(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RTCIdentityProviderGlobalScopeImpl.get_origin(instance);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
        return try RTCIdentityProviderGlobalScopeImpl.get_isSecureContext(instance);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
        return try RTCIdentityProviderGlobalScopeImpl.get_crossOriginIsolated(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!IDBFactory {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try RTCIdentityProviderGlobalScopeImpl.get_indexedDB(instance);
        state.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!TrustedTypePolicyFactory {
        return try RTCIdentityProviderGlobalScopeImpl.get_trustedTypes(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyerror!Performance {
        return try RTCIdentityProviderGlobalScopeImpl.get_performance(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!CacheStorage {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = try RTCIdentityProviderGlobalScopeImpl.get_caches(instance);
        state.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyerror!Scheduler {
        return try RTCIdentityProviderGlobalScopeImpl.get_scheduler(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyerror!Crypto {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_crypto) |cached| {
            return cached;
        }
        const value = try RTCIdentityProviderGlobalScopeImpl.get_crypto(instance);
        state.cached_crypto = value;
        return value;
    }

    pub fn get_rtcIdentityProvider(instance: *runtime.Instance) anyerror!RTCIdentityProviderRegistrar {
        return try RTCIdentityProviderGlobalScopeImpl.get_rtcIdentityProvider(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_when(instance, type_, options);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) anyerror!void {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_reportError(instance, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: anyopaque) anyerror!i32 {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_clearInterval(instance, id);
    }

    pub fn call_importScripts(instance: *runtime.Instance, urls: anyopaque) anyerror!void {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_importScripts(instance, urls);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: anyopaque) anyerror!i32 {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_removeEventListener(instance, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init: RequestInit) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try RTCIdentityProviderGlobalScopeImpl.call_fetch(instance, input, init);
    }

    pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_btoa(instance, data);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_dispatchEvent(instance, event);
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
            .ImageBitmapSource_ImageBitmapOptions => |a| return try RTCIdentityProviderGlobalScopeImpl.ImageBitmapSource_ImageBitmapOptions(instance, a.image, a.options),
            .ImageBitmapSource_long_long_long_long_ImageBitmapOptions => |a| return try RTCIdentityProviderGlobalScopeImpl.ImageBitmapSource_long_long_long_long_ImageBitmapOptions(instance, a.image, a.sx, a.sy, a.sw, a.sh, a.options),
        }
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: StructuredSerializeOptions) anyerror!anyopaque {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try RTCIdentityProviderGlobalScopeImpl.call_clearTimeout(instance, id);
    }

};
