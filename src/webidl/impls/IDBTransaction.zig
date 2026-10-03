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
    task: ?*TransactionTask = null,
    database_generation: u64 = 0,
    registered: bool = false,

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
        if (self.task) |task| task.cancel();
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
    internal.task = null;
    internal.database_generation = 0;
    internal.registered = false;

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
        if (internal.registered) if (internal.database) |database| {
            if (runtime.SlabAllocator.generationOf(database) == internal.database_generation)
                dom.indexeddb.removeDatabaseTransaction(database, instance);
        };
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
    if (internal.task) |task| task.schedule();
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
    if (internal.task) |task| task.schedule();
}

pub fn installHooks() void {
    dom.indexeddb.installTransactions(.{ .end_event = endEvent, .attach = attachTransaction, .finish = finishTransaction, .get_the_parent = getParent, .cleanup = cleanupTransaction, .enqueue = enqueueRequest, .enqueue_internal = enqueueInternal, .outcome = transactionOutcome, .wake = wakeTransaction });
}
fn getParent(instance: *runtime.Instance) ?*runtime.Instance {
    return (instance.getState(State).own._internal orelse return null).database;
}
fn cleanupTransaction(instance: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    // IndexedDB 2.7 cleanup step 2: active -> inactive, and clear cleanup loop.
    if (internal.transaction) |transaction| transaction.setInactive();
    internal.cleanup_list = null;
    if (internal.task) |task| task.schedule();
}

fn attachTransaction(instance: *runtime.Instance, transaction: *BackendTransaction, database: *runtime.Instance) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    std.debug.assert(internal.transaction == null);
    const cleanup_list = dom.indexeddb.agentCleanupList(instance.ctx);
    if (cleanup_list) |list| try list.add(instance);
    errdefer if (cleanup_list) |list| list.remove(instance);
    try dom.indexeddb.registerDatabaseTransaction(database, instance);
    errdefer dom.indexeddb.removeDatabaseTransaction(database, instance);
    const task = try TransactionTask.create(instance, transaction);
    internal.cleanup_list = cleanup_list;
    internal.transaction = transaction;
    internal.database = database;
    internal.database_generation = runtime.SlabAllocator.generationOf(database);
    internal.registered = true;
    internal.task = task;
    engine.traceChild(instance, database, .{ .name = "idb.database" });
    task.schedule();
}
fn finishTransaction(instance: *runtime.Instance, abort: bool) !bool {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const transaction = internal.transaction orelse return error.InvalidStateError;
    // Aborting an upgrade 5.8 and committing 5.4: dispatch after state is finished.
    const aborted = abort or internal.aborted or transaction.err != null;
    internal.aborted = aborted;
    if (internal.finish_event_fired) return !aborted;
    if (transaction.state != .finished) {
        if (aborted) try transaction.abortForError(transaction.err orelse error.AbortError) else try transaction.commit();
    }
    if (transaction.mode == .versionchange) dom.indexeddb.endUpgrade(internal.database.?);
    internal.finish_event_fired = true;
    const event = try interfaces.Event.call_constructor(instance.ctx, runtime.DOMString.initInterned(if (aborted) "abort" else "complete"), @import("webidl").Opt(dictionaries.EventInit).passed(.{ .bubbles = aborted }));
    const root = try engine.retainValue(instance.ctx, .{ .instance = event });
    defer root.release();
    var did_throw = false;
    const running_task = internal.task;
    _ = try dom.fire_event.dispatchTrustedWithThrows(instance, event, &did_throw);
    if (running_task) |task| if (task.cancelled) return !aborted;
    if (!instance.ctx.hasEngine()) return !aborted;
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
    if (internal.task) |task| task.schedule();
    return internal.aborted;
}

fn transactionOutcome(instance: *runtime.Instance) ?bool {
    const internal = instance.getState(State).own._internal orelse return false;
    return if (internal.finish_event_fired) !internal.aborted else null;
}
fn wakeTransaction(instance: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    if (internal.task) |task| task.schedule();
}

fn enqueueRequest(instance: *runtime.Instance, source: *runtime.Instance, operation: dom.indexeddb.Operation, reused: ?*runtime.Instance) !*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const transaction = internal.transaction orelse return error.InvalidStateError;
    // ED 5.6 steps 1-4: accept now, even if scheduling prevents execution yet.
    if (transaction.state != .active) return error.TransactionInactiveError;
    const task = internal.task orelse return error.InvalidStateError;
    try task.pending.ensureUnusedCapacity(task.allocator, 1);
    // ED 5.6 step 3 creates a request in the current realm; ED 4.9 captures
    // that realm again when iteration reuses a request from another realm.
    const realm = operation.target_realm orelse engine.currentRealm() orelse instance.ctx;
    var captured = operation;
    captured.target_realm = realm;
    const request = reused orelse try interfaces.IDBRequest.init(realm.allocator, realm);
    errdefer if (reused == null and !engine.hasWrapper(request)) runtime.Instance.deinit(request);
    const root = try engine.retainValue(instance.ctx, .{ .instance = request });
    errdefer root.release();
    const cursor_root = if (operation.cursor) |cursor| try engine.retainValue(instance.ctx, .{ .instance = cursor }) else null;
    errdefer if (cursor_root) |held| held.release();
    dom.indexeddb.setRequestTransaction(request, instance);
    dom.indexeddb.setRequestSource(request, source);
    dom.indexeddb.setRequestPending(request);
    task.pending.appendAssumeCapacity(.{ .source = source, .request = request, .request_realm = request.ctx, .root = root, .cursor_root = cursor_root, .operation = captured });
    task.schedule();
    return request;
}

fn enqueueInternal(instance: *runtime.Instance, source: *runtime.Instance, operation: dom.indexeddb.Operation) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const transaction = internal.transaction orelse return error.InvalidStateError;
    if (transaction.state != .active) return error.TransactionInactiveError;
    const task = internal.task orelse return error.InvalidStateError;
    try task.pending.ensureUnusedCapacity(task.allocator, 1);
    const root = try engine.retainValue(instance.ctx, .{ .instance = source });
    var captured = operation;
    // Index population has no script result; its clone uses the source realm.
    captured.target_realm = source.ctx;
    task.pending.appendAssumeCapacity(.{ .source = source, .request = null, .root = root, .operation = captured });
    task.schedule();
}

/// Pending activity roots last through the task's microtask checkpoint. They
/// never store a request result; script results belong to traced owner slots.
const TransactionTask = struct {
    allocator: std.mem.Allocator,
    instance: *runtime.Instance,
    backend: *BackendTransaction,
    root: ?engine.Owned,
    pending: std.ArrayList(Work) = .empty,
    current: ?Work = null,
    queued: bool = false,
    running: bool = false,
    cancelled: bool = false,
    finished: bool = false,

    const Work = struct {
        source: *runtime.Instance,
        request: ?*runtime.Instance,
        // Retirement may destroy the request wrapper even while its task is
        // rooted. Inspect the inert Context before dereferencing that wrapper.
        request_realm: ?runtime.Context = null,
        root: engine.Owned,
        cursor_root: ?engine.Owned = null,
        operation: dom.indexeddb.Operation,
        fn deinit(self: *Work) void {
            self.operation.deinit();
            if (self.cursor_root) |root| root.release();
            self.root.release();
        }
    };

    fn create(instance: *runtime.Instance, backend: *BackendTransaction) !*TransactionTask {
        const allocator = instance.ctx.allocator;
        if (instance.ctx.getOptionalEventLoop() == null) return error.NoEventLoop;
        const task = try allocator.create(TransactionTask);
        errdefer allocator.destroy(task);
        const root = try engine.retainValue(instance.ctx, .{ .instance = instance });
        backend.retain();
        task.* = .{ .allocator = allocator, .instance = instance, .backend = backend, .root = root };
        return task;
    }
    fn schedule(self: *TransactionTask) void {
        if (self.queued or self.running or self.cancelled or self.finished) return;
        if (self.backend.state != .finished and !self.backend.canStart()) return;
        const loop = self.instance.ctx.getOptionalEventLoop() orelse return;
        self.queued = true;
        loop.queueTask(.{ .callback = run, .context = self, .drop = drop });
    }
    fn run(data: ?*anyopaque) void {
        const self: *TransactionTask = @ptrCast(@alignCast(data.?));
        self.queued = false;
        if (self.cancelled) return self.destroy();
        if (!self.instance.ctx.hasEngine()) return self.cancel();
        self.running = true;
        var realm = self.instance.ctx;
        if (self.pending.items.len != 0) if (self.pending.items[0].request_realm) |request_realm| {
            if (request_realm.hasEngine()) realm = request_realm;
        };
        engine.runTaskInRealm(realm, steps, self) catch {};
        // A listener or its microtasks may have retired the realm and cancelled
        // this task. Never inspect the wrapper after that cancellation.
        if (self.current) |work| {
            self.current = null;
            var completed = work;
            completed.deinit();
        }
        self.running = false;
        if (self.cancelled) return self.destroy();
        if (!self.instance.ctx.hasEngine()) return self.cancel();
        if (self.finished) {
            if (self.instance.getState(State).own._internal) |internal| {
                internal.task = null;
                dom.indexeddb.removeDatabaseTransaction(internal.database.?, self.instance);
                internal.registered = false;
                dom.indexeddb.databaseTransactionFinished(internal.database.?);
            }
            return self.destroy();
        }
        if (self.pending.items.len != 0 or self.backend.state != .active) self.schedule();
    }
    fn steps(data: ?*anyopaque) void {
        const self: *TransactionTask = @ptrCast(@alignCast(data.?));
        self.perform() catch |err| {
            if (!self.cancelled and self.instance.ctx.hasEngine()) self.abortWithName(@errorName(err)) catch {};
        };
    }
    fn perform(self: *TransactionTask) !void {
        if (self.backend.state != .finished and !self.backend.canStart()) return;
        const internal = self.instance.getState(State).own._internal orelse return error.InvalidStateError;
        if (self.pending.items.len == 0) {
            if (self.backend.state == .active) return;
            _ = try finishTransaction(self.instance, internal.aborted);
            if (!self.cancelled) self.finished = true;
            return;
        }
        // ED 5.6.5: execute FIFO; remove the request before dispatch so a cursor
        // can place the same request again from its success event.
        self.current = self.pending.orderedRemove(0);
        const work = &self.current.?;
        // Retired request globals run no script. The task still releases the
        // operation and its roots after this queued step returns.
        if (work.request_realm) |request_realm| if (!request_realm.hasEngine()) return;
        if (internal.aborted) {
            const request = work.request orelse return;
            const exception = try makeException(request, "AbortError");
            try dom.indexeddb.completeRequest(request, .jsUndefined, exception);
            try self.dispatch(request, true);
            return;
        }
        if (!work.operation.target_realm.?.hasEngine()) {
            // Deviation (integrator Q22, 2026-10-03): when only the result
            // realm retired, leave this request without an event. ED 6.2 /
            // 6.7 use ! StructuredDeserialize and define no failure branch;
            // the engine cannot yet reconstruct a value in that dead realm.
            return;
        }
        try self.backend.beginRequestExecution();
        const execution = if (work.request) |request| dom.indexeddb.executeRequest(work.source, request, &work.operation) else dom.indexeddb.executeInternal(work.source);
        self.backend.endRequestExecution();
        execution catch |err| {
            const request = work.request orelse return self.abortWithName(@errorName(err));
            // 5.6.5.3: an error after explicit commit aborts, regardless of an
            // error listener's eventual preventDefault().
            if (self.backend.state == .committing) try self.abortWithName(@errorName(err));
            const exception = try makeException(request, if (internal.aborted) "AbortError" else @errorName(err));
            try dom.indexeddb.completeRequest(request, .jsUndefined, exception);
            try self.dispatch(request, true);
            return;
        };
        if (work.request) |request| try self.dispatch(request, false);
    }
    fn dispatch(self: *TransactionTask, request: *runtime.Instance, is_error: bool) !void {
        const realm = self.current.?.request_realm.?;
        if (!realm.hasEngine()) return;
        // ED 5.9/5.10 steps 1-7: only inactive transactions become active.
        const event = try interfaces.Event.call_constructor(realm, runtime.DOMString.initInterned(if (is_error) "error" else "success"), @import("webidl").Opt(dictionaries.EventInit).passed(.{ .bubbles = is_error, .cancelable = is_error }));
        const root = try engine.retainValue(realm, .{ .instance = event });
        defer root.release();
        if (self.backend.state == .inactive) self.backend.state = .active;
        var did_throw = false;
        const uncancelled = try dom.fire_event.dispatchTrustedWithThrows(request, event, &did_throw);
        if (self.cancelled or !self.instance.ctx.hasEngine()) return;
        if (self.backend.state == .active) {
            self.backend.setInactive();
            if (!realm.hasEngine()) return;
            // Steps 8.2-4: exceptions take precedence over request errors.
            if (did_throw) return self.abortWithName("AbortError");
            if (is_error and uncancelled) {
                const exception = try interfaces.IDBRequest.get_error(request);
                const internal = self.instance.getState(State).own._internal.?;
                internal.exception = exception;
                if (exception) |child| engine.traceChild(self.instance, child, .{ .name = "idb.error" });
                internal.aborted = true;
                try self.backend.abortForError(error.AbortError);
            }
            if (self.backend.state != .finished and self.pending.items.len == 0) self.backend.state = .committing;
        }
    }
    fn abortWithName(self: *TransactionTask, name: []const u8) !void {
        const internal = self.instance.getState(State).own._internal orelse return;
        if (self.backend.state == .finished) return;
        internal.exception = try makeException(self.instance, name);
        engine.traceChild(self.instance, internal.exception.?, .{ .name = "idb.error" });
        internal.aborted = true;
        try self.backend.abortForError(error.AbortError);
    }
    fn drop(data: ?*anyopaque) void {
        const self: *TransactionTask = @ptrCast(@alignCast(data.?));
        self.queued = false;
        self.cancel();
    }
    fn cancel(self: *TransactionTask) void {
        if (!self.cancelled) {
            self.cancelled = true;
            if (self.instance.getState(State).own._internal) |internal| {
                if (internal.task == self) internal.task = null;
            }
            if (self.backend.state != .finished) self.backend.abortForError(error.AbortError) catch {};
            if (self.root) |root| root.release();
            self.root = null;
        }
        if (!self.queued and !self.running) self.destroy();
    }
    fn destroy(self: *TransactionTask) void {
        // Releasing pending roots can synchronously destroy wrappers. This
        // task is detached before that starts and remains its own last holder.
        self.running = true;
        for (self.pending.items) |*work| work.deinit();
        self.pending.deinit(self.allocator);
        if (self.current) |*work| work.deinit();
        if (self.root) |root| root.release();
        self.backend.deinit();
        self.allocator.destroy(self);
    }
};

fn makeException(instance: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.DOMException.call_constructor(instance.ctx, @import("webidl").Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(name)), @import("webidl").Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(name)));
}
