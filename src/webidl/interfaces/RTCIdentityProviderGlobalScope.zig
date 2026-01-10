//! Generated from: webrtc-identity.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCIdentityProviderGlobalScopeImpl = @import("impls").RTCIdentityProviderGlobalScope;
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
const RTCIdentityProviderRegistrar = @import("RTCIdentityProviderRegistrar.zig").RTCIdentityProviderRegistrar;
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

pub const RTCIdentityProviderGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "RTCIdentityProviderGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkerGlobalScope.State;
        pub const ParentInterface = WorkerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worker", "RTCIdentityProvider" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "RTCIdentityProvider" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .RTCIdentityProvider = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "rtcIdentityProvider", "get_rtcIdentityProvider", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            "structuredClone",
            "fetch",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "rtcIdentityProvider", "get_rtcIdentityProvider", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            rtcIdentityProvider: *runtime.Instance = undefined,
            _internal: ?*RTCIdentityProviderGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_rtcIdentityProvider = &get_rtcIdentityProvider,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCIdentityProviderGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return RTCIdentityProviderGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIdentityProviderGlobalScopeImpl.deinit(instance);
    }

    pub fn get_rtcIdentityProvider(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCIdentityProviderGlobalScopeImpl.get_rtcIdentityProvider(instance);
    }

};
