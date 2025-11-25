//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-25T13:07:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageBucketImpl = @import("impls").StorageBucket;
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "indexedDB", "get_indexedDB", null },
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
            name: runtime.DOMString = undefined,
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StorageBucketImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageBucketImpl.deinit(instance);
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

    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageBucketImpl.call_getDirectory(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_persist(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageBucketImpl.call_persist(instance);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageBucketImpl.call_estimate(instance);
    }

    pub fn call_setExpires(instance: *runtime.Instance, expires: DOMHighResTimeStamp) anyerror!*const anyopaque {
        
        return try StorageBucketImpl.call_setExpires(instance, expires);
    }

    pub fn call_expires(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageBucketImpl.call_expires(instance);
    }

    pub fn call_persisted(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageBucketImpl.call_persisted(instance);
    }

};
