//! Generated from: saa-non-cookie-storage.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageAccessHandleImpl = @import("../impls/StorageAccessHandle.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        StorageAccessHandleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StorageAccessHandleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sessionStorage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageAccessHandleImpl.get_sessionStorage(state);
    }

    pub fn get_localStorage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageAccessHandleImpl.get_localStorage(state);
    }

    pub fn get_indexedDB(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageAccessHandleImpl.get_indexedDB(state);
    }

    pub fn get_locks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageAccessHandleImpl.get_locks(state);
    }

    pub fn get_caches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageAccessHandleImpl.get_caches(state);
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageAccessHandleImpl.call_getDirectory(state);
    }

    pub fn call_BroadcastChannel(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return StorageAccessHandleImpl.call_BroadcastChannel(state, name);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageAccessHandleImpl.call_estimate(state);
    }

    pub fn call_createObjectURL(instance: *runtime.Instance, obj: anyopaque) runtime.DOMString {
        const state = instance.getState(State);
        
        return StorageAccessHandleImpl.call_createObjectURL(state, obj);
    }

    pub fn call_SharedWorker(instance: *runtime.Instance, scriptURL: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return StorageAccessHandleImpl.call_SharedWorker(state, scriptURL, options);
    }

    pub fn call_revokeObjectURL(instance: *runtime.Instance, url: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return StorageAccessHandleImpl.call_revokeObjectURL(state, url);
    }

};
