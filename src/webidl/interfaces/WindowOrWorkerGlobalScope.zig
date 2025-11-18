//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowOrWorkerGlobalScopeImpl = @import("impls").WindowOrWorkerGlobalScope;
const Promise<ImageBitmap> = @import("interfaces").Promise<ImageBitmap>;
const VoidFunction = @import("callbacks").VoidFunction;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const IDBFactory = @import("interfaces").IDBFactory;
const Performance = @import("interfaces").Performance;
const CacheStorage = @import("interfaces").CacheStorage;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;
const TimerHandler = @import("typedefs").TimerHandler;
const Promise<Response> = @import("interfaces").Promise<Response>;
const RequestInfo = @import("typedefs").RequestInfo;
const RequestInit = @import("dictionaries").RequestInit;
const Scheduler = @import("interfaces").Scheduler;
const Crypto = @import("interfaces").Crypto;
const ImageBitmapOptions = @import("dictionaries").ImageBitmapOptions;

pub const WindowOrWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "WindowOrWorkerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            origin: runtime.USVString = undefined,
            isSecureContext: bool = undefined,
            crossOriginIsolated: bool = undefined,
            indexedDB: IDBFactory = undefined,
            trustedTypes: TrustedTypePolicyFactory = undefined,
            performance: Performance = undefined,
            caches: CacheStorage = undefined,
            scheduler: Scheduler = undefined,
            crypto: Crypto = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WindowOrWorkerGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WindowOrWorkerGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowOrWorkerGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!IDBFactory {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try WindowOrWorkerGlobalScopeImpl.get_indexedDB(instance);
        state.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!TrustedTypePolicyFactory {
        return try WindowOrWorkerGlobalScopeImpl.get_trustedTypes(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyerror!Performance {
        return try WindowOrWorkerGlobalScopeImpl.get_performance(instance);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!CacheStorage {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = try WindowOrWorkerGlobalScopeImpl.get_caches(instance);
        state.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyerror!Scheduler {
        return try WindowOrWorkerGlobalScopeImpl.get_scheduler(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyerror!Crypto {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_crypto) |cached| {
            return cached;
        }
        const value = try WindowOrWorkerGlobalScopeImpl.get_crypto(instance);
        state.cached_crypto = value;
        return value;
    }

    pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_reportError(instance, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: anyopaque) anyerror!i32 {
        
        return try WindowOrWorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
    }

    pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
        
        return try WindowOrWorkerGlobalScopeImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
        
        return try WindowOrWorkerGlobalScopeImpl.call_btoa(instance, data);
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
            .ImageBitmapSource_ImageBitmapOptions => |a| return try WindowOrWorkerGlobalScopeImpl.ImageBitmapSource_ImageBitmapOptions(instance, a.image, a.options),
            .ImageBitmapSource_long_long_long_long_ImageBitmapOptions => |a| return try WindowOrWorkerGlobalScopeImpl.ImageBitmapSource_long_long_long_long_ImageBitmapOptions(instance, a.image, a.sx, a.sy, a.sw, a.sh, a.options),
        }
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_clearInterval(instance, id);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: StructuredSerializeOptions) anyerror!anyopaque {
        
        return try WindowOrWorkerGlobalScopeImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: i32, arguments: anyopaque) anyerror!i32 {
        
        return try WindowOrWorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyerror!void {
        
        return try WindowOrWorkerGlobalScopeImpl.call_clearTimeout(instance, id);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init: RequestInit) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try WindowOrWorkerGlobalScopeImpl.call_fetch(instance, input, init);
    }

};
