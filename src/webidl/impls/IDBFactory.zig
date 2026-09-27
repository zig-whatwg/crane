//! Implementation for IDBFactory interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/factory.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbfactory
//!
//! IDBFactory is the entry point for IndexedDB. It provides methods to open
//! and delete databases, list available databases, and compare keys.

const std = @import("std");
const webidl = @import("webidl");
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

/// Deinitialize instance - clean up owned resources only
/// NOTE: Do NOT call runtime.Instance.deinit() here!
/// The GC integration layer (gc_integration.onObjectFreed) handles:
/// 1. Calling this deinit function (via vtable.deinit)
/// 2. Freeing the Instance handle back to the SlabAllocator
/// Calling Instance.deinit from here would cause infinite recursion.
pub fn deinit(instance: *runtime.Instance) void {
    // Use lifecycle tracking to prevent double-deinit
    // This can happen if wrapper_cache.deinit iterates over entries
    // and calls onObjectFreed for an instance that was already deinited elsewhere.
    if (!runtime.instance_lifecycle.markCleanupStarted(instance)) {
        return; // Already being cleaned up, skip
    }

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }

    runtime.instance_lifecycle.markCleanupComplete(instance);
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Operation: open
///
/// Opens a connection to a database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-open
///
/// Returns an IDBOpenDBRequest that will eventually contain the database connection.
pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, version: webidl.Opt(u64)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Version 0 is invalid per spec - unwrap Opt
    const version_val: ?u64 = if (version.wasPassed()) version.value else null;
    if (version_val != null and version_val.? == 0) {
        return error.TypeError;
    }

    // Convert DOMString to slice for backend
    const name_slice = name.asSlice();

    // Call backend open
    const request = internal.factory.open(name_slice, version_val) catch |err| {
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
pub fn call_databases(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
pub fn call_deleteDatabase(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*runtime.Instance {
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
pub fn call_cmp(instance: *runtime.Instance, first: runtime.JSValue, second: runtime.JSValue) anyerror!i16 {
    const state = instance.getState(State);
    _ = state.own._internal orelse return error.InvalidState;

    // Steps 1-2: Let a be the result of converting first to a key; if it is
    // invalid, throw a "DataError" DOMException.
    const a = keyFromValue(first) orelse return error.DataError;
    // Steps 3-4: the same for second.
    const b = keyFromValue(second) orelse return error.DataError;
    // Step 5: Return the result of comparing two keys with a and b.
    return storage.indexeddb.compareKeys(a, b);
}

/// IndexedDB "convert a value to a key", for the keys whose values arrive
/// already classified by the binding: a number (NaN is invalid) and a string.
/// Date, buffer-source and Array keys are objects, and reading them (a Date's
/// time value, a buffer's bytes, an Array's elements) needs Engine operations
/// that do not exist yet - until then they are invalid keys, as they were when
/// this read V8 values directly. Null for an invalid key.
///
/// The key borrows a string's bytes: it lives only for the operation.
fn keyFromValue(value: runtime.JSValue) ?BackendKey {
    return switch (value) {
        .number => |n| if (std.math.isNan(n)) null else BackendKey.number(n),
        .string => |s| BackendKey.string(s.data),
        else => null,
    };
}
