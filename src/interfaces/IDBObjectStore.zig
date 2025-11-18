//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBObjectStoreImpl = @import("../impls/IDBObjectStore.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        IDBObjectStoreImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBObjectStoreImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return IDBObjectStoreImpl.get_name(state);
    }

    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        IDBObjectStoreImpl.set_name(state, value);
    }

    pub fn get_keyPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBObjectStoreImpl.get_keyPath(state);
    }

    pub fn get_indexNames(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBObjectStoreImpl.get_indexNames(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transaction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_transaction) |cached| {
            return cached;
        }
        const value = IDBObjectStoreImpl.get_transaction(state);
        state.cached_transaction = value;
        return value;
    }

    pub fn get_autoIncrement(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IDBObjectStoreImpl.get_autoIncrement(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_delete(state, query);
    }

    pub fn call_deleteIndex(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return IDBObjectStoreImpl.call_deleteIndex(state, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (count > std.math.maxInt(u53)) return error.TypeError;
        
        return IDBObjectStoreImpl.call_getAll(state, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openKeyCursor(instance: *runtime.Instance, query: anyopaque, direction: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_openKeyCursor(state, query, direction);
    }

    pub fn call_index(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return IDBObjectStoreImpl.call_index(state, name);
    }

    /// Extended attributes: [NewObject]
    pub fn call_count(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_count(state, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_add(instance: *runtime.Instance, value: anyopaque, key: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_add(state, value, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return IDBObjectStoreImpl.call_clear(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_openCursor(instance: *runtime.Instance, query: anyopaque, direction: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_openCursor(state, query, direction);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on count
        if (count > std.math.maxInt(u53)) return error.TypeError;
        
        return IDBObjectStoreImpl.call_getAllKeys(state, queryOrOptions, count);
    }

    /// Extended attributes: [NewObject]
    pub fn call_put(instance: *runtime.Instance, value: anyopaque, key: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_put(state, value, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getAllRecords(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_getAllRecords(state, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getKey(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_getKey(state, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_get(instance: *runtime.Instance, query: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_get(state, query);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createIndex(instance: *runtime.Instance, name: runtime.DOMString, keyPath: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBObjectStoreImpl.call_createIndex(state, name, keyPath, options);
    }

};
