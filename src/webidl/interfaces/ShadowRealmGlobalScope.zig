//! Generated from: ShadowRealmGlobalScope.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ShadowRealmGlobalScopeImpl = @import("impls").ShadowRealmGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ByteString = @import("typedefs").ByteString;
const VoidFunction = @import("callbacks").VoidFunction;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const USVString = @import("typedefs").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;

pub const ShadowRealmGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "ShadowRealmGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier = "ShadowRealm" } },
            .{ .name = "Exposed", .value = .{ .identifier = "ShadowRealm" } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ShadowRealm = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "self", "get_self", "set_self" },
            .{ "name", "get_name", null },
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "btoa", "call_btoa", 1 },
            .{ "atob", "call_atob", 1 },
            .{ "structuredClone", "call_structuredClone", 1 },
            .{ "queueMicrotask", "call_queueMicrotask", 1 },
            .{ "reportError", "call_reportError", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "btoa",
            "atob",
            "structuredClone",
            "queueMicrotask",
            "reportError",
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
            .{ "self", "get_self", "set_self" },
            .{ "name", "get_name", null },
            .{ "origin", "get_origin", null },
            .{ "isSecureContext", "get_isSecureContext", null },
            .{ "crossOriginIsolated", "get_crossOriginIsolated", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            self: *runtime.Instance = undefined,
            name: runtime.DOMString = undefined,
            origin: runtime.USVString = undefined,
            isSecureContext: bool = undefined,
            crossOriginIsolated: bool = undefined,
            _internal: ?*ShadowRealmGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_crossOriginIsolated = &get_crossOriginIsolated,
        .get_isSecureContext = &get_isSecureContext,
        .get_name = &get_name,
        .get_origin = &get_origin,
        .get_self = &get_self,

        .set_self = &set_self,

        .call_atob = &call_atob,
        .call_btoa = &call_btoa,
        .call_queueMicrotask = &call_queueMicrotask,
        .call_reportError = &call_reportError,
        .call_structuredClone = &call_structuredClone,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ShadowRealmGlobalScope has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "init") and @hasDecl(ShadowRealmGlobalScopeImpl, "initOwn")) @compileError("ShadowRealmGlobalScopeImpl defines both init and initOwn");
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "init")) return ShadowRealmGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ShadowRealmGlobalScopeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "init")) return false;
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "construction_args")) {
            inline for (ShadowRealmGlobalScopeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "deinit") and @hasDecl(ShadowRealmGlobalScopeImpl, "deinitOwn")) @compileError("ShadowRealmGlobalScopeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "deinit")) return ShadowRealmGlobalScopeImpl.deinit(instance);
        if (comptime @hasDecl(ShadowRealmGlobalScopeImpl, "deinitOwn")) ShadowRealmGlobalScopeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ShadowRealmGlobalScope")) {
            if (comptime @hasDecl(impls.ShadowRealmGlobalScope, "installHooks")) impls.ShadowRealmGlobalScope.installHooks();
        }
    }

    /// Extended attributes: [Replaceable]
    pub fn get_self(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ShadowRealmGlobalScopeImpl.get_self(instance);
    }

    /// Extended attributes: [Replaceable]
    pub fn set_self(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        // [Replaceable] - Create own property on the object using [[DefineOwnProperty]]
        // Per WebIDL spec: PropertyDescriptor{[[Value]]: V, [[Writable]]: true,
        //                                     [[Enumerable]]: true, [[Configurable]]: true}
        try runtime.defineOwnProperty(instance, "self", value);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ShadowRealmGlobalScopeImpl.get_name(instance);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ShadowRealmGlobalScopeImpl.get_origin(instance);
    }

    pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRealmGlobalScopeImpl.get_isSecureContext(instance);
    }

    pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRealmGlobalScopeImpl.get_crossOriginIsolated(instance);
    }

    pub fn call_queueMicrotask(instance: *runtime.Instance, callback: VoidFunction) anyerror!void {
        return try ShadowRealmGlobalScopeImpl.call_queueMicrotask(instance, callback);
    }

    pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!runtime.JSValue {
        return try ShadowRealmGlobalScopeImpl.call_structuredClone(instance, value, options);
    }

    pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
        return try ShadowRealmGlobalScopeImpl.call_atob(instance, data);
    }

    pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
        return try ShadowRealmGlobalScopeImpl.call_btoa(instance, data);
    }

    pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
        return try ShadowRealmGlobalScopeImpl.call_reportError(instance, e);
    }

    /// WebIDL ByteString results: each byte becomes the code unit of its value.
    pub const byte_string_returns = .{
        "call_atob",
    };
};
