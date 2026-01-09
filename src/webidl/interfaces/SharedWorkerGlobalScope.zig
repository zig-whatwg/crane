//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SharedWorkerGlobalScopeImpl = @import("impls").SharedWorkerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WorkerGlobalScope = @import("WorkerGlobalScope.zig").WorkerGlobalScope;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
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

pub const SharedWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "SharedWorkerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkerGlobalScope.State;
        pub const ParentInterface = WorkerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "SharedWorker" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "SharedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", "set_name" },
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
            .{ "name", "get_name", "set_name" },
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
            name: typedefs.DOMString = undefined,
            onconnect: typedefs.EventHandler = undefined,
            _internal: ?*SharedWorkerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_onconnect = &get_onconnect,

        .set_name = &set_name,
        .set_onconnect = &set_onconnect,

        .call_close = &call_close,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedWorkerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SharedWorkerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedWorkerGlobalScopeImpl.deinit(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try SharedWorkerGlobalScopeImpl.get_name(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_name(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "name", value);
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
