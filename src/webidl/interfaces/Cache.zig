//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CacheImpl = @import("impls").Cache;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CacheQueryOptions = @import("dictionaries").CacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const Response = @import("interfaces").Response;

pub const Cache = struct {
    pub const Meta = struct {
        pub const name = "Cache";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "match", "call_match", 1 },
            .{ "matchAll", "call_matchAll", 0 },
            .{ "add", "call_add", 1 },
            .{ "addAll", "call_addAll", 1 },
            .{ "put", "call_put", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "keys", "call_keys", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "match",
            "matchAll",
            "add",
            "addAll",
            "put",
            "delete",
            "keys",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CacheImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_add = &call_add,
        .call_addAll = &call_addAll,
        .call_delete = &call_delete,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_matchAll = &call_matchAll,
        .call_put = &call_put,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("Cache has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CacheImpl, "init") and @hasDecl(CacheImpl, "initOwn")) @compileError("CacheImpl defines both init and initOwn");
        if (comptime @hasDecl(CacheImpl, "init")) return CacheImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(CacheImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try CacheImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CacheImpl, "init")) return false;
        if (comptime @hasDecl(CacheImpl, "construction_args")) {
            inline for (CacheImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(CacheImpl, "deinit") and @hasDecl(CacheImpl, "deinitOwn")) @compileError("CacheImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CacheImpl, "deinit")) return CacheImpl.deinit(instance);
        if (comptime @hasDecl(CacheImpl, "deinitOwn")) CacheImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Cache")) {
            if (comptime @hasDecl(impls.Cache, "installHooks")) impls.Cache.installHooks();
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheImpl.call_match(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheImpl.call_delete(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, request: webidl.Opt(RequestInfo), options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheImpl.call_matchAll(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addAll(instance: *runtime.Instance, requests: runtime.JSValue) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheImpl.call_addAll(instance, requests);
    }

    /// Extended attributes: [NewObject]
    pub fn call_put(instance: *runtime.Instance, request: RequestInfo, response: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheImpl.call_put(instance, request, response);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance, request: webidl.Opt(RequestInfo), options: webidl.Opt(CacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheImpl.call_keys(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_add(instance: *runtime.Instance, request: RequestInfo) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheImpl.call_add(instance, request);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_put", 1, "Response" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_match",
        "call_delete",
        "call_matchAll",
        "call_addAll",
        "call_put",
        "call_keys",
        "call_add",
    };
};
