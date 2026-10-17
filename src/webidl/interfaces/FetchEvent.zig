//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FetchEventImpl = @import("impls").FetchEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const Request = @import("interfaces").Request;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const Response = @import("interfaces").Response;
const DOMString = @import("typedefs").DOMString;
const FetchEventInit = @import("dictionaries").FetchEventInit;

pub const FetchEvent = struct {
    pub const Meta = struct {
        pub const name = "FetchEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ExtendableEvent.State;
        pub const ParentInterface = ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "request", "get_request", null },
            .{ "preloadResponse", "get_preloadResponse", null },
            .{ "clientId", "get_clientId", null },
            .{ "resultingClientId", "get_resultingClientId", null },
            .{ "replacesClientId", "get_replacesClientId", null },
            .{ "handled", "get_handled", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "respondWith", "call_respondWith", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "respondWith",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "waitUntil",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "request", "get_request", null },
            .{ "preloadResponse", "get_preloadResponse", null },
            .{ "clientId", "get_clientId", null },
            .{ "resultingClientId", "get_resultingClientId", null },
            .{ "replacesClientId", "get_replacesClientId", null },
            .{ "handled", "get_handled", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            request: *runtime.Instance = undefined,
            preloadResponse: runtime.JSValue = undefined,
            clientId: runtime.DOMString = undefined,
            resultingClientId: runtime.DOMString = undefined,
            replacesClientId: runtime.DOMString = undefined,
            handled: runtime.JSValue = undefined,
            cached_request: ?*runtime.Instance = null,
            _internal: ?*FetchEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_clientId = &get_clientId,
        .get_handled = &get_handled,
        .get_preloadResponse = &get_preloadResponse,
        .get_replacesClientId = &get_replacesClientId,
        .get_request = &get_request,
        .get_resultingClientId = &get_resultingClientId,

        .call_respondWith = &call_respondWith,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("FetchEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(FetchEventImpl, "init") and @hasDecl(FetchEventImpl, "initOwn")) @compileError("FetchEventImpl defines both init and initOwn");
        if (comptime @hasDecl(FetchEventImpl, "init")) return FetchEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(FetchEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try FetchEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FetchEventImpl, "init")) return false;
        if (comptime @hasDecl(FetchEventImpl, "construction_args")) {
            inline for (FetchEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FetchEventImpl, "deinit") and @hasDecl(FetchEventImpl, "deinitOwn")) @compileError("FetchEventImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(FetchEventImpl, "deinit")) return FetchEventImpl.deinit(instance);
        if (comptime @hasDecl(FetchEventImpl, "deinitOwn")) FetchEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FetchEvent")) {
            if (comptime @hasDecl(impls.FetchEvent, "installHooks")) impls.FetchEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: FetchEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FetchEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_request) |cached| {
            return cached;
        }
        const value = try FetchEventImpl.get_request(instance);
        state.own.cached_request = value;
        @import("dom").same_object_cache.made(instance, value, "request");
        return value;
    }

    pub fn get_preloadResponse(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FetchEventImpl.get_preloadResponse(instance);
    }

    pub fn get_clientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try FetchEventImpl.get_clientId(instance);
    }

    pub fn get_resultingClientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try FetchEventImpl.get_resultingClientId(instance);
    }

    pub fn get_replacesClientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try FetchEventImpl.get_replacesClientId(instance);
    }

    pub fn get_handled(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FetchEventImpl.get_handled(instance);
    }

    pub fn call_respondWith(instance: *runtime.Instance, r: runtime.JSValue) anyerror!void {
        return try FetchEventImpl.call_respondWith(instance, r);
    }
};
