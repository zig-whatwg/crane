//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBIndexImpl = @import("impls").IDBIndex;
const IDBRequest = @import("interfaces").IDBRequest;
const IDBGetAllOptions = @import("dictionaries").IDBGetAllOptions;
const IDBCursorDirection = @import("enums").IDBCursorDirection;
const IDBObjectStore = @import("interfaces").IDBObjectStore;

pub const IDBIndex = struct {
    pub const Meta = struct {
        pub const name = "IDBIndex";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
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
            objectStore: IDBObjectStore = undefined,
            keyPath: anyopaque = undefined,
            multiEntry: bool = undefined,
            unique: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBIndex, .{
        .deinit_fn = &deinit_wrapper,

        .get_keyPath = &get_keyPath,
        .get_multiEntry = &get_multiEntry,
        .get_name = &get_name,
        .get_objectStore = &get_objectStore,
        .get_unique = &get_unique,

        .set_name = &set_name,

        .call_count = &call_count,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_getAllKeys = &call_getAllKeys,
        .call_getAllRecords = &call_getAllRecords,
        .call_getKey = &call_getKey,
        .call_openCursor = &call_openCursor,
        .call_openKeyCursor = &call_openKeyCursor,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        IDBIndexImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBIndexImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try IDBIndexImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try IDBIndexImpl.set_name(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_objectStore(instance: *runtime.Instance) anyerror!IDBObjectStore {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_objectStore) |cached| {
            return cached;
        }
        const value = try IDBIndexImpl.get_objectStore(instance);
        state.cached_objectStore = value;
        return value;
    }

    pub fn get_keyPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBIndexImpl.get_keyPath(instance);
    }

    pub fn get_multiEntry(instance: *runtime.Instance) anyerror!bool {
        return try IDBIndexImpl.get_multiEntry(instance);
    }

    pub fn get_unique(instance: *runtime.Instance) anyerror!bool {
        return try IDBIndexImpl.get_unique(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(count)) return error.TypeError;
        
        return try IDBIndexImpl.call_getAll(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openKeyCursor(instance: *runtime.Instance, query: anyopaque, direction: IDBCursorDirection) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_openKeyCursor(instance, query, direction);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllRecords(instance: *runtime.Instance, options: IDBGetAllOptions) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_getAllRecords(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_count(instance: *runtime.Instance, query: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_count(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getKey(instance: *runtime.Instance, query: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_getKey(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, query: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_get(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(count)) return error.TypeError;
        
        return try IDBIndexImpl.call_getAllKeys(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openCursor(instance: *runtime.Instance, query: anyopaque, direction: IDBCursorDirection) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBIndexImpl.call_openCursor(instance, query, direction);
    }

};
