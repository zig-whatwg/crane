//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkerGlobalScopeImpl = @import("impls").WorkerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const FontFaceSource = @import("mixins").FontFaceSource;
const WindowOrWorkerGlobalScope = @import("mixins").WindowOrWorkerGlobalScope;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ByteString = @import("typedefs").ByteString;
const FontFaceSet = @import("FontFaceSet.zig").FontFaceSet;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const WorkerNavigator = @import("WorkerNavigator.zig").WorkerNavigator;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TimerHandler = @import("typedefs").TimerHandler;
const USVString = @import("typedefs").USVString;
const Scheduler = @import("Scheduler.zig").Scheduler;
const Crypto = @import("Crypto.zig").Crypto;
const TrustedScriptURL = @import("TrustedScriptURL.zig").TrustedScriptURL;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const ImageBitmapOptions = @import("dictionaries").ImageBitmapOptions;
const WorkerLocation = @import("WorkerLocation.zig").WorkerLocation;
const EventHandler = @import("typedefs").EventHandler;
const ImageBitmap = @import("ImageBitmap.zig").ImageBitmap;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const VoidFunction = @import("callbacks").VoidFunction;
const Performance = @import("Performance.zig").Performance;
const IDBFactory = @import("IDBFactory.zig").IDBFactory;
const CacheStorage = @import("CacheStorage.zig").CacheStorage;
const RequestInfo = @import("typedefs").RequestInfo;
const TrustedTypePolicyFactory = @import("TrustedTypePolicyFactory.zig").TrustedTypePolicyFactory;
const RequestInit = @import("dictionaries").RequestInit;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const Response = @import("Response.zig").Response;
const DOMString = @import("typedefs").DOMString;

pub const WorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "WorkerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            FontFaceSource,
            WindowOrWorkerGlobalScope,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Worker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Worker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "self", "get_self", null },
            .{ "location", "get_location", null },
            .{ "navigator", "get_navigator", null },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onlanguagechange", "get_onlanguagechange", "set_onlanguagechange" },
            .{ "onoffline", "get_onoffline", "set_onoffline" },
            .{ "ononline", "get_ononline", "set_ononline" },
            .{ "onrejectionhandled", "get_onrejectionhandled", "set_onrejectionhandled" },
            .{ "onunhandledrejection", "get_onunhandledrejection", "set_onunhandledrejection" },
            .{ "fonts", "get_fonts", null },
            .{ "origin", "get_origin", "set_origin" },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", "set_performance" },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", "set_scheduler" },
            .{ "crypto", "get_crypto", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "importScripts", "call_importScripts", 0 },
            .{ "reportError", "call_reportError", 1 },
            .{ "btoa", "call_btoa", 1 },
            .{ "atob", "call_atob", 1 },
            .{ "setTimeout", "call_setTimeout", 1 },
            .{ "clearTimeout", "call_clearTimeout", 0 },
            .{ "setInterval", "call_setInterval", 1 },
            .{ "clearInterval", "call_clearInterval", 0 },
            .{ "queueMicrotask", "call_queueMicrotask", 1 },
            .{ "createImageBitmap", "call_createImageBitmap", 1 },
            .{ "structuredClone", "call_structuredClone", 1 },
            .{ "fetch", "call_fetch", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            "structuredClone",
            "fetch",
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
            .{ "self", "get_self", null },
            .{ "location", "get_location", null },
            .{ "navigator", "get_navigator", null },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onlanguagechange", "get_onlanguagechange", "set_onlanguagechange" },
            .{ "onoffline", "get_onoffline", "set_onoffline" },
            .{ "ononline", "get_ononline", "set_ononline" },
            .{ "onrejectionhandled", "get_onrejectionhandled", "set_onrejectionhandled" },
            .{ "onunhandledrejection", "get_onunhandledrejection", "set_onunhandledrejection" },
            .{ "fonts", "get_fonts", null },
            .{ "origin", "get_origin", "set_origin" },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "trustedTypes", "get_trustedTypes", null },
            .{ "performance", "get_performance", "set_performance" },
            .{ "caches", "get_caches", null },
            .{ "scheduler", "get_scheduler", "set_scheduler" },
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
            self: *runtime.Instance = undefined,
            location: *runtime.Instance = undefined,
            navigator: *runtime.Instance = undefined,
            onerror: typedefs.OnErrorEventHandler = undefined,
            onlanguagechange: typedefs.EventHandler = undefined,
            onoffline: typedefs.EventHandler = undefined,
            ononline: typedefs.EventHandler = undefined,
            onrejectionhandled: typedefs.EventHandler = undefined,
            onunhandledrejection: typedefs.EventHandler = undefined,
            fonts: *runtime.Instance = undefined,
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
            _internal: ?*WorkerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

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
        .get_scheduler = &get_scheduler,
        .get_self = &get_self,
        .get_trustedTypes = &get_trustedTypes,

        .set_onerror = &set_onerror,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onrejectionhandled = &set_onrejectionhandled,
        .set_onunhandledrejection = &set_onunhandledrejection,
        .set_origin = &set_origin,
        .set_performance = &set_performance,
        .set_scheduler = &set_scheduler,

        .call_atob = &call_atob,
        .call_btoa = &call_btoa,
        .call_clearInterval = &call_clearInterval,
        .call_clearTimeout = &call_clearTimeout,
        .call_createImageBitmap = &call_createImageBitmap,
        .call_fetch = &call_fetch,
        .call_importScripts = &call_importScripts,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_reportError = &call_reportError,
        .call_setInterval = &call_setInterval,
        .call_setTimeout = &call_setTimeout,
        .call_structuredClone = &call_structuredClone,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return WorkerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkerGlobalScopeImpl.deinit(instance);
    }

    pub fn get_self(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerGlobalScopeImpl.get_self(instance);
    }

    pub fn get_location(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerGlobalScopeImpl.get_location(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerGlobalScopeImpl.get_navigator(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!OnErrorEventHandler {
        return try WorkerGlobalScopeImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: OnErrorEventHandler) anyerror!void {
        try WorkerGlobalScopeImpl.set_onerror(instance, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerGlobalScopeImpl.get_onlanguagechange(instance);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerGlobalScopeImpl.set_onlanguagechange(instance, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerGlobalScopeImpl.get_onoffline(instance);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerGlobalScopeImpl.set_onoffline(instance, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerGlobalScopeImpl.get_ononline(instance);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerGlobalScopeImpl.set_ononline(instance, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerGlobalScopeImpl.get_onrejectionhandled(instance);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerGlobalScopeImpl.set_onrejectionhandled(instance, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerGlobalScopeImpl.get_onunhandledrejection(instance);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerGlobalScopeImpl.set_onunhandledrejection(instance, value);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerGlobalScopeImpl.get_fonts(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WorkerGlobalScopeImpl.get_origin(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_origin(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "origin", value);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
        return try WorkerGlobalScopeImpl.get_isSecureContext(instance);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
        return try WorkerGlobalScopeImpl.get_crossOriginIsolated(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try WorkerGlobalScopeImpl.get_indexedDB(instance);
        state.own.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerGlobalScopeImpl.get_trustedTypes(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerGlobalScopeImpl.get_performance(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_performance(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "performance", value);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_caches) |cached| {
            return cached;
        }
        const value = try WorkerGlobalScopeImpl.get_caches(instance);
        state.own.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WorkerGlobalScopeImpl.get_scheduler(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_scheduler(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "scheduler", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_crypto) |cached| {
            return cached;
        }
        const value = try WorkerGlobalScopeImpl.get_crypto(instance);
        state.own.cached_crypto = value;
        return value;
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
        
        return try WorkerGlobalScopeImpl.call_setTimeout(instance, handler, timeout, arguments);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!runtime.JSValue {
        
        return try WorkerGlobalScopeImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_atob(instance: *runtime.Instance, data: DOMString) anyerror!runtime.ByteString {
        
        return try WorkerGlobalScopeImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: DOMString) anyerror!DOMString {
        
        return try WorkerGlobalScopeImpl.call_btoa(instance, data);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
        
        return try WorkerGlobalScopeImpl.call_reportError(instance, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
        
        return try WorkerGlobalScopeImpl.call_setInterval(instance, handler, timeout, arguments);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        
        return try WorkerGlobalScopeImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_createImageBitmap(instance: *runtime.Instance, image: ImageBitmapSource, options: webidl.Opt(ImageBitmapOptions)) anyerror!runtime.JSValue {
        
        return try WorkerGlobalScopeImpl.call_createImageBitmap(instance, image, options);
    }

    pub fn call_importScripts(instance: *runtime.Instance, urls: []const DOMString) anyerror!void {
        
        return try WorkerGlobalScopeImpl.call_importScripts(instance, urls);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: RequestInfo, init_data: webidl.Opt(RequestInit)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        
        return try WorkerGlobalScopeImpl.call_fetch(instance, input, init_data);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
        
        return try WorkerGlobalScopeImpl.call_clearInterval(instance, id);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
        
        return try WorkerGlobalScopeImpl.call_clearTimeout(instance, id);
    }

};
