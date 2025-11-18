//! Generated from: saa-non-cookie-storage.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageAccessHandleImpl = @import("impls").StorageAccessHandle;
const Promise<FileSystemDirectoryHandle> = @import("interfaces").Promise<FileSystemDirectoryHandle>;
const LockManager = @import("interfaces").LockManager;
const Promise<StorageEstimate> = @import("interfaces").Promise<StorageEstimate>;
const BroadcastChannel = @import("interfaces").BroadcastChannel;
const (DOMString or SharedWorkerOptions) = @import("interfaces").(DOMString or SharedWorkerOptions);
const CacheStorage = @import("interfaces").CacheStorage;
const SharedWorker = @import("interfaces").SharedWorker;
const IDBFactory = @import("interfaces").IDBFactory;
const (Blob or MediaSource) = @import("interfaces").(Blob or MediaSource);
const Storage = @import("interfaces").Storage;

pub const StorageAccessHandle = struct {
    pub const Meta = struct {
        pub const name = "StorageAccessHandle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sessionStorage: Storage = undefined,
            localStorage: Storage = undefined,
            indexedDB: IDBFactory = undefined,
            locks: LockManager = undefined,
            caches: CacheStorage = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(StorageAccessHandle, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        StorageAccessHandleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageAccessHandleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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

    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageAccessHandleImpl.call_getDirectory(instance);
    }

    pub fn call_BroadcastChannel(instance: *runtime.Instance, name: DOMString) anyerror!BroadcastChannel {
        
        return try StorageAccessHandleImpl.call_BroadcastChannel(instance, name);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageAccessHandleImpl.call_estimate(instance);
    }

    pub fn call_createObjectURL(instance: *runtime.Instance, obj: anyopaque) anyerror!DOMString {
        
        return try StorageAccessHandleImpl.call_createObjectURL(instance, obj);
    }

    pub fn call_SharedWorker(instance: *runtime.Instance, scriptURL: runtime.USVString, options: anyopaque) anyerror!SharedWorker {
        
        return try StorageAccessHandleImpl.call_SharedWorker(instance, scriptURL, options);
    }

    pub fn call_revokeObjectURL(instance: *runtime.Instance, url: DOMString) anyerror!void {
        
        return try StorageAccessHandleImpl.call_revokeObjectURL(instance, url);
    }

};
