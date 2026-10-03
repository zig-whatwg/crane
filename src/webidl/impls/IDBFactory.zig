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
const BackendFactory = storage.indexeddb.IDBFactory;
const BackendOpenDBRequest = storage.indexeddb.IDBOpenDBRequest;
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
    pending: std.ArrayList(*ConnectionTask) = .empty,
    connections: std.ArrayList(Connection) = .empty,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Realm teardown can destroy the factory while requests await close.
        // Cancel owned pending activity without enqueueing into the dying realm.
        while (self.pending.items.len != 0) {
            const task = self.pending.pop().?;
            task.registered = false;
            task.cancel();
        }
        self.pending.deinit(allocator);
        for (self.connections.items) |connection| connection.deinit(allocator);
        self.connections.deinit(allocator);
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
    // What deinit reads, should anything below fail: the errdefer above runs
    // it, and an `_internal` never set read garbage (a failed allocation of
    // the state below crashed in deinit).
    state.own._internal = null;

    // Create internal state - this call's until it is complete, then deinit's.
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator, .factory = undefined };

    // Create backend factory
    internal.factory = try allocator.create(BackendFactory);
    internal.factory.* = BackendFactory.init(allocator);

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
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Version 0 is invalid per spec - unwrap Opt
    const version_val: ?u64 = if (version.wasPassed()) version.value else null;
    if (version_val != null and version_val.? == 0) {
        return error.TypeError;
    }

    // Steps 2-6: obtain the relevant storage key, enqueue, return pending request.
    const origin = try storageKey(instance);
    defer internal.allocator.free(origin);
    return enqueueConnection(instance, origin, name.asSlice(), version_val, false);
}

/// Operation: databases
///
/// Returns a Promise that resolves to a sequence of IDBDatabaseInfo dictionaries.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-databases
pub fn call_databases(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const realm = engine.currentRealm() orelse instance.ctx;
    // Steps 1-2: opaque settings origins reject a new promise, never throw synchronously.
    const origin = storageKey(instance) catch |err| {
        if (err != error.SecurityError) return err;
        const reason = try engine.createDOMException(realm, "SecurityError", "The storage origin is opaque");
        defer reason.release();
        return (try engine.createRejectedPromise(realm, reason.value)).take();
    };
    defer internal.allocator.free(origin);
    internal.factory.setStorageKey(origin);
    defer internal.factory.storage_key = null;
    const db_list = try internal.factory.databases();
    defer internal.allocator.free(db_list);

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
    task.* = .{ .realm = realm, .capability = capability, .snapshot = snapshot };
    if (realm.getOptionalEventLoop()) |loop| {
        loop.queueTask(.{ .callback = DatabasesTask.run, .context = task, .drop = DatabasesTask.drop });
    } else {
        // Engine-less unit-test contexts have no task queue.
        DatabasesTask.run(task);
    }
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
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Steps 1-5: the queue performs deletion only after existing connections close.
    const origin = try storageKey(instance);
    defer internal.allocator.free(origin);
    return enqueueConnection(instance, origin, name.asSlice(), null, true);
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
    dom.indexeddb.installFactories(.{ .register = registerConnection, .unregister = unregisterConnection, .advance = advanceQueue, .wake_transactions = wakeTransactions });
}

fn wakeTransactions(instance: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    for (internal.connections.items) |connection| dom.indexeddb.wakeDatabaseTransactions(connection.instance);
    for (internal.pending.items) |task| {
        if (task.phase == .commit or task.phase == .failed) task.schedule();
    }
}
fn storageKey(instance: *runtime.Instance) ![]u8 {
    // Storage 4.2: the relevant settings object's origin; opaque is failure.
    const realm = instance.ctx.getRealm() orelse return error.SecurityError;
    const global: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return error.SecurityError));
    const settings = dom.global_settings.of(global) orelse return error.SecurityError;
    const origin = try settings.origin(global);
    defer global.ctx.allocator.free(origin);
    if (std.mem.eql(u8, origin, "null")) return error.SecurityError;
    return instance.ctx.allocator.dupe(u8, origin);
}
const Connection = struct {
    instance: *runtime.Instance,
    origin: []u8,
    name: []u8,
    fn deinit(self: Connection, allocator: std.mem.Allocator) void {
        allocator.free(self.origin);
        allocator.free(self.name);
    }
};
fn matches(origin: []const u8, name: []const u8, other_origin: []const u8, other_name: []const u8) bool {
    return std.mem.eql(u8, origin, other_origin) and std.mem.eql(u8, name, other_name);
}
fn registerConnection(factory: *runtime.Instance, connection: *runtime.Instance, origin: []const u8, name: []const u8) !void {
    const internal = factory.getState(State).own._internal orelse return error.InvalidStateError;
    const origin_copy = try internal.allocator.dupe(u8, origin);
    errdefer internal.allocator.free(origin_copy);
    const name_copy = try internal.allocator.dupe(u8, name);
    errdefer internal.allocator.free(name_copy);
    try internal.connections.append(internal.allocator, .{ .instance = connection, .origin = origin_copy, .name = name_copy });
    dom.indexeddb.setDatabaseFactory(connection, factory);
}
fn unregisterConnection(factory: *runtime.Instance, connection: *runtime.Instance) void {
    const internal = factory.getState(State).own._internal orelse return;
    for (internal.connections.items, 0..) |entry, index| {
        if (entry.instance != connection) continue;
        const removed = internal.connections.orderedRemove(index);
        defer removed.deinit(internal.allocator);
        advanceQueue(factory, removed.origin, removed.name);
        return;
    }
}
fn advanceQueue(factory: *runtime.Instance, origin: []const u8, name: []const u8) void {
    const internal = factory.getState(State).own._internal orelse return;
    for (internal.pending.items) |task| {
        if (matches(origin, name, task.origin, task.name)) {
            task.schedule();
            return;
        }
    }
}
fn enqueueConnection(factory: *runtime.Instance, origin: []const u8, name: []const u8, version: ?u64, deletion: bool) !*runtime.Instance {
    const internal = factory.getState(State).own._internal orelse return error.InvalidStateError;
    const request = try interfaces.IDBOpenDBRequest.init(internal.allocator, factory.ctx);
    errdefer if (!engine.hasWrapper(request)) runtime.Instance.deinit(request);
    const origin_copy = try internal.allocator.dupe(u8, origin);
    errdefer internal.allocator.free(origin_copy);
    const name_copy = try internal.allocator.dupe(u8, name);
    errdefer internal.allocator.free(name_copy);
    const factory_root = try engine.retainValue(factory.ctx, .{ .instance = factory });
    errdefer factory_root.release();
    const request_root = try engine.retainValue(factory.ctx, .{ .instance = request });
    errdefer request_root.release();
    const task = try internal.allocator.create(ConnectionTask);
    errdefer internal.allocator.destroy(task);
    task.* = .{ .allocator = internal.allocator, .factory = factory, .request = request, .factory_root = factory_root, .request_root = request_root, .origin = origin_copy, .name = name_copy, .version = version, .deletion = deletion };
    var first = true;
    for (internal.pending.items) |existing| if (matches(origin, name, existing.origin, existing.name)) {
        first = false;
        break;
    };
    try internal.pending.append(internal.allocator, task);
    task.registered = true;
    if (first) task.schedule();
    return request;
}

/// ED 2.8.2 connection queue, 5.1 opening, 5.3 deleting, and 5.7 upgrading.
/// Pending activity roots belong to this operation, and end after its script
/// and microtasks, or when realm teardown drops the queued task.
const ConnectionTask = struct {
    allocator: std.mem.Allocator,
    cancelled: bool = false,
    roots_released: bool = false,
    factory: *runtime.Instance,
    request: *runtime.Instance,
    factory_root: engine.Owned,
    request_root: engine.Owned,
    origin: []u8,
    name: []u8,
    version: ?u64,
    deletion: bool,
    old_version: u64 = 0,
    phase: enum { start, notify, wait, upgrade, commit, success, failed, error_event, finished } = .start,
    notifications: std.ArrayList(struct { instance: *runtime.Instance, root: engine.Owned }) = .empty,
    waiting: bool = false,
    next_notification: usize = 0,
    database: ?*runtime.Instance = null,
    database_root: ?engine.Owned = null,
    transaction: ?*runtime.Instance = null,
    queued: bool = false,
    running: bool = false,
    blocked_fired: bool = false,
    registered: bool = false,

    fn internal(self: *ConnectionTask) *InternalState {
        return self.factory.getState(State).own._internal.?;
    }
    fn schedule(self: *ConnectionTask) void {
        if (self.queued or self.running or self.cancelled or self.phase == .finished) return;
        const loop = self.factory.ctx.getOptionalEventLoop() orelse return;
        self.queued = true;
        loop.queueTask(.{ .callback = run, .context = self, .drop = drop });
    }
    fn run(data: ?*anyopaque) void {
        const self: *ConnectionTask = @ptrCast(@alignCast(data.?));
        self.queued = false;
        if (self.cancelled) {
            self.destroy();
            return;
        }
        if (!self.factory.ctx.hasEngine() or !self.request.ctx.hasEngine()) return self.finish(false);
        self.running = true;
        engine.runTaskInRealm(self.factory.ctx, steps, self) catch {};
        self.running = false;
        // Task ownership extends through runTaskInRealm's checkpoint.
        // Teardown cancels the task before freeing its owning factory. Do not
        // inspect any wrapper after script or its microtasks cancelled it.
        if (self.cancelled) return self.destroy();
        if (!self.factory.ctx.hasEngine() or !self.request.ctx.hasEngine()) return self.finish(false);
        if (self.phase == .finished) self.finish(true) else if (self.phase == .commit or self.phase == .failed) {
            if (self.transaction) |transaction| {
                if (dom.indexeddb.transactionOutcome(transaction) != null) self.schedule();
            }
        } else if (self.phase != .wait or !self.waiting or !self.hasConnections()) self.schedule();
    }
    fn steps(data: ?*anyopaque) void {
        const self: *ConnectionTask = @ptrCast(@alignCast(data.?));
        self.perform() catch |err| {
            if (!self.cancelled and self.factory.ctx.hasEngine() and self.request.ctx.hasEngine()) self.fail(@errorName(err)) catch {};
        };
    }
    fn perform(self: *ConnectionTask) !void {
        switch (self.phase) {
            .start => {
                // Opening steps 2-6 / deletion steps 2-4: inspect version first.
                const backend = self.internal().factory;
                backend.setStorageKey(self.origin);
                defer backend.storage_key = null;
                const databases = try backend.databases();
                defer self.allocator.free(databases);
                for (databases) |database| if (std.mem.eql(u8, database.name, self.name)) {
                    self.old_version = database.version;
                    break;
                };
                if (!self.deletion) {
                    self.version = self.version orelse if (self.old_version == 0) @as(u64, 1) else self.old_version;
                    if (self.version.? < self.old_version) return error.VersionError;
                }
                if (self.deletion or self.version.? > self.old_version) {
                    // Snapshot before dispatch: a listener may close/remove a connection.
                    for (self.internal().connections.items) |connection| {
                        if (!matches(self.origin, self.name, connection.origin, connection.name)) continue;
                        const root = try engine.retainValue(self.factory.ctx, .{ .instance = connection.instance });
                        errdefer root.release();
                        try self.notifications.append(self.internal().allocator, .{ .instance = connection.instance, .root = root });
                    }
                    self.phase = .notify;
                } else self.phase = .wait;
            },
            .notify => {
                if (self.next_notification < self.notifications.items.len) {
                    const notification = self.notifications.items[self.next_notification];
                    self.next_notification += 1;
                    const connection = notification.instance;
                    if (self.connectionRegistered(connection) and !dom.indexeddb.connectionIsClosing(connection)) try self.versionEvent(connection, "versionchange", self.versionForEvent());
                } else self.phase = .wait;
            },
            .wait => {
                if (self.hasConnections() and (self.deletion or self.version.? > self.old_version)) {
                    self.waiting = true;
                    if (!self.blocked_fired) {
                        self.blocked_fired = true;
                        try self.versionEvent(self.request, "blocked", self.versionForEvent());
                    }
                    return;
                }
                if (self.deletion) {
                    const request = blk: {
                        // Finish the native borrow before script can retire
                        // the factory and destroy its backend during dispatch.
                        const backend = self.internal().factory;
                        backend.setStorageKey(self.origin);
                        defer backend.storage_key = null;
                        break :blk try backend.deleteDatabase(self.name);
                    };
                    dom.indexeddb.attachOpenRequest(self.request, request);
                    try dom.indexeddb.completeRequest(self.request, .jsUndefined, null);
                    try self.versionEvent(self.request, "success", null);
                    self.phase = .finished;
                    return;
                }
                const request = blk: {
                    const backend = self.internal().factory;
                    backend.setStorageKey(self.origin);
                    defer backend.storage_key = null;
                    break :blk try backend.openPending(self.name, self.version);
                };
                dom.indexeddb.attachOpenRequest(self.request, request);
                if (request.base.err) |err| return self.fail(@errorName(err));
                const database = try interfaces.IDBDatabase.init(self.internal().allocator, self.factory.ctx);
                errdefer if (!engine.hasWrapper(database)) runtime.Instance.deinit(database);
                const connection = request.base.result.?.database;
                try dom.indexeddb.attachDatabase(database, connection);
                request.base.result = null; // Ownership transferred; the request no longer frees it.
                try dom.indexeddb.registerConnection(self.factory, database, self.origin, self.name);
                self.database_root = try engine.retainValue(self.factory.ctx, .{ .instance = database });
                self.database = database;
                self.phase = if (self.version.? > self.old_version) .upgrade else .success;
            },
            .upgrade => {
                // 5.7: expose the upgrade transaction and done result before dispatch.
                const transaction = try dom.indexeddb.beginUpgrade(self.database.?);
                self.transaction = transaction;
                try dom.indexeddb.completeRequest(self.request, .{ .instance = self.database.? }, null);
                dom.indexeddb.setRequestTransaction(self.request, transaction);
                var did_throw = false;
                const event = try self.newVersionEvent("upgradeneeded", self.version);
                const event_root = try engine.retainValue(self.factory.ctx, .{ .instance = event });
                defer event_root.release();
                _ = try dom.fire_event.dispatchTrustedWithThrows(self.request, event, &did_throw);
                if (self.cancelled or !self.factory.ctx.hasEngine() or !self.request.ctx.hasEngine()) return;
                self.phase = if (try dom.indexeddb.endTransactionEvent(transaction, did_throw)) .failed else .commit;
            },
            .failed => {
                if (self.transaction) |transaction| {
                    if (dom.indexeddb.transactionOutcome(transaction) == null) return;
                }
                dom.indexeddb.setRequestTransaction(self.request, null);
                dom.indexeddb.endUpgrade(self.database.?);
                try interfaces.IDBDatabase.call_close(self.database.?);
                dom.indexeddb.setRequestPending(self.request);
                self.phase = .error_event;
            },
            .error_event => try self.fail("AbortError"),
            .commit => {
                if (self.transaction) |transaction| {
                    const committed = dom.indexeddb.transactionOutcome(transaction) orelse return;
                    dom.indexeddb.setRequestTransaction(self.request, null);
                    dom.indexeddb.endUpgrade(self.database.?);
                    if (!committed) {
                        try interfaces.IDBDatabase.call_close(self.database.?);
                        dom.indexeddb.setRequestPending(self.request);
                        self.phase = .error_event;
                        return;
                    }
                }
                self.phase = if (dom.indexeddb.connectionIsClosing(self.database.?)) .error_event else .success;
            },
            .success => {
                try dom.indexeddb.completeRequest(self.request, .{ .instance = self.database.? }, null);
                // 5.1 final task: upgrade finished, then ordinary trusted success.
                try self.simpleEvent(self.request, "success", false, false);
                self.phase = .finished;
            },
            .finished => {},
        }
    }
    fn versionForEvent(self: *ConnectionTask) ?u64 {
        return if (self.deletion) null else self.version;
    }
    fn hasConnections(self: *ConnectionTask) bool {
        for (self.internal().connections.items) |connection| if (matches(self.origin, self.name, connection.origin, connection.name)) return true;
        return false;
    }
    fn connectionRegistered(self: *ConnectionTask, instance: *runtime.Instance) bool {
        for (self.internal().connections.items) |connection| if (connection.instance == instance) return true;
        return false;
    }
    fn newVersionEvent(self: *ConnectionTask, event_type: []const u8, version: ?u64) !*runtime.Instance {
        return interfaces.IDBVersionChangeEvent.call_constructor(self.factory.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.IDBVersionChangeEventInit).passed(.{ .base = .{}, .oldVersion = self.old_version, .newVersion = version }));
    }
    fn versionEvent(self: *ConnectionTask, target: *runtime.Instance, event_type: []const u8, version: ?u64) !void {
        if (!target.ctx.hasEngine()) return;
        const event = try self.newVersionEvent(event_type, version);
        const root = try engine.retainValue(self.factory.ctx, .{ .instance = event });
        defer root.release();
        _ = try dom.fire_event.dispatchTrusted(target, event);
    }
    fn simpleEvent(self: *ConnectionTask, target: *runtime.Instance, event_type: []const u8, bubbles: bool, cancelable: bool) !void {
        if (!target.ctx.hasEngine()) return;
        const event = try interfaces.Event.call_constructor(self.factory.ctx, runtime.DOMString.initInterned(event_type), webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = bubbles, .cancelable = cancelable }));
        const root = try engine.retainValue(self.factory.ctx, .{ .instance = event });
        defer root.release();
        _ = try dom.fire_event.dispatchTrusted(target, event);
    }
    fn fail(self: *ConnectionTask, error_name: []const u8) !void {
        const exception = try interfaces.DOMException.call_constructor(self.factory.ctx, webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(error_name)), webidl.Opt(runtime.DOMString).passed(runtime.DOMString.initInterned(error_name)));
        try dom.indexeddb.completeRequest(self.request, .jsUndefined, exception);
        try self.simpleEvent(self.request, "error", true, true);
        self.phase = .finished;
    }
    fn drop(data: ?*anyopaque) void {
        const self: *ConnectionTask = @ptrCast(@alignCast(data.?));
        self.queued = false;
        if (self.cancelled) self.destroy() else self.finish(false);
    }
    fn finish(self: *ConnectionTask, advance: bool) void {
        const internal_state = self.internal();
        if (self.registered) for (internal_state.pending.items, 0..) |task, index| {
            if (task != self) continue;
            _ = internal_state.pending.orderedRemove(index);
            self.registered = false;
            break;
        };
        if (advance) advanceQueue(self.factory, self.origin, self.name);
        self.destroy();
    }
    fn releaseRoots(self: *ConnectionTask) void {
        if (self.roots_released) return;
        self.roots_released = true;
        for (self.notifications.items) |notification| notification.root.release();
        if (self.database_root) |root| root.release();
        self.request_root.release();
        self.factory_root.release();
    }
    fn cancel(self: *ConnectionTask) void {
        self.cancelled = true;
        self.releaseRoots();
        // A queued callback still owns its context. Let it observe cancellation
        // and destroy it; an operation waiting for close has no queued callback.
        if (!self.queued and !self.running) self.destroy();
    }
    fn destroy(self: *ConnectionTask) void {
        const allocator = self.allocator;
        self.releaseRoots();
        self.notifications.deinit(allocator);
        allocator.free(self.origin);
        allocator.free(self.name);
        allocator.destroy(self);
    }
};
