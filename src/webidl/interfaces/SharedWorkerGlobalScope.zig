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
const WorkerGlobalScope = @import("interfaces").WorkerGlobalScope;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ByteString = @import("typedefs").ByteString;
const FontFaceSet = @import("interfaces").FontFaceSet;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
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
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: runtime.DOMString = undefined,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("SharedWorkerGlobalScope has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "init") and @hasDecl(SharedWorkerGlobalScopeImpl, "initOwn")) @compileError("SharedWorkerGlobalScopeImpl defines both init and initOwn");
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "init")) return SharedWorkerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SharedWorkerGlobalScopeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "init")) return false;
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "construction_args")) {
            inline for (SharedWorkerGlobalScopeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "deinit") and @hasDecl(SharedWorkerGlobalScopeImpl, "deinitOwn")) @compileError("SharedWorkerGlobalScopeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "deinit")) return SharedWorkerGlobalScopeImpl.deinit(instance);
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "deinitOwn")) SharedWorkerGlobalScopeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SharedWorkerGlobalScope")) {
            if (comptime @hasDecl(impls.SharedWorkerGlobalScope, "installHooks")) impls.SharedWorkerGlobalScope.installHooks();
        }
    }

    /// Extended attributes: [Replaceable]
    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SharedWorkerGlobalScopeImpl.get_name(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_name(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "name", value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "get_onconnect")) return try SharedWorkerGlobalScopeImpl.get_onconnect(instance);
        return event_handlers.value(EventHandler, instance, "onconnect");
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SharedWorkerGlobalScopeImpl, "set_onconnect")) return try SharedWorkerGlobalScopeImpl.set_onconnect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onconnect", value);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try SharedWorkerGlobalScopeImpl.call_close(instance);
    }
};
