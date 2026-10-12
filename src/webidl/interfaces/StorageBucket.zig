//! Generated from: storage-buckets.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageBucketImpl = @import("impls").StorageBucket;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FileSystemDirectoryHandle = @import("interfaces").FileSystemDirectoryHandle;
const CacheStorage = @import("interfaces").CacheStorage;
const IDBFactory = @import("interfaces").IDBFactory;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const StorageEstimate = @import("dictionaries").StorageEstimate;
const DOMString = @import("typedefs").DOMString;

pub const StorageBucket = struct {
    pub const Meta = struct {
        pub const name = "StorageBucket";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "caches", "get_caches", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "persist", "call_persist", 0 },
            .{ "persisted", "call_persisted", 0 },
            .{ "estimate", "call_estimate", 0 },
            .{ "setExpires", "call_setExpires", 1 },
            .{ "expires", "call_expires", 0 },
            .{ "getDirectory", "call_getDirectory", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "persist",
            "persisted",
            "estimate",
            "setExpires",
            "expires",
            "getDirectory",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "caches", "get_caches", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            indexedDB: *runtime.Instance = undefined,
            caches: *runtime.Instance = undefined,
            cached_indexedDB: ?*runtime.Instance = null,
            cached_caches: ?*runtime.Instance = null,
            _internal: ?*StorageBucketImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_caches = &get_caches,
        .get_indexedDB = &get_indexedDB,
        .get_name = &get_name,

        .call_estimate = &call_estimate,
        .call_expires = &call_expires,
        .call_getDirectory = &call_getDirectory,
        .call_persist = &call_persist,
        .call_persisted = &call_persisted,
        .call_setExpires = &call_setExpires,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("StorageBucket has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(StorageBucketImpl, "init") and @hasDecl(StorageBucketImpl, "initOwn")) @compileError("StorageBucketImpl defines both init and initOwn");
        if (comptime @hasDecl(StorageBucketImpl, "init")) return StorageBucketImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(StorageBucketImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try StorageBucketImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StorageBucketImpl, "init")) return false;
        if (comptime @hasDecl(StorageBucketImpl, "construction_args")) {
            inline for (StorageBucketImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(StorageBucketImpl, "deinit") and @hasDecl(StorageBucketImpl, "deinitOwn")) @compileError("StorageBucketImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(StorageBucketImpl, "deinit")) return StorageBucketImpl.deinit(instance);
        if (comptime @hasDecl(StorageBucketImpl, "deinitOwn")) StorageBucketImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "StorageBucket")) {
            if (comptime @hasDecl(impls.StorageBucket, "installHooks")) impls.StorageBucket.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try StorageBucketImpl.get_name(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try StorageBucketImpl.get_indexedDB(instance);
        state.own.cached_indexedDB = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_caches) |cached| {
            return cached;
        }
        const value = try StorageBucketImpl.get_caches(instance);
        state.own.cached_caches = value;
        return value;
    }

    pub fn call_setExpires(instance: *runtime.Instance, expires: DOMHighResTimeStamp) anyerror!runtime.JSValue {
        return try StorageBucketImpl.call_setExpires(instance, expires);
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageBucketImpl.call_getDirectory(instance);
    }

    pub fn call_expires(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageBucketImpl.call_expires(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_persist(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageBucketImpl.call_persist(instance);
    }

    pub fn call_persisted(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageBucketImpl.call_persisted(instance);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageBucketImpl.call_estimate(instance);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_setExpires", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_setExpires",
        "call_getDirectory",
        "call_expires",
        "call_persist",
        "call_persisted",
        "call_estimate",
    };
};
