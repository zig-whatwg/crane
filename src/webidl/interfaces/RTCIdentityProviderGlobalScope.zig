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
const WorkerGlobalScope = @import("interfaces").WorkerGlobalScope;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ByteString = @import("typedefs").ByteString;
const FontFaceSet = @import("interfaces").FontFaceSet;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const RTCIdentityProviderRegistrar = @import("interfaces").RTCIdentityProviderRegistrar;
const WorkerNavigator = @import("interfaces").WorkerNavigator;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const TimerHandler = @import("typedefs").TimerHandler;
const USVString = @import("typedefs").USVString;
const Scheduler = @import("interfaces").Scheduler;
const Crypto = @import("interfaces").Crypto;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ImageBitmapOptions = @import("dictionaries").ImageBitmapOptions;
const WorkerLocation = @import("interfaces").WorkerLocation;
const EventHandler = @import("typedefs").EventHandler;
const ImageBitmap = @import("interfaces").ImageBitmap;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const TrustedScriptURLOrUSVString = @import("typedefs").TrustedScriptURLOrUSVString;
const VoidFunction = @import("callbacks").VoidFunction;
const RequestInfo = @import("typedefs").RequestInfo;
const IDBFactory = @import("interfaces").IDBFactory;
const Performance = @import("interfaces").Performance;
const CacheStorage = @import("interfaces").CacheStorage;
const RequestInit = @import("dictionaries").RequestInit;
const TrustedTypePolicyFactory = @import("interfaces").TrustedTypePolicyFactory;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Response = @import("interfaces").Response;
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
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

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
            .{ "rtcIdentityProvider", "get_rtcIdentityProvider", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCIdentityProviderGlobalScope has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "init") and @hasDecl(RTCIdentityProviderGlobalScopeImpl, "initOwn")) @compileError("RTCIdentityProviderGlobalScopeImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "init")) return RTCIdentityProviderGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try RTCIdentityProviderGlobalScopeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "init")) return false;
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "construction_args")) {
            inline for (RTCIdentityProviderGlobalScopeImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "deinit") and @hasDecl(RTCIdentityProviderGlobalScopeImpl, "deinitOwn")) @compileError("RTCIdentityProviderGlobalScopeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "deinit")) return RTCIdentityProviderGlobalScopeImpl.deinit(instance);
        if (comptime @hasDecl(RTCIdentityProviderGlobalScopeImpl, "deinitOwn")) RTCIdentityProviderGlobalScopeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCIdentityProviderGlobalScope")) {
            if (comptime @hasDecl(impls.RTCIdentityProviderGlobalScope, "installHooks")) impls.RTCIdentityProviderGlobalScope.installHooks();
        }
    }

    pub fn get_rtcIdentityProvider(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCIdentityProviderGlobalScopeImpl.get_rtcIdentityProvider(instance);
    }
};
