//! Generated from: saa-non-cookie-storage.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageAccessHandleImpl = @import("impls").StorageAccessHandle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const LockManager = @import("interfaces").LockManager;
const FileSystemDirectoryHandle = @import("interfaces").FileSystemDirectoryHandle;
const Blob = @import("interfaces").Blob;
const CacheStorage = @import("interfaces").CacheStorage;
const SharedWorker = @import("interfaces").SharedWorker;
const IDBFactory = @import("interfaces").IDBFactory;
const StorageEstimate = @import("dictionaries").StorageEstimate;
const USVString = @import("typedefs").USVString;
const Storage = @import("interfaces").Storage;
const BroadcastChannel = @import("interfaces").BroadcastChannel;
const SharedWorkerOptions = @import("dictionaries").SharedWorkerOptions;
const DOMString = @import("typedefs").DOMString;
const MediaSource = @import("interfaces").MediaSource;

pub const StorageAccessHandle = struct {
    pub const Meta = struct {
        pub const name = "StorageAccessHandle";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sessionStorage", "get_sessionStorage", null },
            .{ "localStorage", "get_localStorage", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "locks", "get_locks", null },
            .{ "caches", "get_caches", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getDirectory", "call_getDirectory", 0 },
            .{ "estimate", "call_estimate", 0 },
            .{ "createObjectURL", "call_createObjectURL", 1 },
            .{ "revokeObjectURL", "call_revokeObjectURL", 1 },
            .{ "BroadcastChannel", "call_BroadcastChannel", 1 },
            .{ "SharedWorker", "call_SharedWorker", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getDirectory",
            "estimate",
            "createObjectURL",
            "revokeObjectURL",
            "BroadcastChannel",
            "SharedWorker",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sessionStorage", "get_sessionStorage", null },
            .{ "localStorage", "get_localStorage", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "locks", "get_locks", null },
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
            sessionStorage: *runtime.Instance = undefined,
            localStorage: *runtime.Instance = undefined,
            indexedDB: *runtime.Instance = undefined,
            locks: *runtime.Instance = undefined,
            caches: *runtime.Instance = undefined,
            _internal: ?*StorageAccessHandleImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_caches = &get_caches,
        .get_indexedDB = &get_indexedDB,
        .get_localStorage = &get_localStorage,
        .get_locks = &get_locks,
        .get_sessionStorage = &get_sessionStorage,

        .call_BroadcastChannel = &call_BroadcastChannel,
        .call_SharedWorker = &call_SharedWorker,
        .call_createObjectURL = &call_createObjectURL,
        .call_estimate = &call_estimate,
        .call_getDirectory = &call_getDirectory,
        .call_revokeObjectURL = &call_revokeObjectURL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("StorageAccessHandle has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(StorageAccessHandleImpl, "init") and @hasDecl(StorageAccessHandleImpl, "initOwn")) @compileError("StorageAccessHandleImpl defines both init and initOwn");
        if (comptime @hasDecl(StorageAccessHandleImpl, "init")) return StorageAccessHandleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(StorageAccessHandleImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try StorageAccessHandleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StorageAccessHandleImpl, "init")) return false;
        if (comptime @hasDecl(StorageAccessHandleImpl, "construction_args")) {
            inline for (StorageAccessHandleImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(StorageAccessHandleImpl, "deinit") and @hasDecl(StorageAccessHandleImpl, "deinitOwn")) @compileError("StorageAccessHandleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(StorageAccessHandleImpl, "deinit")) return StorageAccessHandleImpl.deinit(instance);
        if (comptime @hasDecl(StorageAccessHandleImpl, "deinitOwn")) StorageAccessHandleImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "StorageAccessHandle")) {
            if (comptime @hasDecl(impls.StorageAccessHandle, "installHooks")) impls.StorageAccessHandle.installHooks();
        }
    }

    pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try StorageAccessHandleImpl.get_sessionStorage(instance);
    }

    pub fn get_localStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try StorageAccessHandleImpl.get_localStorage(instance);
    }

    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try StorageAccessHandleImpl.get_indexedDB(instance);
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try StorageAccessHandleImpl.get_locks(instance);
    }

    pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try StorageAccessHandleImpl.get_caches(instance);
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageAccessHandleImpl.call_getDirectory(instance);
    }

    pub fn call_BroadcastChannel(instance: *runtime.Instance, name: DOMString) anyerror!*runtime.Instance {
        return try StorageAccessHandleImpl.call_BroadcastChannel(instance, name);
    }

    pub fn call_SharedWorker(instance: *runtime.Instance, scriptURL: runtime.USVString, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        return try StorageAccessHandleImpl.call_SharedWorker(instance, scriptURL, options);
    }

    pub fn call_createObjectURL(instance: *runtime.Instance, obj: runtime.JSValue) anyerror!DOMString {
        return try StorageAccessHandleImpl.call_createObjectURL(instance, obj);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageAccessHandleImpl.call_estimate(instance);
    }

    pub fn call_revokeObjectURL(instance: *runtime.Instance, url: DOMString) anyerror!void {
        return try StorageAccessHandleImpl.call_revokeObjectURL(instance, url);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getDirectory",
        "call_estimate",
    };
};
