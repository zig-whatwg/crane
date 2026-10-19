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
const engine = @import("engine");
const dom = @import("dom");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IDBFactoryInterface = interfaces.IDBFactory;

// Backend imports
const storage = @import("storage");
const IDBServer = storage.indexeddb.IDBServer;
const server_mod = storage.indexeddb.server;
const StorageKey = storage.StorageKey;

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
/// IndexedDB storage is the Browser's: its IDBServer (a BrowserScope
/// supplement, src/storage/indexeddb/server.zig) holds every database, its
/// connection queue, connection set and transaction scheduler, shared by
/// every agent and thread of the Browser. A factory keeps only its own
/// requests' tasks.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The Browser's IndexedDB server.
    server: *IDBServer,
    pending: std.ArrayList(*ConnectionTask) = .empty,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Realm teardown (a window's unload, a worker's end) can destroy the
        // factory while requests await their turn or a close. Cancel owned
        // pending activity without enqueueing into the dying realm; each
        // request leaves the server's queue (one mid-upgrade keeps the head
        // until its upgrade transaction is rolled back).
        while (self.pending.items.len != 0) {
            const task = self.pending.pop().?;
            task.registered = false;
            task.cancel();
        }
        self.pending.deinit(allocator);
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
    // What deinit reads, should anything below fail: the errdefer above runs
    // it, and an `_internal` never set read garbage (a failed allocation of
    // the state below crashed in deinit).
    state.own._internal = null;

    // The Browser's server, made on first use (a realm with no Browser
    // scope makes no platform object at all).
    const server = dom.indexeddb.serverOf(ctx) orelse return error.InvalidStateError;

    // Create internal state - this call's until it is complete, then deinit's.
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .server = server };

    state.own._internal = internal;
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
    // Q37: ED 4.3 passes no current Realm; factory objects use this factory's relevant realm.
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Version 0 is invalid per spec - unwrap Opt
    const version_val: ?u64 = if (version.wasPassed()) version.value else null;
    if (version_val != null and version_val.? == 0) {
        return error.TypeError;
    }

    // Steps 2-6: obtain the relevant storage key, enqueue, return pending request.
    _ = internal;
    var storage_key = try storageKey(instance);
    defer storage_key.deinit();
    return enqueueConnection(instance, storage_key, name.asSlice(), version_val, false);
}

/// Operation: databases
///
/// Returns a Promise that resolves to a sequence of IDBDatabaseInfo dictionaries.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-databases
pub fn call_databases(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // See call_open for the factory-realm rule (integrator Q37).
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const realm = instance.ctx;
    // Steps 1-2: opaque settings origins reject a new promise, never throw synchronously.
    var storage_key = storageKey(instance) catch |err| {
        if (err != error.SecurityError) return err;
        const reason = try engine.createDOMException(realm, "SecurityError", "The storage origin is opaque");
        defer reason.release();
        return (try engine.createRejectedPromise(realm, reason.value)).take();
    };
    defer storage_key.deinit();
    // Step 4.2: the names and versions of the storage key's databases, read
    // under the server's lock and copied out.
    const db_list = try internal.server.databaseInfos(storage_key, internal.allocator);
    defer server_mod.freeInfos(internal.allocator, db_list);

    // Step 4.2-3: take a snapshot as IDBDatabaseInfo dictionaries. Each
    // dictionary is held until the array has taken its references.
    const values = try internal.allocator.alloc(runtime.JSValue, db_list.len);
    defer internal.allocator.free(values);
    var made: usize = 0;
    defer for (values[0..made]) |value| (engine.Owned{ .value = value }).release();
    for (db_list) |db| {
        // Step 4.3.1: newly created, uncommitted databases are omitted.
        if (db.version == 0) continue;
        const dictionary = try engine.createDictionaryObject(realm, &.{
            .{ .name = "name", .value = runtime.JSValue.fromStringRef(db.name) },
            .{ .name = "version", .value = runtime.JSValue.fromNumber(@floatFromInt(db.version)) },
        });
        values[made] = dictionary.take();
        made += 1;
    }
    const snapshot = try engine.createSequenceOfValues(realm, values[0..made]);
    errdefer snapshot.release();

    // Step 3 and 4.4: return a new promise, resolved from a database task.
    var capability = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&capability);
    const promise = try engine.retainValue(realm, capability.promise);
    errdefer promise.release();
    const task = try realm.allocator.create(DatabasesTask);
    errdefer realm.allocator.destroy(task);
    task.* = .{ .realm = realm, .capability = capability, .snapshot = snapshot };
    _ = dom.indexeddb.queueDatabaseTask(realm, .{ .callback = DatabasesTask.run, .context = task, .drop = DatabasesTask.drop }) catch {
        // Without a queue, reject the returned promise; never run the
        // database-access task synchronously or leave its promise pending.
        const reason = try engine.createDOMException(realm, "UnknownError", "The database task could not be queued");
        defer reason.release();
        try engine.rejectPromise(&capability, reason.value);
        task.finish();
        return promise.take();
    };
    return promise.take();
}

/// The promise and snapshot stay owned by their task through script and its
/// microtasks. A queued task dropped by realm teardown releases them too.
const DatabasesTask = struct {
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    snapshot: engine.Owned,

    fn run(context: ?*anyopaque) void {
        const self: *DatabasesTask = @ptrCast(@alignCast(context.?));
        defer self.finish();
        if (self.realm.hasEngine()) {
            engine.runTaskInRealm(self.realm, steps, self) catch {};
        }
    }

    fn steps(data: ?*anyopaque) void {
        const self: *DatabasesTask = @ptrCast(@alignCast(data.?));
        engine.resolvePromise(&self.capability, self.snapshot.value) catch {};
    }

    fn drop(context: ?*anyopaque) void {
        const self: *DatabasesTask = @ptrCast(@alignCast(context.?));
        self.finish();
    }

    fn finish(self: *DatabasesTask) void {
        self.snapshot.release();
        engine.releasePromiseCapability(&self.capability);
        self.realm.allocator.destroy(self);
    }
};

/// Operation: deleteDatabase
///
/// Deletes a database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-deletedatabase
///
/// Returns an IDBOpenDBRequest that fires success when the database is deleted.
pub fn call_deleteDatabase(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*runtime.Instance {
    // See call_open for the factory-realm rule (integrator Q37).
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Steps 1-5: the queue performs deletion only after existing connections close.
    _ = internal;
    var storage_key = try storageKey(instance);
    defer storage_key.deinit();
    return enqueueConnection(instance, storage_key, name.asSlice(), null, true);
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

    // Steps 1-4: invalid conversion results are DataError; abrupt completions propagate.
    var a = try dom.indexeddb_keys.require(instance.ctx, first, instance.ctx.allocator);
    defer a.deinit();
    var b = try dom.indexeddb_keys.require(instance.ctx, second, instance.ctx.allocator);
    defer b.deinit();
    // Step 5.
    return storage.indexeddb.compareKeys(a, b);
}

pub fn installHooks() void {
    dom.indexeddb.installFactories(.{ .wake_transactions = wakeTransactions });
    // A document's unload or destruction, or a worker's end, closes the
    // connections made in it (IndexedDB 2.? connection).
    dom.unloading_cleanup.install(dom.indexeddb.environmentEnded);
}

/// An upgrade transaction of this factory's agent finished: its open
/// request's final task may run (ED 5.7 step 11's wait ends).
fn wakeTransactions(instance: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    var index: usize = 0;
    while (index < internal.pending.items.len) {
        const task = internal.pending.items[index];
        if (task.phase == .commit or task.phase == .failed) task.schedule() catch task.failScheduling();
        // A queue failure removes this entry and may advance following ones.
        if (index < internal.pending.items.len and internal.pending.items[index] == task) index += 1;
    }
}

/// Storage "obtain a storage key" for the factory's relevant settings
/// object (IndexedDB 4.3 open() step 2, deleteDatabase() step 2, databases()
/// step 2): the ONE place IndexedDB obtains its key -
/// dom.global_settings.storageKeyOf, (origin, top-level site, has
/// cross-site ancestor), so IndexedDB is partitioned as Web Storage is.
/// Failure (an opaque origin or top-level site) is SecurityError. OWNED by
/// the caller.
fn storageKey(instance: *runtime.Instance) !StorageKey {
    const realm = instance.ctx.getRealm() orelse return error.SecurityError;
    const global: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return error.SecurityError));
    // Borrowed from the global (a worker's cached key): copied to keep.
    const key = (try dom.global_settings.storageKeyOf(global)) orelse return error.SecurityError;
    return key.clone(instance.ctx.allocator);
}

fn enqueueConnection(factory: *runtime.Instance, storage_key: StorageKey, name: []const u8, version: ?u64, deletion: bool) !*runtime.Instance {
    const internal = factory.getState(State).own._internal orelse return error.InvalidStateError;
    const server = internal.server;
    const request = try interfaces.IDBOpenDBRequest.init(internal.allocator, factory.ctx);
    errdefer if (!engine.hasWrapper(request)) runtime.Instance.deinit(request);
    const factory_root = try engine.retainValue(factory.ctx, .{ .instance = factory });
    errdefer factory_root.release();
    const request_root = try engine.retainValue(factory.ctx, .{ .instance = request });
    errdefer request_root.release();
    // ED 2.8.2: the queue of (storage key, name) - the Browser's, shared
    // with every other agent and thread.
    const database = try server.uniqueDatabase(storage_key, name);
    errdefer server.release(database);
    const task = try internal.allocator.create(ConnectionTask);
    errdefer internal.allocator.destroy(task);
    task.* = .{ .allocator = internal.allocator, .factory = factory, .realm = factory.ctx, .request = request, .factory_root = factory_root, .request_root = request_root, .server = server, .database = database, .version = version, .deletion = deletion };
    try internal.pending.ensureUnusedCapacity(internal.allocator, 1);
    const queued = try server.enqueue(database, dom.indexeddb.endpointOf(factory.ctx), .{ .context = task, .call = ConnectionTask.serverNote });
    task.entry = queued.id;
    internal.pending.appendAssumeCapacity(task);
    task.registered = true;
    if (queued.head) task.schedule() catch |err| {
        _ = internal.pending.pop();
        task.registered = false;
        server.withdraw(database, queued.id);
        return err;
    };
    return request;
}

/// ED 2.8.2 connection queue, 5.1 opening, 5.3 deleting, and 5.7 upgrading.
/// Pending activity roots belong to this operation, and end after its script
/// and microtasks, or when realm teardown drops the queued task.
///
/// The queue, the connections it waits on and the version are the Browser's
/// server's (server.zig); this task holds its request's entry there by id
/// and runs the request's steps as database tasks of its own realm. The
/// server tells it `advance` - on this thread, directly or by a task of this
/// agent's sink - when it reaches the head, when its versionchange events
/// have been acknowledged, and when the last connection it waits on closes.
const ConnectionTask = struct {
    allocator: std.mem.Allocator,
    cancelled: bool = false,
    roots_released: bool = false,
    factory: *runtime.Instance,
    // The factory, request and newly created connection/upgrade wrappers
    // all belong to this realm. The Context remains inert after retirement.
    realm: runtime.Context,
    request: *runtime.Instance,
    factory_root: engine.Owned,
    request_root: engine.Owned,
    server: *IDBServer,
    /// Held (`server.release` at destroy).
    database: *server_mod.UniqueIDBDatabase,
    /// The request's queue entry; 0 once it left the queue.
    entry: server_mod.Id = 0,
    version: ?u64,
    deletion: bool,
    old_version: u64 = 0,
    /// The version rises (or this is a deletion): connections are told and
    /// waited on (5.1 step 10 / 5.3 steps 5-7).
    change: bool = false,
    phase: enum { start, notify, blocked, wait, upgrade, commit, success, failed, error_event, finished } = .start,
    /// Connections on this thread to tell versionchange, by id, one per
    /// task (5.1 step 10.2); those of other threads were told by the server.
    local_notifications: []server_mod.Id = &.{},
    next_notification: usize = 0,
    /// Waiting for the server's `advance` (acknowledgements, or closes): no
    /// task until it comes.
    parked: bool = false,
    database_instance: ?*runtime.Instance = null,
    database_root: ?engine.Owned = null,
    transaction: ?*runtime.Instance = null,
    transaction_root: ?engine.Owned = null,
    queued: bool = false,
    queued_task: dom.indexeddb.DatabaseTaskHandle = .{},
    running: bool = false,
    blocked_fired: bool = false,
    registered: bool = false,

    fn internal(self: *ConnectionTask) *InternalState {
        return self.factory.getState(State).own._internal.?;
    }
    /// The server's note for this request's entry, on this thread.
    fn serverNote(context: *anyopaque, note: server_mod.Note) void {
        const self: *ConnectionTask = @ptrCast(@alignCast(context));
        if (note != .advance) return;
        self.parked = false;
        self.schedule() catch self.failScheduling();
    }
    fn schedule(self: *ConnectionTask) !void {
        if (self.queued or self.running or self.cancelled or self.phase == .finished) return;
        if (!self.realm.hasEngine()) return;
        // A closing worker can invoke drop before queueDatabaseTask returns.
        // Give the queue ownership first, and never touch self on success:
        // drop may already have destroyed it.
        self.queued = true;
        _ = dom.indexeddb.queueDatabaseTask(self.realm, .{ .callback = run, .context = self, .drop = drop }) catch |err| {
            // A queue error never calls run/drop, so self is still ours.
            self.queued = false;
            return err;
        };
    }
    fn run(data: ?*anyopaque) void {
        const self: *ConnectionTask = @ptrCast(@alignCast(data.?));
        dom.indexeddb.databaseTaskStarted(&self.queued_task);
        self.queued = false;
        if (self.cancelled) {
            self.destroy();
            return;
        }
        if (!self.realm.hasEngine()) return self.finish(false);
        self.running = true;
        var ran = true;
        engine.runTaskInRealm(self.realm, steps, self) catch {
            // The realm runs no task again - a destroyed document's (HTML
            // "destroy a document" step 7: its tasks are removed without
            // running): the request can never go on. It leaves the queue
            // rather than be queued again for ever.
            ran = false;
        };
        self.running = false;
        // Task ownership extends through runTaskInRealm's checkpoint.
        // Teardown cancels the task before freeing its owning factory. Do not
        // inspect any wrapper after script or its microtasks cancelled it.
        if (self.cancelled) return self.destroy();
        if (!ran or !self.realm.hasEngine()) return self.finish(false);
        if (self.phase == .finished) self.finish(true) else if (self.phase == .commit or self.phase == .failed) {
            if (self.transaction) |transaction| {
                if (dom.indexeddb.transactionOutcome(transaction) != null) self.schedule() catch self.failScheduling();
            }
        } else if (!self.parked) self.schedule() catch self.failScheduling();
    }
    fn failScheduling(self: *ConnectionTask) void {
        // No task source remains to deliver an event. Finish the failed
        // operation's state and release its activity without invoking script.
        self.phase = .finished;
        if (self.realm.hasEngine()) {
            const exception = interfaces.DOMException.call_constructor(self.realm, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned("The database task could not be queued")), webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned("UnknownError"))) catch null;
            dom.indexeddb.completeRequest(self.request, .jsUndefined, exception) catch {};
            if (self.transaction) |transaction| interfaces.IDBTransaction.call_abort(transaction) catch {};
            if (self.database_instance) |database| interfaces.IDBDatabase.call_close(database) catch {};
        }
        self.finish(true);
    }
    fn steps(data: ?*anyopaque) void {
        const self: *ConnectionTask = @ptrCast(@alignCast(data.?));
        self.perform() catch |err| {
            if (!self.cancelled and self.realm.hasEngine()) self.fail(@errorName(err)) catch {};
        };
    }
    fn perform(self: *ConnectionTask) !void {
        switch (self.phase) {
            .start => {
                // Opening steps 5-10.2 / deletion steps 3-5, at the head of
                // the queue: the version decision, and versionchange posted
                // to every other thread's open connection.
                const started = try self.server.start(self.database, self.entry, self.version, self.deletion, self.allocator);
                const proceed = switch (started) {
                    .version_error => return error.VersionError,
                    .proceed => |proceed| proceed,
                };
                self.old_version = proceed.old_version;
                self.version = proceed.new_version;
                self.change = proceed.change;
                self.local_notifications = proceed.local;
                self.phase = if (self.change) .notify else .wait;
            },
            .notify => {
                if (self.next_notification < self.local_notifications.len) {
                    // Step 10.2, a connection on this thread: one database
                    // task each. A connection closed meanwhile is skipped.
                    const id = self.local_notifications[self.next_notification];
                    self.next_notification += 1;
                    if (self.server.versionChangeWanted(self.database, id)) |client| {
                        client.call(client.context, .{ .versionchange = .{ .old_version = self.old_version, .new_version = self.versionForEvent(), .posted = false } });
                    }
                    if (self.cancelled or !self.realm.hasEngine()) return;
                }
                if (self.next_notification == self.local_notifications.len) {
                    // Step 10.3: every other thread's event fired, or wait for
                    // the last acknowledgement to advance this request.
                    if (!self.server.awaitAcknowledgements(self.database, self.entry)) {
                        self.parked = true;
                        return;
                    }
                    // ED 5.1 step 10.4 / 5.3 step 6: decide after the last
                    // notification. A later close cannot retract the blocked
                    // event that this decision queues.
                    self.phase = if (self.server.hasConnections(self.database)) .blocked else .wait;
                }
            },
            .blocked => {
                self.blocked_fired = true;
                self.phase = .wait;
                try self.versionEvent(self.request, "blocked", self.versionForEvent());
            },
            .wait => {
                // Step 10.5 / 5.3 step 7: wait until every connection closed.
                if (self.change and !self.server.awaitCloses(self.database, self.entry)) {
                    if (!self.blocked_fired) {
                        self.blocked_fired = true;
                        try self.versionEvent(self.request, "blocked", self.versionForEvent());
                    }
                    self.parked = true;
                    return;
                }
                if (self.deletion) {
                    // 5.3 steps 8-11: the database goes; success reports its
                    // old version.
                    self.old_version = self.server.deleteDatabase(self.database);
                    try dom.indexeddb.completeRequest(self.request, .jsUndefined, null);
                    try self.versionEvent(self.request, "success", null);
                    self.phase = .finished;
                    return;
                }
                // 5.1 steps 4 and 11: the connection, in this agent; its
                // record in the server names this thread and its sink.
                const opened = self.server.openConnection(self.database, self.version.?, true, self.allocator, dom.indexeddb.endpointOf(self.realm)) catch |err| return self.fail(@errorName(err));
                const database = interfaces.IDBDatabase.init(self.internal().allocator, self.realm) catch |err| {
                    opened.connection.releaseHeapOwnership();
                    return err;
                };
                errdefer if (!engine.hasWrapper(database)) runtime.Instance.deinit(database);
                dom.indexeddb.attachDatabase(database, opened.connection) catch |err| {
                    opened.connection.releaseHeapOwnership();
                    return err;
                };
                dom.indexeddb.setDatabaseFactory(database, self.factory);
                self.database_root = try engine.retainValue(self.realm, .{ .instance = database });
                self.database_instance = database;
                self.phase = if (self.version.? > opened.old_version) .upgrade else .success;
            },
            .upgrade => {
                // 5.7: expose the upgrade transaction and done result before dispatch.
                const transaction = try dom.indexeddb.beginUpgrade(self.database_instance.?);
                errdefer {
                    interfaces.IDBTransaction.call_abort(transaction) catch {};
                    interfaces.IDBDatabase.call_close(self.database_instance.?) catch {};
                }
                // ED 5.4/5.5: hiding request.transaction after complete/abort
                // does not end the opening algorithm's use of this transaction.
                // Keep its wrapper until the final success/error task ends.
                // WebKit's IDBOpenDBRequest retains m_transaction separately
                // from whether that property is exposed to script.
                self.transaction_root = try engine.retainValue(self.realm, .{ .instance = transaction });
                self.transaction = transaction;
                dom.indexeddb.associateUpgradeRequest(transaction, self.request);
                try dom.indexeddb.completeRequest(self.request, .{ .instance = self.database_instance.? }, null);
                dom.indexeddb.setRequestTransaction(self.request, transaction);
                var did_throw = false;
                const event = try self.newVersionEvent("upgradeneeded", self.version);
                const event_root = try engine.retainValue(self.realm, .{ .instance = event });
                defer event_root.release();
                _ = try dom.fire_event.dispatchTrustedWithThrows(self.request, event, &did_throw);
                if (self.cancelled or !self.realm.hasEngine()) return;
                self.phase = if (try dom.indexeddb.endTransactionEvent(transaction, did_throw)) .failed else .commit;
            },
            .failed => {
                if (self.transaction) |transaction| {
                    if (dom.indexeddb.transactionOutcome(transaction) == null) return;
                }
                // ED 5.5 step 7.3 already reset the request after abort dispatch.
                dom.indexeddb.endUpgrade(self.database_instance.?);
                try interfaces.IDBDatabase.call_close(self.database_instance.?);
                self.phase = .error_event;
            },
            .error_event => try self.fail("AbortError"),
            .commit => {
                if (self.transaction) |transaction| {
                    const committed = dom.indexeddb.transactionOutcome(transaction) orelse return;
                    // ED 5.4/5.5 already cleared the association after dispatch.
                    dom.indexeddb.endUpgrade(self.database_instance.?);
                    if (!committed) {
                        try interfaces.IDBDatabase.call_close(self.database_instance.?);
                        self.phase = .error_event;
                        return;
                    }
                }
                if (dom.indexeddb.connectionIsClosing(self.database_instance.?)) {
                    self.phase = .error_event;
                } else try self.succeed();
            },
            .success => try self.succeed(),
            .finished => {},
        }
    }
    fn versionForEvent(self: *ConnectionTask) ?u64 {
        return if (self.deletion) null else self.version;
    }
    fn succeed(self: *ConnectionTask) !void {
        // ED 4.3 open() step 5.3.2 is one database task: set the result and
        // done flag, then fire success. Internal phase bookkeeping must not
        // insert another task between those steps and upgrade completion.
        try dom.indexeddb.completeRequest(self.request, .{ .instance = self.database_instance.? }, null);
        try self.simpleEvent(self.request, "success", false, false);
        self.phase = .finished;
    }
    fn newVersionEvent(self: *ConnectionTask, event_type: []const u8, version: ?u64) !*runtime.Instance {
        return interfaces.IDBVersionChangeEvent.call_constructor(self.realm, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.IDBVersionChangeEventInit).passed(.{ .base = .{}, .oldVersion = self.old_version, .newVersion = version }));
    }
    fn versionEvent(self: *ConnectionTask, target: *runtime.Instance, event_type: []const u8, version: ?u64) !void {
        if (!self.realm.hasEngine()) return;
        const event = try self.newVersionEvent(event_type, version);
        const root = try engine.retainValue(self.realm, .{ .instance = event });
        defer root.release();
        _ = try dom.fire_event.dispatchTrusted(target, event);
    }
    fn simpleEvent(self: *ConnectionTask, target: *runtime.Instance, event_type: []const u8, bubbles: bool, cancelable: bool) !void {
        if (!self.realm.hasEngine()) return;
        const event = try interfaces.Event.call_constructor(self.realm, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = bubbles, .cancelable = cancelable }));
        const root = try engine.retainValue(self.realm, .{ .instance = event });
        defer root.release();
        _ = try dom.fire_event.dispatchTrusted(target, event);
    }
    fn fail(self: *ConnectionTask, error_name: []const u8) !void {
        const exception = try interfaces.DOMException.call_constructor(self.realm, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(error_name)), webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(error_name)));
        try dom.indexeddb.completeRequest(self.request, .jsUndefined, exception);
        try self.simpleEvent(self.request, "error", true, true);
        self.phase = .finished;
    }
    fn drop(data: ?*anyopaque) void {
        const self: *ConnectionTask = @ptrCast(@alignCast(data.?));
        dom.indexeddb.databaseTaskStarted(&self.queued_task);
        self.queued = false;
        if (self.cancelled) self.destroy() else self.finish(false);
    }
    /// Leave the server's queue: `done` when the request completed (the next
    /// one runs), otherwise withdrawn - its agent ended, or no task source
    /// remains (one mid-upgrade keeps the head until the rollback).
    fn leaveQueue(self: *ConnectionTask, done: bool) void {
        const entry = self.entry;
        if (entry == 0) return;
        self.entry = 0;
        if (done) self.server.dequeue(self.database, entry) else self.server.withdraw(self.database, entry);
    }
    fn finish(self: *ConnectionTask, advance: bool) void {
        // A task dropped after realm retirement still belongs to the
        // factory's pending queue. Unlink it before releasing its roots so
        // factory teardown cannot revisit a freed ConnectionTask.
        if (self.registered) {
            const internal_state = self.internal();
            for (internal_state.pending.items, 0..) |task, index| {
                if (task != self) continue;
                _ = internal_state.pending.orderedRemove(index);
                self.registered = false;
                break;
            }
        }
        self.leaveQueue(advance and self.realm.hasEngine());
        self.destroy();
    }
    fn releaseRoots(self: *ConnectionTask) void {
        if (self.roots_released) return;
        self.roots_released = true;
        if (self.transaction_root) |root| root.release();
        if (self.database_root) |root| root.release();
        self.request_root.release();
        self.factory_root.release();
    }
    fn cancel(self: *ConnectionTask) void {
        // Releasing a root can reenter source cleanup. Keep this task alive
        // until cancellation has finished transferring payload ownership.
        const was_running = self.running;
        self.running = true;
        self.cancelled = true;
        // The agent ends: the request leaves the Browser's queue now (the
        // server is never told to call back into this task again).
        self.leaveQueue(false);
        if (self.queued and dom.indexeddb.cancelDatabaseTask(&self.queued_task)) self.queued = false;
        self.releaseRoots();
        self.running = was_running;
        // Failed cancellation leaves its callback/drop owning the context.
        if (!self.queued and !self.running) self.destroy();
    }
    fn destroy(self: *ConnectionTask) void {
        const allocator = self.allocator;
        self.running = true;
        // Every path leaves the queue before the task goes: the server's
        // entry names this task as its client.
        self.leaveQueue(false);
        self.releaseRoots();
        allocator.free(self.local_notifications);
        self.server.release(self.database);
        allocator.destroy(self);
    }
};
