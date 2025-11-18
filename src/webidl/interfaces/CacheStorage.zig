//! Generated from: service-workers.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CacheStorageImpl = @import("impls").CacheStorage;
const Promise<sequence<DOMString>> = @import("interfaces").Promise<sequence<DOMString>>;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<(Responseorundefined)> = @import("interfaces").Promise<(Responseorundefined)>;
const MultiCacheQueryOptions = @import("dictionaries").MultiCacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const Promise<Cache> = @import("interfaces").Promise<Cache>;

pub const CacheStorage = struct {
    pub const Meta = struct {
        pub const name = "CacheStorage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CacheStorage, .{
        .deinit_fn = &deinit_wrapper,

        .call_delete = &call_delete,
        .call_has = &call_has,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_open = &call_open,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CacheStorageImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CacheStorageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, cacheName: DOMString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_delete(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try CacheStorageImpl.call_keys(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_has(instance: *runtime.Instance, cacheName: DOMString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_has(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_open(instance: *runtime.Instance, cacheName: DOMString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_open(instance, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: MultiCacheQueryOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try CacheStorageImpl.call_match(instance, request, options);
    }

};
