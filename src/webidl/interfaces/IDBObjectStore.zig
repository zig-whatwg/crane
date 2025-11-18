//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBObjectStoreImpl = @import("impls").IDBObjectStore;
const IDBRequest = @import("interfaces").IDBRequest;
const IDBGetAllOptions = @import("dictionaries").IDBGetAllOptions;
const DOMStringList = @import("interfaces").DOMStringList;
const (DOMString or sequence) = @import("interfaces").(DOMString or sequence);
const IDBIndexParameters = @import("dictionaries").IDBIndexParameters;
const IDBCursorDirection = @import("enums").IDBCursorDirection;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBTransaction = @import("interfaces").IDBTransaction;

pub const IDBObjectStore = struct {
    pub const Meta = struct {
        pub const name = "IDBObjectStore";
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
            keyPath: anyopaque = undefined,
            indexNames: DOMStringList = undefined,
            transaction: IDBTransaction = undefined,
            autoIncrement: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBObjectStore, .{
        .deinit_fn = &deinit_wrapper,

        .get_autoIncrement = &get_autoIncrement,
        .get_indexNames = &get_indexNames,
        .get_keyPath = &get_keyPath,
        .get_name = &get_name,
        .get_transaction = &get_transaction,

        .set_name = &set_name,

        .call_add = &call_add,
        .call_clear = &call_clear,
        .call_count = &call_count,
        .call_createIndex = &call_createIndex,
        .call_delete = &call_delete,
        .call_deleteIndex = &call_deleteIndex,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_getAllKeys = &call_getAllKeys,
        .call_getAllRecords = &call_getAllRecords,
        .call_getKey = &call_getKey,
        .call_index = &call_index,
        .call_openCursor = &call_openCursor,
        .call_openKeyCursor = &call_openKeyCursor,
        .call_put = &call_put,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        IDBObjectStoreImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBObjectStoreImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try IDBObjectStoreImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try IDBObjectStoreImpl.set_name(instance, value);
    }

    pub fn get_keyPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBObjectStoreImpl.get_keyPath(instance);
    }

    pub fn get_indexNames(instance: *runtime.Instance) anyerror!DOMStringList {
        return try IDBObjectStoreImpl.get_indexNames(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transaction(instance: *runtime.Instance) anyerror!IDBTransaction {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transaction) |cached| {
            return cached;
        }
        const value = try IDBObjectStoreImpl.get_transaction(instance);
        state.cached_transaction = value;
        return value;
    }

    pub fn get_autoIncrement(instance: *runtime.Instance) anyerror!bool {
        return try IDBObjectStoreImpl.get_autoIncrement(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, query: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_delete(instance, query);
    }

    pub fn call_deleteIndex(instance: *runtime.Instance, name: DOMString) anyerror!void {
        
        return try IDBObjectStoreImpl.call_deleteIndex(instance, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(count)) return error.TypeError;
        
        return try IDBObjectStoreImpl.call_getAll(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openKeyCursor(instance: *runtime.Instance, query: anyopaque, direction: IDBCursorDirection) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_openKeyCursor(instance, query, direction);
    }

    pub fn call_index(instance: *runtime.Instance, name: DOMString) anyerror!IDBIndex {
        
        return try IDBObjectStoreImpl.call_index(instance, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_count(instance: *runtime.Instance, query: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_count(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_add(instance: *runtime.Instance, value: anyopaque, key: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_add(instance, value, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clear(instance: *runtime.Instance) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        return try IDBObjectStoreImpl.call_clear(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openCursor(instance: *runtime.Instance, query: anyopaque, direction: IDBCursorDirection) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_openCursor(instance, query, direction);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(count)) return error.TypeError;
        
        return try IDBObjectStoreImpl.call_getAllKeys(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_put(instance: *runtime.Instance, value: anyopaque, key: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_put(instance, value, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllRecords(instance: *runtime.Instance, options: IDBGetAllOptions) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_getAllRecords(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getKey(instance: *runtime.Instance, query: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_getKey(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, query: anyopaque) anyerror!IDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_get(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createIndex(instance: *runtime.Instance, name: DOMString, keyPath: anyopaque, options: IDBIndexParameters) anyerror!IDBIndex {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_createIndex(instance, name, keyPath, options);
    }

};
