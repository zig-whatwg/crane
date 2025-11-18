//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DedicatedWorkerGlobalScopeImpl = @import("../impls/DedicatedWorkerGlobalScope.zig");
const WorkerGlobalScope = @import("WorkerGlobalScope.zig");
const AnimationFrameProvider = @import("AnimationFrameProvider.zig");
const MessageEventTarget = @import("MessageEventTarget.zig");

pub const DedicatedWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "DedicatedWorkerGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkerGlobalScope;
        pub const MixinTypes = .{
            AnimationFrameProvider,
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "DedicatedWorker" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            onrtctransform: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DedicatedWorkerGlobalScope, .{
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
        .get_onerror = &get_onerror,
        .get_onlanguagechange = &get_onlanguagechange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onoffline = &get_onoffline,
        .get_ononline = &get_ononline,
        .get_onrejectionhandled = &get_onrejectionhandled,
        .get_onrtctransform = &get_onrtctransform,
        .get_onunhandledrejection = &get_onunhandledrejection,
        .get_origin = &get_origin,
        .get_performance = &get_performance,
        .get_scheduler = &get_scheduler,
        .get_self = &get_self,
        .get_trustedTypes = &get_trustedTypes,

        .set_onerror = &set_onerror,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onrejectionhandled = &set_onrejectionhandled,
        .set_onrtctransform = &set_onrtctransform,
        .set_onunhandledrejection = &set_onunhandledrejection,

        .call_addEventListener = &call_addEventListener,
        .call_atob = &call_atob,
        .call_btoa = &call_btoa,
        .call_cancelAnimationFrame = &call_cancelAnimationFrame,
        .call_clearInterval = &call_clearInterval,
        .call_clearTimeout = &call_clearTimeout,
        .call_close = &call_close,
        .call_createImageBitmap = &call_createImageBitmap,
        .call_createImageBitmap = &call_createImageBitmap,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_fetch = &call_fetch,
        .call_importScripts = &call_importScripts,
        .call_postMessage = &call_postMessage,
        .call_postMessage = &call_postMessage,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_removeEventListener = &call_removeEventListener,
        .call_reportError = &call_reportError,
        .call_requestAnimationFrame = &call_requestAnimationFrame,
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
        DedicatedWorkerGlobalScopeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_self(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_self(state);
    }

    pub fn get_location(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_location(state);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_navigator(state);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onerror(state, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onlanguagechange(state);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onlanguagechange(state, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onoffline(state);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onoffline(state, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_ononline(state);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_ononline(state, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onrejectionhandled(state);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onrejectionhandled(state, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onunhandledrejection(state);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onunhandledrejection(state, value);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_fonts(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_origin(state);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_isSecureContext(state);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_crossOriginIsolated(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = DedicatedWorkerGlobalScopeImpl.get_indexedDB(state);
        state.cached_indexedDB = value;
        return value;
    }

    pub fn get_trustedTypes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_trustedTypes(state);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_performance(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_performance(state);
    }

    /// Extended attributes: [SecureContext], [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = DedicatedWorkerGlobalScopeImpl.get_caches(state);
        state.cached_caches = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_scheduler(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_scheduler(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_crypto(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_crypto) |cached| {
            return cached;
        }
        const value = DedicatedWorkerGlobalScopeImpl.get_crypto(state);
        state.cached_crypto = value;
        return value;
    }

    /// Extended attributes: [Replaceable]
    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_name(state);
    }

    pub fn get_onrtctransform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onrtctransform(state);
    }

    pub fn set_onrtctransform(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onrtctransform(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onmessage(state, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.get_onmessageerror(state);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DedicatedWorkerGlobalScopeImpl.set_onmessageerror(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_when(state, type_, options);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_reportError(state, e);
    }

    pub fn call_setInterval(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_setInterval(state, handler, timeout, arguments);
    }

    /// Arguments for postMessage (WebIDL overloading)
    pub const PostMessageArgs = union(enum) {
        /// postMessage(message, transfer)
        any_sequence: struct {
            message: anyopaque,
            transfer: anyopaque,
        },
        /// postMessage(message, options)
        any_StructuredSerializeOptions: struct {
            message: anyopaque,
            options: anyopaque,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .any_sequence => |a| return DedicatedWorkerGlobalScopeImpl.any_sequence(state, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return DedicatedWorkerGlobalScopeImpl.any_StructuredSerializeOptions(state, a.message, a.options),
        }
    }

    pub fn call_clearInterval(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_clearInterval(state, id);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_cancelAnimationFrame(state, handle);
    }

    pub fn call_importScripts(instance: *runtime.Instance, urls: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_importScripts(state, urls);
    }

    pub fn call_setTimeout(instance: *runtime.Instance, handler: anyopaque, timeout: i32, arguments: anyopaque) i32 {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_setTimeout(state, handler, timeout, arguments);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fetch(instance: *runtime.Instance, input: anyopaque, init: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DedicatedWorkerGlobalScopeImpl.call_fetch(state, input, init);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: anyopaque) u32 {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_requestAnimationFrame(state, callback);
    }

    pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) runtime.ByteString {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_atob(state, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) runtime.DOMString {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_btoa(state, data);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_dispatchEvent(state, event);
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
            .ImageBitmapSource_ImageBitmapOptions => |a| return DedicatedWorkerGlobalScopeImpl.ImageBitmapSource_ImageBitmapOptions(state, a.image, a.options),
            .ImageBitmapSource_long_long_long_long_ImageBitmapOptions => |a| return DedicatedWorkerGlobalScopeImpl.ImageBitmapSource_long_long_long_long_ImageBitmapOptions(state, a.image, a.sx, a.sy, a.sw, a.sh, a.options),
        }
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_queueMicrotask(state, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_structuredClone(state, value, options);
    }

    pub fn call_clearTimeout(instance: *runtime.Instance, id: i32) anyopaque {
        const state = instance.getState(State);
        
        return DedicatedWorkerGlobalScopeImpl.call_clearTimeout(state, id);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DedicatedWorkerGlobalScopeImpl.call_close(state);
    }

};
