//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageBucketImpl = @import("impls").StorageBucket;
const Promise<StorageEstimate> = @import("interfaces").Promise<StorageEstimate>;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<FileSystemDirectoryHandle> = @import("interfaces").Promise<FileSystemDirectoryHandle>;
const CacheStorage = @import("interfaces").CacheStorage;
const IDBFactory = @import("interfaces").IDBFactory;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<DOMHighResTimeStamp?> = @import("interfaces").Promise<DOMHighResTimeStamp?>;

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
        
        // Initialize the instance (Impl receives full instance)
        StorageBucketImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageBucketImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try StorageBucketImpl.get_name(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_indexedDB(instance: *runtime.Instance) anyerror!IDBFactory {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_indexedDB) |cached| {
            return cached;
        }
        const value = try StorageBucketImpl.get_indexedDB(instance);
        state.cached_indexedDB = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_caches(instance: *runtime.Instance) anyerror!CacheStorage {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_caches) |cached| {
            return cached;
        }
        const value = try StorageBucketImpl.get_caches(instance);
        state.cached_caches = value;
        return value;
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageBucketImpl.call_getDirectory(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_persist(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageBucketImpl.call_persist(instance);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageBucketImpl.call_estimate(instance);
    }

    pub fn call_setExpires(instance: *runtime.Instance, expires: DOMHighResTimeStamp) anyerror!anyopaque {
        
        return try StorageBucketImpl.call_setExpires(instance, expires);
    }

    pub fn call_expires(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageBucketImpl.call_expires(instance);
    }

    pub fn call_persisted(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageBucketImpl.call_persisted(instance);
    }

};
