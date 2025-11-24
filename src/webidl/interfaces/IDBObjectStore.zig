//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBObjectStoreImpl = @import("impls").IDBObjectStore;
const IDBRequest = @import("interfaces").IDBRequest;
const IDBGetAllOptions = @import("dictionaries").IDBGetAllOptions;
const DOMStringList = @import("interfaces").DOMStringList;
const IDBIndexParameters = @import("dictionaries").IDBIndexParameters;
const sequence = @import("interfaces").sequence;
const IDBCursorDirection = @import("enums").IDBCursorDirection;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBTransaction = @import("interfaces").IDBTransaction;
const DOMString = @import("typedefs").DOMString;

pub const IDBObjectStore = struct {
    pub const Meta = struct {
        pub const name = "IDBObjectStore";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", "set_name" },
            .{ "keyPath", "get_keyPath", null },
            .{ "indexNames", "get_indexNames", null },
            .{ "transaction", "get_transaction", null },
            .{ "autoIncrement", "get_autoIncrement", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "put", "call_put", 1 },
            .{ "add", "call_add", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "clear", "call_clear", 0 },
            .{ "get", "call_get", 1 },
            .{ "getKey", "call_getKey", 1 },
            .{ "getAll", "call_getAll", 0 },
            .{ "getAllKeys", "call_getAllKeys", 0 },
            .{ "getAllRecords", "call_getAllRecords", 0 },
            .{ "count", "call_count", 0 },
            .{ "openCursor", "call_openCursor", 0 },
            .{ "openKeyCursor", "call_openKeyCursor", 0 },
            .{ "index", "call_index", 1 },
            .{ "createIndex", "call_createIndex", 2 },
            .{ "deleteIndex", "call_deleteIndex", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "put",
            "add",
            "delete",
            "clear",
            "get",
            "getKey",
            "getAll",
            "getAllKeys",
            "getAllRecords",
            "count",
            "openCursor",
            "openKeyCursor",
            "index",
            "createIndex",
            "deleteIndex",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", "set_name" },
            .{ "keyPath", "get_keyPath", null },
            .{ "indexNames", "get_indexNames", null },
            .{ "transaction", "get_transaction", null },
            .{ "autoIncrement", "get_autoIncrement", null },
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
            keyPath: *const anyopaque = undefined,
            indexNames: *runtime.Instance = undefined,
            transaction: *runtime.Instance = undefined,
            autoIncrement: bool = undefined,
            cached_transaction: ?*runtime.Instance = null,
            _internal: ?*IDBObjectStoreImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBObjectStoreImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBObjectStoreImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try IDBObjectStoreImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try IDBObjectStoreImpl.set_name(instance, value);
    }

    pub fn get_keyPath(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBObjectStoreImpl.get_keyPath(instance);
    }

    pub fn get_indexNames(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try IDBObjectStoreImpl.get_indexNames(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transaction(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transaction) |cached| {
            return cached;
        }
        const value = try IDBObjectStoreImpl.get_transaction(instance);
        state.own.cached_transaction = value;
        return value;
    }

    pub fn get_autoIncrement(instance: *runtime.Instance) anyerror!bool {
        return try IDBObjectStoreImpl.get_autoIncrement(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, query: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_delete(instance, query);
    }

    pub fn call_deleteIndex(instance: *runtime.Instance, name: DOMString) anyerror!void {
        
        return try IDBObjectStoreImpl.call_deleteIndex(instance, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: *const anyopaque, count: u32) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(u32, count)) return error.TypeError;
        
        return try IDBObjectStoreImpl.call_getAll(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openKeyCursor(instance: *runtime.Instance, query: *const anyopaque, direction: IDBCursorDirection) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_openKeyCursor(instance, query, direction);
    }

    pub fn call_index(instance: *runtime.Instance, name: DOMString) anyerror!*runtime.Instance {
        
        return try IDBObjectStoreImpl.call_index(instance, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_count(instance: *runtime.Instance, query: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_count(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_add(instance: *runtime.Instance, value: *const anyopaque, key: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_add(instance, value, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clear(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try IDBObjectStoreImpl.call_clear(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openCursor(instance: *runtime.Instance, query: *const anyopaque, direction: IDBCursorDirection) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_openCursor(instance, query, direction);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: *const anyopaque, count: u32) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (!runtime.isInRange(u32, count)) return error.TypeError;
        
        return try IDBObjectStoreImpl.call_getAllKeys(instance, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_put(instance: *runtime.Instance, value: *const anyopaque, key: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_put(instance, value, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllRecords(instance: *runtime.Instance, options: IDBGetAllOptions) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_getAllRecords(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getKey(instance: *runtime.Instance, query: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_getKey(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, query: *const anyopaque) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_get(instance, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createIndex(instance: *runtime.Instance, name: DOMString, keyPath: *const anyopaque, options: IDBIndexParameters) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try IDBObjectStoreImpl.call_createIndex(instance, name, keyPath, options);
    }

};
