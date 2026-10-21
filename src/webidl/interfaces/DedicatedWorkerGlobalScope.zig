//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DedicatedWorkerGlobalScopeImpl = @import("impls").DedicatedWorkerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WorkerGlobalScope = @import("interfaces").WorkerGlobalScope;
const AnimationFrameProvider = @import("mixins").AnimationFrameProvider;
const MessageEventTarget = @import("mixins").MessageEventTarget;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ByteString = @import("typedefs").ByteString;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const FontFaceSet = @import("interfaces").FontFaceSet;
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
const FrameRequestCallback = @import("callbacks").FrameRequestCallback;
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

pub const DedicatedWorkerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "DedicatedWorkerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkerGlobalScope.State;
        pub const ParentInterface = WorkerGlobalScope;
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
            .{ "name", "get_name", "set_name" },
            .{ "onrtctransform", "get_onrtctransform", "set_onrtctransform" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 1 },
            .{ "close", "call_close", 0 },
            .{ "requestAnimationFrame", "call_requestAnimationFrame", 1 },
            .{ "cancelAnimationFrame", "call_cancelAnimationFrame", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "name", "get_name", "set_name" },
            .{ "onrtctransform", "get_onrtctransform", "set_onrtctransform" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
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
            onrtctransform: typedefs.EventHandler = undefined,
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            _internal: ?*DedicatedWorkerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_name = &get_name,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onrtctransform = &get_onrtctransform,

        .set_name = &set_name,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onrtctransform = &set_onrtctransform,

        .call_cancelAnimationFrame = &call_cancelAnimationFrame,
        .call_close = &call_close,
        .call_postMessage = &call_postMessage,
        .call_requestAnimationFrame = &call_requestAnimationFrame,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("DedicatedWorkerGlobalScope has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "init") and @hasDecl(DedicatedWorkerGlobalScopeImpl, "initOwn")) @compileError("DedicatedWorkerGlobalScopeImpl defines both init and initOwn");
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "init")) return DedicatedWorkerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try DedicatedWorkerGlobalScopeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "init")) return false;
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "construction_args")) {
            inline for (DedicatedWorkerGlobalScopeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "deinit") and @hasDecl(DedicatedWorkerGlobalScopeImpl, "deinitOwn")) @compileError("DedicatedWorkerGlobalScopeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "deinit")) return DedicatedWorkerGlobalScopeImpl.deinit(instance);
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "deinitOwn")) DedicatedWorkerGlobalScopeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DedicatedWorkerGlobalScope")) {
            if (comptime @hasDecl(impls.DedicatedWorkerGlobalScope, "installHooks")) impls.DedicatedWorkerGlobalScope.installHooks();
        }
    }

    /// Extended attributes: [Replaceable]
    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try DedicatedWorkerGlobalScopeImpl.get_name(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_name(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "name", value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onrtctransform(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "get_onrtctransform")) return try DedicatedWorkerGlobalScopeImpl.get_onrtctransform(instance);
        return event_handlers.value(EventHandler, instance, "onrtctransform");
    }

    pub fn set_onrtctransform(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "set_onrtctransform")) return try DedicatedWorkerGlobalScopeImpl.set_onrtctransform(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onrtctransform", value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "get_onmessage")) return try DedicatedWorkerGlobalScopeImpl.get_onmessage(instance);
        return event_handlers.value(EventHandler, instance, "onmessage");
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "set_onmessage")) return try DedicatedWorkerGlobalScopeImpl.set_onmessage(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessage", value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "get_onmessageerror")) return try DedicatedWorkerGlobalScopeImpl.get_onmessageerror(instance);
        return event_handlers.value(EventHandler, instance, "onmessageerror");
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "set_onmessageerror")) return try DedicatedWorkerGlobalScopeImpl.set_onmessageerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessageerror", value);
    }

    pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
        return try DedicatedWorkerGlobalScopeImpl.call_cancelAnimationFrame(instance, handle);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
        return try DedicatedWorkerGlobalScopeImpl.call_postMessage(instance, message, transfer);
    }

    pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: FrameRequestCallback) anyerror!u32 {
        return try DedicatedWorkerGlobalScopeImpl.call_requestAnimationFrame(instance, callback);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try DedicatedWorkerGlobalScopeImpl.call_close(instance);
    }

    pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!void {
        if (comptime @hasDecl(DedicatedWorkerGlobalScopeImpl, "call_postMessage__1")) {
            return try DedicatedWorkerGlobalScopeImpl.call_postMessage__1(instance, message, options);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "postMessage", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_postMessage", .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.sequence} } } },
            .{ .function = "call_postMessage__1", .implemented = @hasDecl(DedicatedWorkerGlobalScopeImpl, "call_postMessage__1"), .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        } },
    };

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onrtctransform", "set_onmessage", "set_onmessageerror" };

    /// WebIDL `object` arguments (or sequences of `object`): a value that is
    /// not an Object throws a TypeError (bit i = argument i).
    pub const object_arguments = .{
        .{ "call_postMessage", 0b10 },
    };
};
