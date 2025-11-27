//! Implementation for IDBIndex interface
//!
//! Connects WebIDL IDBIndex interface to storage.indexeddb.IDBIndex implementation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const storage = @import("storage");
const IDBIndexInterface = interfaces.IDBIndex;

pub const State = IDBIndexInterface.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    TransactionInactive,
    NotFound,
    DataError,
    OutOfMemory,
};

/// Internal state wrapping storage.indexeddb.IDBIndex
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    index: ?*storage.indexeddb.IDBIndex,
    object_store_instance: ?*runtime.Instance,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

/// Initialize instance
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
    internal.index = null;
    internal.object_store_instance = null;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    runtime.Instance.deinit(instance);
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;
    return runtime.DOMString.initInterned(index.name);
}

/// Getter for objectStore - returns the associated IDBObjectStore
pub fn get_objectStore(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.object_store_instance orelse error.InvalidState;
}

/// Getter for keyPath
pub fn get_keyPath(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;
    if (index.key_path) |kp| {
        // Return key path as opaque pointer (would be string or sequence<string>)
        return @ptrCast(kp.ptr);
    }
    return error.NotFound;
}

/// Getter for multiEntry
pub fn get_multiEntry(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;
    return index.multi_entry;
}

/// Getter for unique
pub fn get_unique(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;
    return index.unique;
}

/// Setter for name - renames the index (only during version change transaction)
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.index orelse return error.InvalidState;
    // Note: Renaming requires being in a version change transaction
    // For now, just return not implemented
    _ = value;
    return error.NotImplemented;
}

/// Operation: get - retrieves the value of the first record matching the given key or key range
pub fn call_get(instance: *runtime.Instance, query: *const anyopaque) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;

    // Convert query to IDBKeyRange
    const key_range = convertQueryToKeyRange(query) orelse return error.DataError;

    const request = index.get(key_range) catch |err| {
        return mapIDBError(err);
    };

    // Wrap request in WebIDL instance
    _ = request;
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: getKey - retrieves the primary key of the first record matching the given key or key range
pub fn call_getKey(instance: *runtime.Instance, query: *const anyopaque) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;

    const key_range = convertQueryToKeyRange(query) orelse return error.DataError;

    const request = index.getKey(key_range) catch |err| {
        return mapIDBError(err);
    };

    _ = request;
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: getAll - retrieves all values matching the query
pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: *const anyopaque, count: u32) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.index orelse return error.InvalidState;
    _ = queryOrOptions;
    _ = count;
    // Would iterate through index entries and collect all matching values
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: getAllKeys - retrieves all primary keys matching the query
pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: *const anyopaque, count: u32) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.index orelse return error.InvalidState;
    _ = queryOrOptions;
    _ = count;
    // Would iterate through index entries and collect all matching primary keys
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: getAllRecords - retrieves all records matching the options
pub fn call_getAllRecords(instance: *runtime.Instance, options: dictionaries.IDBGetAllOptions) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.index orelse return error.InvalidState;
    _ = options;
    // Would return array of {key, primaryKey, value} objects
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: count - returns the count of records matching the query
pub fn call_count(instance: *runtime.Instance, query: *const anyopaque) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;

    // Convert query to key range (query parameter is always provided)
    const key_range = convertQueryToKeyRange(query);

    const request = index.count(key_range) catch |err| {
        return mapIDBError(err);
    };

    _ = request;
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: openCursor - opens a cursor over the index
pub fn call_openCursor(instance: *runtime.Instance, query: *const anyopaque, direction: enums.IDBCursorDirection) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;

    // Convert query to key range (null query means unbounded)
    const key_range = convertQueryToKeyRange(query);
    const cursor_direction = convertCursorDirection(direction);

    const request = index.openCursor(key_range, cursor_direction) catch |err| {
        return mapIDBError(err);
    };

    _ = request;
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: openKeyCursor - opens a key cursor over the index
pub fn call_openKeyCursor(instance: *runtime.Instance, query: *const anyopaque, direction: enums.IDBCursorDirection) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const index = internal.index orelse return error.InvalidState;

    // Convert query to key range (null query means unbounded)
    const key_range = convertQueryToKeyRange(query);
    const cursor_direction = convertCursorDirection(direction);

    const request = index.openKeyCursor(key_range, cursor_direction) catch |err| {
        return mapIDBError(err);
    };

    _ = request;
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

// Helper functions

fn convertQueryToKeyRange(query: *const anyopaque) ?storage.indexeddb.IDBKeyRange {
    // In a full implementation, this would:
    // 1. Check if query is an IDBKeyRange and return it directly
    // 2. If query is a key value, create an IDBKeyRange.only(key)
    _ = query;
    return storage.indexeddb.IDBKeyRange.unbounded();
}

fn convertCursorDirection(direction: enums.IDBCursorDirection) storage.indexeddb.cursor.IDBCursorDirection {
    return switch (direction) {
        ._next_ => .next,
        ._nextunique_ => .nextunique,
        ._prev_ => .prev,
        ._prevunique_ => .prevunique,
    };
}

fn mapIDBError(err: storage.indexeddb.IDBError) ImplError {
    return switch (err) {
        storage.indexeddb.IDBError.InvalidStateError => error.InvalidState,
        storage.indexeddb.IDBError.TransactionInactiveError => error.TransactionInactive,
        storage.indexeddb.IDBError.DataError => error.DataError,
        else => error.NotImplemented,
    };
}
