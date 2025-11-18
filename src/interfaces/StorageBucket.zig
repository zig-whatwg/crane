//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageBucketImpl = @import("../impls/StorageBucket.zig");

pub const StorageBucket = struct {
    pub const Meta = struct {
        pub const name = "StorageBucket";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            indexedDB: IDBFactory = undefined,
            caches: CacheStorage = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(StorageBucket, .{
        .deinit_fn = &deinit_wrapper,

        .get_caches = &get_caches,
        .get_indexedDB = &get_indexedDB,
        .get_name = &get_name,

        .call_estimate = &call_estimate,
        .call_expires = &call_expires,
        .call_getDirectory = &call_getDirectory,
        .call_persist = &call_persist,
        .call_persisted = &call_persisted,
        .call_setExpires = &call_setExpires,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StorageBucketImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StorageBucketImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return StorageBucketImpl.get_name(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = StorageBucketImpl.get_indexedDB(state);
        state.cached_indexedDB = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = StorageBucketImpl.get_caches(state);
        state.cached_caches = value;
        return value;
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageBucketImpl.call_getDirectory(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_persist(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageBucketImpl.call_persist(state);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageBucketImpl.call_estimate(state);
    }

    pub fn call_setExpires(instance: *runtime.Instance, expires: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return StorageBucketImpl.call_setExpires(state, expires);
    }

    pub fn call_expires(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageBucketImpl.call_expires(state);
    }

    pub fn call_persisted(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageBucketImpl.call_persisted(state);
    }

};
