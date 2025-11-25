//! Generated from: html.idl
//! Generated at: 2025-11-25T19:42:23Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedWorkerGlobalScopeImpl = @import("impls").SharedWorkerGlobalScope;
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
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
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

pub const SharedWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "SharedWorkerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "SharedWorker" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "SharedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
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
            .{ "onconnect", "get_onconnect", "set_onconnect" },
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
            onconnect: EventHandler = undefined,
            _internal: ?*SharedWorkerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_onconnect = &get_onconnect,

        .set_onconnect = &set_onconnect,

        .call_close = &call_close,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedWorkerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedWorkerGlobalScopeImpl.deinit(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try SharedWorkerGlobalScopeImpl.get_name(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SharedWorkerGlobalScopeImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SharedWorkerGlobalScopeImpl.set_onconnect(instance, value);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try SharedWorkerGlobalScopeImpl.call_close(instance);
    }

};
