//! Implementation for IDBFactory interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/factory.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbfactory
//!
//! IDBFactory is the entry point for IndexedDB. It provides methods to open
//! and delete databases, list available databases, and compare keys.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IDBFactoryInterface = interfaces.IDBFactory;

// Backend imports
const storage = @import("storage");
const BackendFactory = storage.indexeddb.IDBFactory;
const BackendKey = storage.indexeddb.IDBKey;
const BackendKeyRange = storage.indexeddb.IDBKeyRange;

pub const State = IDBFactoryInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    SecurityError,
    TypeError,
    DataError,
};

/// Internal state for IDBFactory
///
/// Stores the backend IDBFactory instance that manages all database operations.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend factory instance
    factory: *BackendFactory,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.factory.deinit();
        allocator.destroy(self.factory);
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

    // Create internal state
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;

    // Create backend factory
    internal.factory = try allocator.create(BackendFactory);
    errdefer allocator.destroy(internal.factory);

    internal.factory.* = BackendFactory.init(allocator);

    // Set default storage key from context origin (if available)
    // TODO: Get origin from runtime context
    internal.factory.setStorageKey("default-origin");

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

/// Operation: open
///
/// Opens a connection to a database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-open
///
/// Returns an IDBOpenDBRequest that will eventually contain the database connection.
pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, version: u64) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Version 0 is invalid per spec
    if (version == 0) {
        return error.TypeError;
    }

    // Convert DOMString to slice for backend
    const name_slice = name.asSlice();

    // Call backend open
    const request = internal.factory.open(name_slice, version) catch |err| {
        return switch (err) {
            error.TypeError => error.TypeError,
            error.SecurityError => error.SecurityError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };

    // Wrap the backend request in a WebIDL IDBOpenDBRequest instance
    const request_instance = interfaces.IDBOpenDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend request in the WebIDL wrapper
    const request_state = request_instance.getState(interfaces.IDBOpenDBRequest.State);
    if (request_state.own._internal) |req_internal| {
        // Set the backend request reference
        _ = req_internal;
        _ = request;
        // TODO: Connect backend request to WebIDL request wrapper
    }

    return request_instance;
}

/// Operation: databases
///
/// Returns a Promise that resolves to a sequence of IDBDatabaseInfo dictionaries.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-databases
pub fn call_databases(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const db_list = internal.factory.databases() catch |err| {
        return switch (err) {
            error.SecurityError => error.SecurityError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };

    // TODO: Convert db_list to Promise<sequence<IDBDatabaseInfo>>
    // For now, return the raw pointer - V8 integration layer will handle conversion
    _ = db_list;
    return error.InvalidState; // Placeholder until Promise integration is complete
}

/// Operation: deleteDatabase
///
/// Deletes a database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-deletedatabase
///
/// Returns an IDBOpenDBRequest that fires success when the database is deleted.
pub fn call_deleteDatabase(instance: *runtime.Instance, name: runtime.DOMString) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert DOMString to slice for backend
    const name_slice = name.asSlice();

    // Call backend deleteDatabase
    const request = internal.factory.deleteDatabase(name_slice) catch |err| {
        return switch (err) {
            error.SecurityError => error.SecurityError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };

    // Wrap the backend request in a WebIDL IDBOpenDBRequest instance
    const request_instance = interfaces.IDBOpenDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend request reference
    _ = request;
    // TODO: Connect backend request to WebIDL request wrapper

    return request_instance;
}

/// Operation: cmp
///
/// Compares two IndexedDB keys.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-cmp
///
/// Returns:
/// -  1 if first > second
/// - -1 if first < second
/// -  0 if first == second
pub fn call_cmp(instance: *runtime.Instance, first: *const anyopaque, second: *const anyopaque) ImplError!i16 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert anyopaque pointers to IDBKey
    // The V8 layer should have already converted JS values to IDBKey
    const first_key = convertToKey(first) catch return error.DataError;
    const second_key = convertToKey(second) catch return error.DataError;

    return internal.factory.cmp(first_key, second_key);
}

/// Convert anyopaque to IDBKey
///
/// This handles the conversion from V8 values (passed as opaque pointers)
/// to the backend IDBKey type.
fn convertToKey(ptr: *const anyopaque) !BackendKey {
    // For now, assume the pointer is directly an IDBKey
    // In full implementation, this would inspect the JS value type
    // and construct the appropriate IDBKey variant
    _ = ptr;

    // TODO: Implement proper JS value to IDBKey conversion
    // This requires integration with the V8 conversions layer
    return BackendKey.number(0); // Placeholder
}
