//! Implementation for IDBDatabase interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/database.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbdatabase
//!
//! IDBDatabase represents a connection to a database. It provides methods to:
//! - Create and delete object stores
//! - Create transactions for reading/writing data
//! - Close the database connection

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IDBDatabaseInterface = interfaces.IDBDatabase;

// Backend imports
const storage = @import("storage");
const BackendDatabase = storage.indexeddb.IDBDatabase;
const BackendTransactionMode = storage.indexeddb.IDBTransactionMode;

pub const State = IDBDatabaseInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    NotFound,
    ConstraintError,
    InvalidAccessError,
    TransactionInactiveError,
};

/// Internal state for IDBDatabase
///
/// Stores the backend database instance and event handlers.
/// Note: EventHandler is already `?*const fn(...)`, so we don't wrap in another optional
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend database
    database: *BackendDatabase,

    /// Event handlers (EventHandler = ?*const fn, so null = no handler)
    onabort: typedefs.EventHandler,
    onclose: typedefs.EventHandler,
    onerror: typedefs.EventHandler,
    onversionchange: typedefs.EventHandler,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.database.deinit();
        allocator.destroy(self.database);
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

    // Create backend database with default name/version
    // In practice, this would be set by IDBFactory.open()
    internal.database = try allocator.create(BackendDatabase);
    errdefer allocator.destroy(internal.database);

    internal.database.* = BackendDatabase.init(allocator, "unnamed", 1);

    // Initialize event handlers to null
    internal.onabort = null;
    internal.onclose = null;
    internal.onerror = null;
    internal.onversionchange = null;

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
///
/// Returns the name of the database.
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return runtime.DOMString.initInterned(internal.database.name);
}

/// Getter for version
///
/// Returns the version of the database.
pub fn get_version(instance: *runtime.Instance) ImplError!u64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.database.version;
}

/// Getter for objectStoreNames
///
/// Returns a DOMStringList of object store names.
pub fn get_objectStoreNames(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Get object store names from backend
    // TODO: Create DOMStringList instance with names
    // For now, just verify the database is accessible
    _ = internal.database.objectStoreNames() catch {
        return error.OutOfMemory;
    };

    return error.InvalidState; // Placeholder until DOMStringList is wired up
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onabort;
}

/// Getter for onclose
pub fn get_onclose(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onclose;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onerror;
}

/// Getter for onversionchange
pub fn get_onversionchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onversionchange;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onabort = value;
}

/// Setter for onclose
pub fn set_onclose(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onclose = value;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onerror = value;
}

/// Setter for onversionchange
pub fn set_onversionchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onversionchange = value;
}

/// Operation: transaction
///
/// Creates a new transaction on the database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-transaction
pub fn call_transaction(instance: *runtime.Instance, storeNames: *const anyopaque, mode: enums.IDBTransactionMode, options: dictionaries.IDBTransactionOptions) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Check if database is closed
    if (internal.database.closed) {
        return error.InvalidState;
    }

    // Convert mode enum
    const backend_mode = switch (mode) {
        ._readonly_ => BackendTransactionMode.readonly,
        ._readwrite_ => BackendTransactionMode.readwrite,
        ._versionchange_ => return error.InvalidAccessError, // Can't manually create versionchange
    };

    // Create transaction on backend
    // TODO: Convert storeNames from JS array to Zig slice
    _ = storeNames;
    _ = options;

    const txn = internal.database.transaction(&.{}, backend_mode, .{}) catch |err| {
        return switch (err) {
            error.NotFoundError => error.NotFound,
            error.InvalidStateError => error.InvalidState,
            error.InvalidAccessError => error.InvalidAccessError,
            else => error.InvalidState,
        };
    };

    // Create WebIDL IDBTransaction wrapper
    const txn_instance = interfaces.IDBTransaction.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend transaction reference
    _ = txn;
    // TODO: Connect backend transaction to wrapper

    return txn_instance;
}

/// Operation: createObjectStore
///
/// Creates a new object store in the database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-createobjectstore
///
/// Note: Can only be called during a versionchange transaction.
pub fn call_createObjectStore(instance: *runtime.Instance, name: runtime.DOMString, options: dictionaries.IDBObjectStoreParameters) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Check if we're in a versionchange transaction
    if (internal.database.version_change_transaction == null) {
        return error.InvalidState;
    }

    // Convert DOMString to slice
    const name_slice = name.asSlice();

    // Convert options - keyPath is anyopaque, need to handle it differently
    // TODO: Proper keyPath conversion from JS value
    const backend_options = storage.indexeddb.database.IDBObjectStoreParameters{
        .key_path = null, // TODO: Convert options.keyPath from anyopaque
        .auto_increment = options.autoIncrement orelse false,
    };

    // Create object store on backend
    const store = internal.database.createObjectStore(name_slice, backend_options) catch |err| {
        return switch (err) {
            error.ConstraintError => error.ConstraintError,
            error.InvalidStateError => error.InvalidState,
            error.InvalidAccessError => error.InvalidAccessError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    // Create WebIDL IDBObjectStore wrapper
    const store_instance = interfaces.IDBObjectStore.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend object store reference
    _ = store;
    // TODO: Connect backend store to wrapper

    return store_instance;
}

/// Operation: close
///
/// Closes the database connection.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.database.close();
}

/// Operation: deleteObjectStore
///
/// Deletes an object store from the database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-deleteobjectstore
///
/// Note: Can only be called during a versionchange transaction.
pub fn call_deleteObjectStore(instance: *runtime.Instance, name: runtime.DOMString) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Check if we're in a versionchange transaction
    if (internal.database.version_change_transaction == null) {
        return error.InvalidState;
    }

    // Convert DOMString to slice
    const name_slice = name.asSlice();

    internal.database.deleteObjectStore(name_slice) catch |err| {
        return switch (err) {
            error.NotFoundError => error.NotFound,
            error.InvalidStateError => error.InvalidState,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };
}
