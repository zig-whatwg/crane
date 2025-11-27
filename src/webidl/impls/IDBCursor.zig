//! Implementation for IDBCursor interface
//!
//! Connects WebIDL IDBCursor interface to storage.indexeddb.IDBCursor implementation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const storage = @import("storage");
const IDBCursorInterface = interfaces.IDBCursor;

// Backend types
const BackendCursor = storage.indexeddb.IDBCursor;
const BackendKey = storage.indexeddb.IDBKey;

pub const State = IDBCursorInterface.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    TransactionInactive,
    ReadOnlyError,
    InvalidAccessError,
    DataError,
    TypeError,
    OutOfMemory,
};

/// Internal state wrapping storage.indexeddb.IDBCursor
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    cursor: ?*BackendCursor,
    request_instance: ?*runtime.Instance,

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
    internal.cursor = null;
    internal.request_instance = null;

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

/// Getter for source - returns the object store or index this cursor is iterating
pub fn get_source(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;
    // Return the source (object store or index) as opaque pointer
    return switch (cursor.source) {
        .object_store => |store| @ptrCast(store),
        .index => |idx| @ptrCast(idx),
    };
}

/// Getter for direction - returns the cursor direction
pub fn get_direction(instance: *runtime.Instance) ImplError!enums.IDBCursorDirection {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;
    return switch (cursor.direction) {
        .next => ._next_,
        .nextunique => ._nextunique_,
        .prev => ._prev_,
        .prevunique => ._prevunique_,
    };
}

/// Getter for key - returns the current key
pub fn get_key(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;
    if (cursor.key) |key| {
        // Return key as opaque pointer
        return @ptrCast(&key);
    }
    // Return undefined/null for no key
    return error.InvalidState;
}

/// Getter for primaryKey - returns the current primary key
pub fn get_primaryKey(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;
    if (cursor.primary_key) |pk| {
        return @ptrCast(&pk);
    }
    return error.InvalidState;
}

/// Getter for request - returns the IDBRequest associated with the cursor
pub fn get_request(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.request_instance orelse error.InvalidState;
}

/// Operation: advance - advances the cursor by count positions
pub fn call_advance(instance: *runtime.Instance, count: u32) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;

    cursor.advance(count) catch |err| switch (err) {
        error.InvalidStateError => return error.InvalidState,
        error.TransactionInactiveError => return error.TransactionInactive,
        error.TypeError => return error.TypeError,
        else => return error.NotImplemented,
    };
}

/// Operation: continue - continues to the next position or to a specific key
pub fn call_continue(instance: *runtime.Instance, key: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;

    // Convert key from opaque to IDBKey (null means continue to next)
    const idb_key = convertOpaqueToKey(key);

    cursor.@"continue"(idb_key) catch |err| switch (err) {
        error.InvalidStateError => return error.InvalidState,
        error.TransactionInactiveError => return error.TransactionInactive,
        error.DataError => return error.DataError,
        else => return error.NotImplemented,
    };
}

/// Operation: continuePrimaryKey - continues to a specific key and primary key
pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: *const anyopaque, primaryKey: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;

    const idb_key = convertOpaqueToKey(key) orelse return error.DataError;
    const idb_primary_key = convertOpaqueToKey(primaryKey) orelse return error.DataError;

    cursor.continuePrimaryKey(idb_key, idb_primary_key) catch |err| switch (err) {
        error.InvalidStateError => return error.InvalidState,
        error.TransactionInactiveError => return error.TransactionInactive,
        error.InvalidAccessError => return error.InvalidAccessError,
        error.DataError => return error.DataError,
        else => return error.NotImplemented,
    };
}

/// Operation: update - updates the record at the cursor's current position
pub fn call_update(instance: *runtime.Instance, value: *const anyopaque) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;

    // Convert value to bytes (would be serialized JS value)
    _ = value;
    const value_bytes: []const u8 = &.{};

    const request = cursor.update(value_bytes) catch |err| switch (err) {
        error.InvalidStateError => return error.InvalidState,
        error.TransactionInactiveError => return error.TransactionInactive,
        error.ReadOnlyError => return error.ReadOnlyError,
        else => return error.NotImplemented,
    };

    _ = request;
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

/// Operation: delete - deletes the record at the cursor's current position
pub fn call_delete(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor = internal.cursor orelse return error.InvalidState;

    const request = cursor.delete() catch |err| switch (err) {
        error.InvalidStateError => return error.InvalidState,
        error.TransactionInactiveError => return error.TransactionInactive,
        error.ReadOnlyError => return error.ReadOnlyError,
        else => return error.NotImplemented,
    };

    _ = request;
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };
    return req_instance;
}

// Helper functions

fn convertOpaqueToKey(ptr: *const anyopaque) ?BackendKey {
    // In a full implementation, this would:
    // 1. Check if ptr points to a valid key representation
    // 2. Convert from JS value to IDBKey
    _ = ptr;
    return null;
}
