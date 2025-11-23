//! Generated from: saa-non-cookie-storage.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageAccessHandleImpl = @import("impls").StorageAccessHandle;
const LockManager = @import("interfaces").LockManager;
const FileSystemDirectoryHandle = @import("interfaces").FileSystemDirectoryHandle;
const Blob = @import("interfaces").Blob;
const CacheStorage = @import("interfaces").CacheStorage;
const SharedWorker = @import("interfaces").SharedWorker;
const IDBFactory = @import("interfaces").IDBFactory;
const StorageEstimate = @import("dictionaries").StorageEstimate;
const USVString = @import("interfaces").USVString;
const Storage = @import("interfaces").Storage;
const BroadcastChannel = @import("interfaces").BroadcastChannel;
const SharedWorkerOptions = @import("dictionaries").SharedWorkerOptions;
const DOMString = @import("typedefs").DOMString;
const MediaSource = @import("interfaces").MediaSource;

pub const StorageAccessHandle = struct {
    pub const Meta = struct {
        pub const name = "StorageAccessHandle";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sessionStorage", "get_sessionStorage", null },
            .{ "localStorage", "get_localStorage", null },
            .{ "indexedDB", "get_indexedDB", null },
            .{ "locks", "get_locks", null },
            .{ "caches", "get_caches", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            sessionStorage: Storage = undefined,
            localStorage: Storage = undefined,
            indexedDB: IDBFactory = undefined,
            locks: LockManager = undefined,
            caches: CacheStorage = undefined,
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StorageAccessHandleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageAccessHandleImpl.deinit(instance);
    }

    pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!Storage {
        return try StorageAccessHandleImpl.get_sessionStorage(instance);
    }

    pub fn get_localStorage(instance: *runtime.Instance) anyerror!Storage {
        return try StorageAccessHandleImpl.get_localStorage(instance);
    }

    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!IDBFactory {
        return try StorageAccessHandleImpl.get_indexedDB(instance);
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!LockManager {
        return try StorageAccessHandleImpl.get_locks(instance);
    }

    pub fn get_caches(instance: *runtime.Instance) anyerror!CacheStorage {
        return try StorageAccessHandleImpl.get_caches(instance);
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageAccessHandleImpl.call_getDirectory(instance);
    }

    pub fn call_BroadcastChannel(instance: *runtime.Instance, name: DOMString) anyerror!BroadcastChannel {
        
        return try StorageAccessHandleImpl.call_BroadcastChannel(instance, name);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageAccessHandleImpl.call_estimate(instance);
    }

    pub fn call_createObjectURL(instance: *runtime.Instance, obj: *const anyopaque) anyerror!DOMString {
        
        return try StorageAccessHandleImpl.call_createObjectURL(instance, obj);
    }

    pub fn call_SharedWorker(instance: *runtime.Instance, scriptURL: runtime.USVString, options: *const anyopaque) anyerror!SharedWorker {
        
        return try StorageAccessHandleImpl.call_SharedWorker(instance, scriptURL, options);
    }

    pub fn call_revokeObjectURL(instance: *runtime.Instance, url: DOMString) anyerror!void {
        
        return try StorageAccessHandleImpl.call_revokeObjectURL(instance, url);
    }

};
