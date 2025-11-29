//! Implementation for IDBTransaction interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/transaction.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbtransaction
//!
//! IDBTransaction represents a transaction on a database. It provides methods to:
//! - Access object stores within the transaction scope
//! - Commit or abort the transaction

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IDBTransactionInterface = interfaces.IDBTransaction;

// Backend imports
const storage = @import("storage");
const BackendTransaction = storage.indexeddb.IDBTransaction;
const BackendTransactionMode = storage.indexeddb.IDBTransactionMode;

pub const State = IDBTransactionInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    NotFound,
    TransactionInactiveError,
    InvalidAccessError,
};

/// Internal state for IDBTransaction
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend transaction (set by IDBDatabase.transaction())
    transaction: ?*BackendTransaction,

    /// Parent database instance
    database: ?*runtime.Instance,

    /// Event handlers
    onabort: typedefs.EventHandler,
    oncomplete: typedefs.EventHandler,
    onerror: typedefs.EventHandler,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.transaction) |txn| {
            txn.deinit();
            allocator.destroy(txn);
        }
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
    internal.database = null;

    // Transaction pointer is set by IDBDatabase.transaction() - start as null
    internal.transaction = null;

    // Initialize event handlers
    internal.onabort = null;
    internal.oncomplete = null;
    internal.onerror = null;

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

/// Getter for objectStoreNames
///
/// Returns a DOMStringList of object store names in this transaction's scope.
pub fn get_objectStoreNames(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    // Get scope from backend
    _ = txn.scope;

    // TODO: Create DOMStringList from scope
    return error.InvalidState; // Placeholder until DOMStringList is wired up
}

/// Getter for mode
///
/// Returns the mode of the transaction (readonly, readwrite, or versionchange).
pub fn get_mode(instance: *runtime.Instance) ImplError!enums.IDBTransactionMode {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    return switch (txn.mode) {
        .readonly => ._readonly_,
        .readwrite => ._readwrite_,
        .versionchange => ._versionchange_,
    };
}

/// Getter for durability
///
/// Returns the durability hint for the transaction.
pub fn get_durability(instance: *runtime.Instance) ImplError!enums.IDBTransactionDurability {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    return switch (txn.durability) {
        .default => ._default_,
        .strict => ._strict_,
        .relaxed => ._relaxed_,
    };
}

/// Getter for db
///
/// Returns the database this transaction belongs to.
pub fn get_db(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return internal.database orelse error.InvalidState;
}

/// Getter for error
///
/// Returns the error that caused the transaction to abort, if any.
pub fn get_error(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    _ = state.own._internal orelse return error.InvalidState;

    // TODO: Track transaction error and return DOMException wrapper
    // Currently the backend doesn't store the error that caused abort
    return null;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onabort;
}

/// Getter for oncomplete
pub fn get_oncomplete(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.oncomplete;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onerror;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onabort = value;
}

/// Setter for oncomplete
pub fn set_oncomplete(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.oncomplete = value;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onerror = value;
}

/// Operation: objectStore
///
/// Returns an object store in the transaction's scope.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbtransaction-objectstore
pub fn call_objectStore(instance: *runtime.Instance, name: runtime.DOMString) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    const name_slice = name.asSlice();

    // Get object store from transaction
    const store = txn.objectStore(name_slice) catch |err| {
        return switch (err) {
            error.NotFoundError => error.NotFound,
            error.InvalidStateError => error.InvalidState,
            else => error.InvalidState,
        };
    };

    // Create WebIDL IDBObjectStore wrapper
    const store_instance = interfaces.IDBObjectStore.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend reference
    _ = store;
    // TODO: Connect backend store to wrapper

    return store_instance;
}

/// Operation: commit
///
/// Commits the transaction.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbtransaction-commit
pub fn call_commit(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    txn.commit() catch |err| {
        return switch (err) {
            error.InvalidStateError => error.InvalidState,
            else => error.InvalidState,
        };
    };
}

/// Operation: abort
///
/// Aborts the transaction.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbtransaction-abort
pub fn call_abort(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    txn.abort() catch |err| {
        return switch (err) {
            error.InvalidStateError => error.InvalidState,
            else => error.InvalidState,
        };
    };
}
