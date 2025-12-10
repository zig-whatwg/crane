//! Implementation for IDBObjectStore interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/object_store.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbobjectstore
//!
//! IDBObjectStore represents an object store in a database. It provides CRUD operations.

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IDBObjectStoreInterface = interfaces.IDBObjectStore;

// Backend imports
const storage = @import("storage");
const BackendObjectStore = storage.indexeddb.object_store.IDBObjectStore;
const BackendKeyRange = storage.indexeddb.IDBKeyRange;
const BackendCursorDirection = storage.indexeddb.cursor.IDBCursorDirection;

pub const State = IDBObjectStoreInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    NotFound,
    DataError,
    ReadOnlyError,
    TransactionInactiveError,
    ConstraintError,
};

/// Internal state for IDBObjectStore
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend object store (borrowed, owned by transaction/database)
    store: ?*BackendObjectStore,

    /// Parent transaction instance
    transaction: ?*runtime.Instance,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Don't destroy backend store - it's owned by the database
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);

    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.store = null;
    internal.transaction = null;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;
    return runtime.DOMString.initInterned(store.name);
}

/// Getter for keyPath
pub fn get_keyPath(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    // Get key path from backend
    if (store.getKeyPathString()) |_| {
        // TODO: Convert to JS value
        return error.InvalidState;
    }
    // Return null/undefined for no key path
    return error.InvalidState;
}

/// Getter for indexNames
pub fn get_indexNames(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = store.indexNames() catch return error.OutOfMemory;
    // TODO: Create DOMStringList from names
    return error.InvalidState;
}

/// Getter for transaction
pub fn get_transaction(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.transaction orelse error.InvalidState;
}

/// Getter for autoIncrement
pub fn get_autoIncrement(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;
    return store.auto_increment;
}

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    // Renaming object stores is only allowed during versionchange transactions
    _ = store;
    _ = value;
    return error.InvalidState; // TODO: Implement rename
}

/// Operation: put
pub fn call_put(instance: *runtime.Instance, value: runtime.JSValue, key: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    // TODO: Convert JS value to serialized bytes
    // TODO: Convert JS key to IDBKey
    _ = value;
    _ = key;

    const request = store.put(&.{}, null) catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            error.DataError => error.DataError,
            error.ConstraintError => error.ConstraintError,
            else => error.InvalidState,
        };
    };

    // Create WebIDL IDBRequest wrapper
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, value: runtime.JSValue, key: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = value;
    _ = key;

    const request = store.add(&.{}, null) catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            error.DataError => error.DataError,
            error.ConstraintError => error.ConstraintError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.delete(BackendKeyRange.unbounded()) catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const request = store.clear() catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.get(BackendKeyRange.unbounded()) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: getKey
pub fn call_getKey(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.getKey(BackendKeyRange.unbounded()) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: getAll
pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = queryOrOptions;
    _ = count;

    // TODO: Implement getAll with proper query conversion
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
}

/// Operation: getAllKeys
pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = queryOrOptions;
    _ = count;

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
}

/// Operation: getAllRecords
pub fn call_getAllRecords(instance: *runtime.Instance, options: webidl.Opt(dictionaries.IDBGetAllOptions)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = options;

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
}

/// Operation: count
pub fn call_count(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.count(null) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: openCursor
pub fn call_openCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    // Unwrap Opt for direction (default to "next")
    const direction_val = if (direction.wasPassed()) direction.value else ._next_;
    const backend_direction = switch (direction_val) {
        ._next_ => BackendCursorDirection.next,
        ._nextunique_ => BackendCursorDirection.nextunique,
        ._prev_ => BackendCursorDirection.prev,
        ._prevunique_ => BackendCursorDirection.prevunique,
    };

    const request = store.openCursor(BackendKeyRange.unbounded(), backend_direction) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: openKeyCursor
pub fn call_openKeyCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = query;
    _ = direction;

    // TODO: Implement openKeyCursor
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
}

/// Operation: index
pub fn call_index(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const name_slice = name.asSlice();

    const index = store.index(name_slice) catch |err| {
        return switch (err) {
            error.NotFoundError => error.NotFound,
            error.InvalidStateError => error.InvalidState,
            else => error.InvalidState,
        };
    };

    const index_instance = interfaces.IDBIndex.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = index;
    return index_instance;
}

/// Operation: createIndex
pub fn call_createIndex(instance: *runtime.Instance, name: runtime.DOMString, keyPath: runtime.JSValue, options: webidl.Opt(dictionaries.IDBIndexParameters)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const name_slice = name.asSlice();
    _ = keyPath;

    // Unwrap Opt for options
    const backend_options = storage.indexeddb.object_store.IDBIndexParameters{
        .unique = if (options.wasPassed()) options.value.unique orelse false else false,
        .multi_entry = if (options.wasPassed()) options.value.multiEntry orelse false else false,
    };

    const index = store.createIndex(name_slice, "", backend_options) catch |err| {
        return switch (err) {
            error.ConstraintError => error.ConstraintError,
            error.InvalidStateError => error.InvalidState,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const index_instance = interfaces.IDBIndex.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = index;
    return index_instance;
}

/// Operation: deleteIndex
pub fn call_deleteIndex(instance: *runtime.Instance, name: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const name_slice = name.asSlice();

    store.deleteIndex(name_slice) catch |err| {
        return switch (err) {
            error.NotFoundError => error.NotFound,
            error.InvalidStateError => error.InvalidState,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };
}
