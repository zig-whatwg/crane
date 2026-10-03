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
const dom = @import("dom");
const engine = @import("engine");
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
    cleanup_list: ?*dom.indexeddb.CleanupList = null,
    aborted: bool = false,
    finish_event_fired: bool = false,
    exception: ?*runtime.Instance = null,
    store_wrappers: std.ArrayListUnmanaged(StoreWrapper) = .empty,

    /// Event handlers
    onabort: typedefs.EventHandler,
    oncomplete: typedefs.EventHandler,
    onerror: typedefs.EventHandler,

    const StoreWrapper = struct {
        store: *storage.indexeddb.IDBObjectStore,
        instance: *runtime.Instance,
        slot: []const u8,
    };

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.transaction) |txn| {
            txn.releaseHeapOwnership();
        }
        for (self.store_wrappers.items) |wrapper| allocator.free(wrapper.slot);
        self.store_wrappers.deinit(allocator);
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
    const instance = try interfaces.EventTarget.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);

    // Create internal state
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.database = null;
    internal.cleanup_list = null;
    internal.aborted = false;
    internal.finish_event_fired = false;
    internal.exception = null;
    internal.store_wrappers = .empty;

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
        if (internal.cleanup_list) |list| list.remove(instance);
        engine.forgetTracedChild(instance, .{ .name = "idb.error" });
        engine.forgetTracedChild(instance, .{ .name = "idb.database" });
        for (internal.store_wrappers.items) |wrapper|
            engine.forgetTracedChild(instance, .{ .name = wrapper.slot });
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    interfaces.EventTarget.deinit(instance);
}

/// Getter for objectStoreNames
///
/// Returns a DOMStringList of object store names in this transaction's scope.
pub fn get_objectStoreNames(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    // Upgrade scope tracks stores in its connection; every returned list is new.
    if (txn.mode == .versionchange) {
        const names = try txn.db.objectStoreNames();
        defer txn.allocator.free(names);
        return dom.string_lists.create(instance.ctx, names);
    }
    const names = try internal.allocator.dupe([]const u8, txn.scope);
    defer internal.allocator.free(names);
    std.mem.sort([]const u8, names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return storage.indexeddb.key.compareStrings(a, b) < 0;
        }
    }.lessThan);
    return dom.string_lists.create(instance.ctx, names);
}

/// Getter for mode
///
/// Returns the mode of the transaction (readonly, readwrite, or versionchange).
pub fn get_mode(instance: *runtime.Instance) anyerror!enums.IDBTransactionMode {
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
pub fn get_durability(instance: *runtime.Instance) anyerror!enums.IDBTransactionDurability {
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
pub fn get_db(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return internal.database orelse error.InvalidState;
}

/// Getter for error
///
/// Returns the error that caused the transaction to abort, if any.
pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return (instance.getState(State).own._internal orelse return error.InvalidStateError).exception;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "abort");
}

/// Getter for oncomplete
pub fn get_oncomplete(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "complete");
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return dom.event_handlers.get(typedefs.EventHandler, instance, "error");
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "abort", value);
}

/// Setter for oncomplete
pub fn set_oncomplete(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "complete", value);
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try dom.event_handlers.set(typedefs.EventHandler, instance, "error", value);
}

/// Operation: objectStore
///
/// Returns an object store in the transaction's scope.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbtransaction-objectstore
pub fn call_objectStore(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    const name_slice = name.asSlice();

    // objectStore steps 1-2: the native handle validates finished state and scope.
    const store = try txn.objectStore(name_slice);
    // Step 3: one handle per store and transaction, kept by a traced edge.
    for (internal.store_wrappers.items) |wrapper|
        if (wrapper.store == store) return wrapper.instance;
    try internal.store_wrappers.ensureUnusedCapacity(internal.allocator, 1);
    const slot = try std.fmt.allocPrint(internal.allocator, "idb.store.{d}", .{internal.store_wrappers.items.len});
    errdefer internal.allocator.free(slot);
    const store_instance = try interfaces.IDBObjectStore.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(store_instance);
    try dom.indexeddb.attachStore(store_instance, store, instance, false);
    internal.store_wrappers.appendAssumeCapacity(.{ .store = store, .instance = store_instance, .slot = slot });
    engine.traceChild(instance, store_instance, .{ .name = slot });
    return store_instance;
}

/// Operation: commit
///
/// Commits the transaction.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbtransaction-commit
pub fn call_commit(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    // IDL commit step 1: only active; outstanding requests finish asynchronously.
    if (txn.state != .active) return error.InvalidStateError;
    txn.state = .committing;
}

/// Operation: abort
///
/// Aborts the transaction.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbtransaction-abort
pub fn call_abort(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const txn = internal.transaction orelse return error.InvalidState;

    if (txn.state == .committing or txn.state == .finished) return error.InvalidStateError;
    try txn.abort();
    internal.aborted = true;
    // Aborting with null leaves transaction.error null.
    txn.err = null;
}

pub fn installHooks() void {
    dom.indexeddb.installTransactions(.{ .end_event = endEvent, .attach = attachTransaction, .finish = finishTransaction, .get_the_parent = getParent, .cleanup = cleanupTransaction });
}
fn getParent(instance: *runtime.Instance) ?*runtime.Instance {
    return (instance.getState(State).own._internal orelse return null).database;
}
fn cleanupTransaction(instance: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    // IndexedDB 2.7 cleanup step 2: active -> inactive, and clear cleanup loop.
    if (internal.transaction) |transaction| transaction.setInactive();
    internal.cleanup_list = null;
}

fn attachTransaction(instance: *runtime.Instance, transaction: *BackendTransaction, database: *runtime.Instance) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    std.debug.assert(internal.transaction == null);
    const cleanup_list = dom.indexeddb.agentCleanupList(instance.ctx);
    if (cleanup_list) |list| try list.add(instance);
    internal.cleanup_list = cleanup_list;
    internal.transaction = transaction;
    internal.database = database;
    engine.traceChild(instance, database, .{ .name = "idb.database" });
}
fn finishTransaction(instance: *runtime.Instance, abort: bool) !bool {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const transaction = internal.transaction orelse return error.InvalidStateError;
    // Aborting an upgrade 5.8 and committing 5.4: dispatch after state is finished.
    const aborted = abort or internal.aborted or transaction.err != null;
    internal.aborted = aborted;
    if (internal.finish_event_fired) return !aborted;
    if (transaction.state != .finished) {
        if (aborted) try transaction.abort() else try transaction.commit();
    }
    if (transaction.mode == .versionchange) dom.indexeddb.endUpgrade(internal.database.?);
    internal.finish_event_fired = true;
    const event = try interfaces.Event.call_constructor(instance.ctx, runtime.DOMString.initInterned(if (aborted) "abort" else "complete"), @import("webidl").Opt(dictionaries.EventInit).passed(.{ .bubbles = aborted }));
    const root = try engine.retainValue(instance.ctx, .{ .instance = event });
    defer root.release();
    var did_throw = false;
    _ = try dom.fire_event.dispatchTrustedWithThrows(instance, event, &did_throw);
    dom.indexeddb.closeConnectionIfReady(internal.database.?);
    return !aborted;
}

fn endEvent(instance: *runtime.Instance, did_throw: bool) !bool {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const transaction = internal.transaction orelse return error.InvalidStateError;
    // 5.7 step 10.6: only an active transaction is deactivated/aborted.
    if (transaction.state == .active) {
        transaction.setInactive();
        if (did_throw) {
            internal.exception = try interfaces.DOMException.call_constructor(instance.ctx, @import("webidl").Opt(runtime.DOMString).passed(runtime.DOMString.initInterned("An upgrade listener threw")), @import("webidl").Opt(runtime.DOMString).passed(runtime.DOMString.initInterned("AbortError")));
            engine.traceChild(instance, internal.exception.?, .{ .name = "idb.error" });
            internal.aborted = true;
            try transaction.abort();
        }
    }
    return internal.aborted;
}
