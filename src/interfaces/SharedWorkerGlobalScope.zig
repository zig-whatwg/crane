//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedWorkerGlobalScopeImpl = @import("../impls/SharedWorkerGlobalScope.zig");
const WorkerGlobalScope = @import("WorkerGlobalScope.zig");

pub const SharedWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "SharedWorkerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkerGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "SharedWorker" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "SharedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            onconnect: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SharedWorkerGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_caches = &get_caches,
        .get_crossOriginIsolated = &get_crossOriginIsolated,
        .get_crypto = &get_crypto,
        .get_fonts = &get_fonts,
        .get_indexedDB = &get_indexedDB,
        .get_isSecureContext = &get_isSecureContext,
        .get_location = &get_location,
        .get_name = &get_name,
        .get_navigator = &get_navigator,
        .get_onconnect = &get_onconnect,
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

        .set_onconnect = &set_onconnect,
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
        .call_close = &call_close,
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
        SharedWorkerGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_self(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_self(state);
    }

    pub fn get_location(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_location(state);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_navigator(state);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.set_onerror(state, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_onlanguagechange(state);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.set_onlanguagechange(state, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_onoffline(state);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.set_onoffline(state, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_ononline(state);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.set_ononline(state, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_onrejectionhandled(state);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.set_onrejectionhandled(state, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_onunhandledrejection(state);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.set_onunhandledrejection(state, value);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_fonts(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_origin(state);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_isSecureContext(state);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_crossOriginIsolated(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = SharedWorkerGlobalScopeImpl.get_indexedDB(state);
        state.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_trustedTypes(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_performance(state);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = SharedWorkerGlobalScopeImpl.get_caches(state);
        state.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_scheduler(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_crypto) |cached| {
            return cached;
        }
        const value = SharedWorkerGlobalScopeImpl.get_crypto(state);
        state.cached_crypto = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_name(state);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.get_onconnect(state);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SharedWorkerGlobalScopeImpl.set_onconnect(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_when(state, type_, options);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_reportError(state, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_setInterval(state, handler, timeout, arguments);
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_clearInterval(state, id);
    }

    pub fn call_importScripts(instance: *runtime.Instance, urls: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_importScripts(state, urls);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_setTimeout(state, handler, timeout, arguments);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return SharedWorkerGlobalScopeImpl.call_fetch(state, input, init);
    }

    pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) runtime.ByteString {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_atob(state, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_btoa(state, data);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_dispatchEvent(state, event);
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
            .ImageBitmapSource_ImageBitmapOptions => |a| return SharedWorkerGlobalScopeImpl.ImageBitmapSource_ImageBitmapOptions(state, a.image, a.options),
            .ImageBitmapSource_long_long_long_long_ImageBitmapOptions => |a| return SharedWorkerGlobalScopeImpl.ImageBitmapSource_long_long_long_long_ImageBitmapOptions(state, a.image, a.sx, a.sy, a.sw, a.sh, a.options),
        }
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_queueMicrotask(state, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_structuredClone(state, value, options);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return SharedWorkerGlobalScopeImpl.call_clearTimeout(state, id);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedWorkerGlobalScopeImpl.call_close(state);
    }

};
