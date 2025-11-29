//! Generated from: html.idl
//! Generated at: 2025-11-29T05:01:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowOrWorkerGlobalScopeImpl = @import("impls").WindowOrWorkerGlobalScope;
const mixins = @import("mixins");
const ByteString = @import("interfaces").ByteString;
const Performance = @import("interfaces").Performance;
const CacheStorage = @import("interfaces").CacheStorage;
const VoidFunction = @import("callbacks").VoidFunction;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const IDBFactory = @import("interfaces").IDBFactory;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;
const TimerHandler = @import("typedefs").TimerHandler;
const USVString = @import("interfaces").USVString;
const RequestInfo = @import("typedefs").RequestInfo;
const RequestInit = @import("dictionaries").RequestInit;
const Scheduler = @import("interfaces").Scheduler;
const Crypto = @import("interfaces").Crypto;
const ImageBitmapOptions = @import("dictionaries").ImageBitmapOptions;
const Response = @import("interfaces").Response;
const DOMString = @import("typedefs").DOMString;
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const WindowOrWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "WindowOrWorkerGlobalScope";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", null },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", null },
            .{ "crypto", "get_crypto", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "reportError", "call_reportError", 1 },
            .{ "btoa", "call_btoa", 1 },
            .{ "atob", "call_atob", 1 },
            .{ "setTimeout", "call_setTimeout", 2 },
            .{ "clearTimeout", "call_clearTimeout", 0 },
            .{ "setInterval", "call_setInterval", 2 },
            .{ "clearInterval", "call_clearInterval", 0 },
            .{ "queueMicrotask", "call_queueMicrotask", 1 },
            .{ "createImageBitmap", "call_createImageBitmap", 1 },
            .{ "createImageBitmap", "call_createImageBitmap", 5 },
            .{ "structuredClone", "call_structuredClone", 1 },
            .{ "fetch", "call_fetch", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", null },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", null },
            .{ "crypto", "get_crypto", null },
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
            origin: runtime.USVString = undefined,
            isSecureContext: bool = undefined,
            crossOriginIsolated: bool = undefined,
            indexedDB: *runtime.Instance = undefined,
            trustedTypes: *runtime.Instance = undefined,
            performance: *runtime.Instance = undefined,
            caches: *runtime.Instance = undefined,
            scheduler: *runtime.Instance = undefined,
            crypto: *runtime.Instance = undefined,
            cached_indexedDB: ?*runtime.Instance = null,
            cached_caches: ?*runtime.Instance = null,
            cached_crypto: ?*runtime.Instance = null,
            _internal: ?*WindowOrWorkerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_caches = &get_caches,
        .get_crossOriginIsolated = &get_crossOriginIsolated,
        .get_crypto = &get_crypto,
        .get_indexedDB = &get_indexedDB,
        .get_isSecureContext = &get_isSecureContext,
        .get_origin = &get_origin,
        .get_performance = &get_performance,
        .get_scheduler = &get_scheduler,
        .get_trustedTypes = &get_trustedTypes,

        .call_atob = &call_atob,
        .call_btoa = &call_btoa,
        .call_clearInterval = &call_clearInterval,
        .call_clearTimeout = &call_clearTimeout,
        .call_createImageBitmap = &call_createImageBitmap,
        .call_fetch = &call_fetch,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_reportError = &call_reportError,
        .call_setInterval = &call_setInterval,
        .call_setTimeout = &call_setTimeout,
        .call_structuredClone = &call_structuredClone,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WindowOrWorkerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowOrWorkerGlobalScopeImpl.deinit(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WindowOrWorkerGlobalScopeImpl.get_origin(instance);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
        return try WindowOrWorkerGlobalScopeImpl.get_isSecureContext(instance);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
        return try WindowOrWorkerGlobalScopeImpl.get_crossOriginIsolated(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try WindowOrWorkerGlobalScopeImpl.get_indexedDB(instance);
        state.own.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowOrWorkerGlobalScopeImpl.get_trustedTypes(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowOrWorkerGlobalScopeImpl.get_performance(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_caches) |cached| {
            return cached;
        }
        const value = try WindowOrWorkerGlobalScopeImpl.get_caches(instance);
        state.own.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowOrWorkerGlobalScopeImpl.get_scheduler(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_crypto) |cached| {
            return cached;
        }
        const value = try WindowOrWorkerGlobalScopeImpl.get_crypto(instance);
        state.own.cached_crypto = value;
        return value;
    }

    pub fn call_reportError(instance: *runtime.Instance, e: *const anyopaque) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_reportError(instance, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const *const anyopaque) anyerror!i32 {
        
        return try WindowOrWorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
    }

    pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
        
        return try WindowOrWorkerGlobalScopeImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
        
        return try WindowOrWorkerGlobalScopeImpl.call_btoa(instance, data);
    }

    pub fn call_createImageBitmap(instance: *runtime.Instance, image: ImageBitmapSource, options: webidl.Opt(ImageBitmapOptions)) anyerror!*const anyopaque {
        
        return try WindowOrWorkerGlobalScopeImpl.call_createImageBitmap(instance, image, options);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_clearInterval(instance, id);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: *const anyopaque, options: webidl.Opt(StructuredSerializeOptions)) anyerror!*const anyopaque {
        
        return try WindowOrWorkerGlobalScopeImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const *const anyopaque) anyerror!i32 {
        
        return try WindowOrWorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_clearTimeout(instance, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init_data: webidl.Opt(RequestInit)) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try WindowOrWorkerGlobalScopeImpl.call_fetch(instance, input, init_data);
    }

};
