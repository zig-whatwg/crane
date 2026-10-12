//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CacheStorageImpl = @import("impls").CacheStorage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Cache = @import("interfaces").Cache;
const MultiCacheQueryOptions = @import("dictionaries").MultiCacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const DOMString = @import("typedefs").DOMString;

pub const CacheStorage = struct {
    pub const Meta = struct {
        pub const name = "CacheStorage";
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
            .{ "has", "call_has", 1 },
            .{ "open", "call_open", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "keys", "call_keys", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "match",
            "has",
            "open",
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
            _internal: ?*CacheStorageImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_delete = &call_delete,
        .call_has = &call_has,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_open = &call_open,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CacheStorage has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CacheStorageImpl, "init") and @hasDecl(CacheStorageImpl, "initOwn")) @compileError("CacheStorageImpl defines both init and initOwn");
        if (comptime @hasDecl(CacheStorageImpl, "init")) return CacheStorageImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(CacheStorageImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try CacheStorageImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CacheStorageImpl, "init")) return false;
        if (comptime @hasDecl(CacheStorageImpl, "construction_args")) {
            inline for (CacheStorageImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CacheStorageImpl, "deinit") and @hasDecl(CacheStorageImpl, "deinitOwn")) @compileError("CacheStorageImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CacheStorageImpl, "deinit")) return CacheStorageImpl.deinit(instance);
        if (comptime @hasDecl(CacheStorageImpl, "deinitOwn")) CacheStorageImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CacheStorage")) {
            if (comptime @hasDecl(impls.CacheStorage, "installHooks")) impls.CacheStorage.installHooks();
        }
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(MultiCacheQueryOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheStorageImpl.call_match(instance, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_has(instance: *runtime.Instance, cacheName: DOMString) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheStorageImpl.call_has(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, cacheName: DOMString) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheStorageImpl.call_delete(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try CacheStorageImpl.call_keys(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_open(instance: *runtime.Instance, cacheName: DOMString) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try CacheStorageImpl.call_open(instance, cacheName);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_match",
        "call_has",
        "call_delete",
        "call_keys",
        "call_open",
    };
};
