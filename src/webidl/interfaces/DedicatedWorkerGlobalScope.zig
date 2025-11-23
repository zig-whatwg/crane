//! Generated from: html.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DedicatedWorkerGlobalScopeImpl = @import("impls").DedicatedWorkerGlobalScope;
const WorkerGlobalScope = @import("interfaces").WorkerGlobalScope;
const AnimationFrameProvider = @import("interfaces").AnimationFrameProvider;
const MessageEventTarget = @import("interfaces").MessageEventTarget;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ByteString = @import("interfaces").ByteString;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const FontFaceSet = @import("interfaces").FontFaceSet;
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
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const FrameRequestCallback = @import("callbacks").FrameRequestCallback;
const VoidFunction = @import("callbacks").VoidFunction;
const Performance = @import("interfaces").Performance;
const IDBFactory = @import("interfaces").IDBFactory;
const CacheStorage = @import("interfaces").CacheStorage;
const RequestInfo = @import("typedefs").RequestInfo;
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;
const RequestInit = @import("dictionaries").RequestInit;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Response = @import("interfaces").Response;
const DOMString = @import("typedefs").DOMString;

pub const DedicatedWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "DedicatedWorkerGlobalScope";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkerGlobalScope;
        pub const MixinTypes = &.{
            AnimationFrameProvider,
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "DedicatedWorker" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "onrtctransform", "get_onrtctransform", "set_onrtctransform" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 2 },
            .{ "postMessage", "call_postMessage", 1 },
            .{ "close", "call_close", 0 },
            .{ "requestAnimationFrame", "call_requestAnimationFrame", 1 },
            .{ "cancelAnimationFrame", "call_cancelAnimationFrame", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
            "postMessage",
            "close",
            "requestAnimationFrame",
            "cancelAnimationFrame",
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
            .{ "name", "get_name", null },
            .{ "onrtctransform", "get_onrtctransform", "set_onrtctransform" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
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
            name: runtime.DOMString = undefined,
            onrtctransform: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            _internal: ?*DedicatedWorkerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onrtctransform = &get_onrtctransform,

        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onrtctransform = &set_onrtctransform,

        .call_cancelAnimationFrame = &call_cancelAnimationFrame,
        .call_close = &call_close,
        .call_postMessage = &call_postMessage,
        .call_requestAnimationFrame = &call_requestAnimationFrame,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DedicatedWorkerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DedicatedWorkerGlobalScopeImpl.deinit(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try DedicatedWorkerGlobalScopeImpl.get_name(instance);
    }

    pub fn get_onrtctransform(instance: *runtime.Instance) anyerror!EventHandler {
        return try DedicatedWorkerGlobalScopeImpl.get_onrtctransform(instance);
    }

    pub fn set_onrtctransform(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DedicatedWorkerGlobalScopeImpl.set_onrtctransform(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try DedicatedWorkerGlobalScopeImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DedicatedWorkerGlobalScopeImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try DedicatedWorkerGlobalScopeImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DedicatedWorkerGlobalScopeImpl.set_onmessageerror(instance, value);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: FrameRequestCallback) anyerror!u32 {
        
        return try DedicatedWorkerGlobalScopeImpl.call_requestAnimationFrame(instance, callback);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
        
        return try DedicatedWorkerGlobalScopeImpl.call_cancelAnimationFrame(instance, handle);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try DedicatedWorkerGlobalScopeImpl.call_close(instance);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: *const anyopaque, transfer: *const anyopaque) anyerror!void {
        
        return try DedicatedWorkerGlobalScopeImpl.call_postMessage(instance, message, transfer);
    }

};
