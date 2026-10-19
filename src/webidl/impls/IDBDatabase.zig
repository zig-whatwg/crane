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
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
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
    upgrade_transaction: ?*runtime.Instance = null,
    factory: ?*runtime.Instance = null,
    factory_generation: u64 = 0,

    /// Event handlers (EventHandler = ?*const fn, so null = no handler)
    onabort: typedefs.EventHandler,
    onclose: typedefs.EventHandler,
    onerror: typedefs.EventHandler,
    onversionchange: typedefs.EventHandler,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.database.releaseHeapOwnership();
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

    state.own._internal = null;
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    const database = try allocator.create(BackendDatabase);
    database.* = BackendDatabase.init(allocator, "unnamed", 1);
    internal.* = .{ .allocator = allocator, .database = database, .onabort = null, .onclose = null, .onerror = null, .onversionchange = null };
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // The connection's object is gone (collected, or its realm ended): it
        // hears no versionchange again, and the Browser's server closes it
        // once its transactions finish (ED 5.2; agent end).
        internal.database.version_change_hook = null;
        internal.database.closePending();
        engine.forgetTracedChild(instance, .{ .name = "idb.factory" });
        engine.forgetTracedChild(instance, .{ .name = "idb.upgrade" });
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    interfaces.EventTarget.deinit(instance);
}

/// Getter for name
///
/// Returns the name of the database.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.database.name);
}

/// Getter for version
///
/// Returns the version of the database.
pub fn get_version(instance: *runtime.Instance) anyerror!u64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.database.version;
}

/// Getter for objectStoreNames
///
/// Returns a DOMStringList of object store names.
pub fn get_objectStoreNames(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Create a sorted name list steps 1-2: fresh, copied snapshot every call.
    const names = try internal.database.objectStoreNames();
    defer internal.allocator.free(names);
    return dom.string_lists.create(instance.ctx, names);
}

/// Operation: transaction
///
/// Creates a new transaction on the database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-transaction
pub fn call_transaction(instance: *runtime.Instance, storeNames: runtime.JSValue, mode: webidl.Opt(enums.IDBTransactionMode), options: webidl.Opt(dictionaries.IDBTransactionOptions)) anyerror!*runtime.Instance {
    const allocator = instance.ctx.allocator;
    // WebIDL union conversion precedes the method algorithm.
    var converted: ?[][]u8 = null;
    if (engine.typeOf(instance.ctx, storeNames) == .object) converted = try engine.convertToSequenceOfDOMStrings(instance.ctx, storeNames, allocator);
    if (converted == null) {
        const name = try engine.convertToDOMString(instance.ctx, storeNames, allocator);
        errdefer allocator.free(name);
        const names = try allocator.alloc([]u8, 1);
        names[0] = name;
        converted = names;
    }
    defer {
        for (converted.?) |name| allocator.free(name);
        allocator.free(converted.?);
    }
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    // Steps 1-2: live upgrade and close-pending checks.
    if (internal.database.version_change_transaction != null or internal.database.closed) return error.InvalidStateError;
    var scope: std.ArrayList([]const u8) = .empty;
    defer scope.deinit(allocator);
    // Step 3: set of unique converted names, retaining the converted allocation.
    for (converted.?) |name| {
        var duplicate = false;
        for (scope.items) |existing| if (std.mem.eql(u8, existing, name)) {
            duplicate = true;
            break;
        };
        if (!duplicate) try scope.append(allocator, name);
    }
    // Steps 4-6: missing name, empty scope, then invalid versionchange mode.
    if (!internal.database.hasObjectStores(scope.items)) return error.NotFoundError;
    if (scope.items.len == 0) return error.InvalidAccessError;
    const backend_mode: BackendTransactionMode = switch (if (mode.wasPassed()) mode.value else ._readonly_) {
        ._readonly_ => .readonly,
        ._readwrite_ => .readwrite,
        ._versionchange_ => return error.TypeError,
    };
    const durability: storage.indexeddb.IDBTransactionDurability = switch (if (options.wasPassed()) options.value.durability orelse ._default_ else ._default_) {
        ._default_ => .default,
        ._strict_ => .strict,
        ._relaxed_ => .relaxed,
    };
    // Steps 7-9: backend owns its scope snapshot; the owner hook transfers it.
    const transaction = try internal.database.transaction(scope.items, backend_mode, .{ .durability = durability });
    errdefer {
        transaction.deinit();
        allocator.destroy(transaction);
    }
    const wrapper = try interfaces.IDBTransaction.init(allocator, instance.ctx);
    errdefer runtime.Instance.deinit(wrapper);
    try dom.indexeddb.attachTransaction(wrapper, transaction, instance);
    return wrapper;
}

/// Operation: createObjectStore
///
/// Creates a new object store in the database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-createobjectstore
///
/// Note: Can only be called during a versionchange transaction.
pub fn call_createObjectStore(instance: *runtime.Instance, name: runtime.DOMString, options: webidl.Opt(dictionaries.IDBObjectStoreParameters)) anyerror!*runtime.Instance {
    // Convert the dictionary's nullable string/sequence union before running
    // the method. Native 4.4 steps 1-8 then apply validation in spec order.
    const converted = if (options.wasPassed()) options.value else dictionaries.IDBObjectStoreParameters{};
    const key_path = converted.keyPath orelse runtime.JSValue.jsNull;
    var path: ?dom.indexeddb_keys.Path = if (key_path.isNullOrUndefined()) null else try dom.indexeddb_keys.keyPath(instance.ctx, key_path, instance.ctx.allocator);
    defer if (path) |*owned| owned.deinit();
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const backend_options = storage.indexeddb.database.IDBObjectStoreParameters{
        .key_path = if (path) |owned| if (owned.value == .single) owned.value.single else null else null,
        .compound_key_path = if (path) |owned| if (owned.value == .array) owned.value.array else null else null,
        .auto_increment = converted.autoIncrement orelse false,
    };
    const store = internal.database.createObjectStore(name.asSlice(), backend_options) catch |err| {
        return switch (err) {
            error.InvalidKeyPathError => error.SyntaxError,
            else => err,
        };
    };

    // createObjectStore returns the same handle as transaction.objectStore.
    // The native creation handle is temporary; the transaction owns its cache.
    defer {
        store.deinit();
        internal.database.allocator.destroy(store);
    }
    return interfaces.IDBTransaction.call_objectStore(internal.upgrade_transaction.?, name);
}

/// Operation: close
///
/// Closes the database connection.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-close
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // ED 5.2 "close a database connection" step 1: close pending; the
    // Browser's server closes it once its transactions finish (step 2) and
    // then lets a request waiting on it go on.
    internal.database.closed = true;
    internal.database.closePending();
}

/// Operation: deleteObjectStore
///
/// Deletes an object store from the database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbdatabase-deleteobjectstore
///
/// Note: Can only be called during a versionchange transaction.
pub fn call_deleteObjectStore(instance: *runtime.Instance, name: runtime.DOMString) anyerror!void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    try internal.database.deleteObjectStore(name.asSlice());
}

pub fn installHooks() void {
    dom.indexeddb.installDatabases(.{ .is_closing = isClosing, .set_factory = setFactory, .attach = attachDatabase, .begin_upgrade = beginUpgrade, .end_upgrade = endUpgrade, .transaction_finished = transactionFinished });
}

/// An upgrade transaction of this connection finished: its factory's open
/// request may take its final step. (Every other wake is the server's.)
fn transactionFinished(instance: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    const factory = internal.factory orelse return;
    if (runtime.SlabAllocator.generationOf(factory) == internal.factory_generation)
        dom.indexeddb.wakeFactoryTransactions(factory);
}

/// The server's versionchange for this connection (ED 5.1 step 10.2): on
/// this thread - within the requester's own database task when it is of
/// this agent, else as a task of this agent's loop (`posted`), entering the
/// connection's realm first (lesson
/// architecture-a-task-from-a-sink-runs-outside-every-realm).
fn versionChangeHook(context: *anyopaque, old_version: u64, new_version: ?u64, posted: bool) void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(context));
    var change: VersionChange = .{ .instance = instance, .old_version = old_version, .new_version = new_version };
    if (!instance.ctx.hasEngine()) return;
    if (posted) engine.runTaskInRealm(instance.ctx, VersionChange.steps, &change) catch {} else VersionChange.steps(&change);
}

const VersionChange = struct {
    instance: *runtime.Instance,
    old_version: u64,
    new_version: ?u64,

    fn steps(data: ?*anyopaque) void {
        const self: *VersionChange = @ptrCast(@alignCast(data.?));
        self.fire() catch {};
    }

    fn fire(self: *VersionChange) !void {
        const realm = self.instance.ctx;
        if (!realm.hasEngine()) return;
        if (cachedWindowOf(realm)) |window| {
            // A connection of a page the back/forward cache keeps cannot
            // answer versionchange: the page is evicted instead, and its end
            // closes the connection, so the upgrade goes on (Blink's
            // kIgnoreEventAndEvict for IndexedDB versionchange;
            // IndexedDB/back-forward-cache-open-connection.window.js passes
            // in Chrome 155, Firefox 158 and Safari 27).
            dom.bfcache.evict(window, null);
            return;
        }
        const internal = self.instance.getState(State).own._internal orelse return;
        if (internal.database.closed) return;
        const event = try interfaces.IDBVersionChangeEvent.call_constructor(realm, runtime.DOMString.initInterned("versionchange"), webidl.Opt(dictionaries.IDBVersionChangeEventInit).passed(.{ .base = .{}, .oldVersion = self.old_version, .newVersion = self.new_version }));
        const root = try engine.retainValue(realm, .{ .instance = event });
        defer root.release();
        _ = try dom.fire_event.dispatchTrusted(self.instance, event);
    }
};

/// The Window of `realm` when it belongs to a page the back/forward cache
/// keeps. Asked on `realm`'s own thread: a worker's global is never cached,
/// and the cache is read only on its window thread.
fn cachedWindowOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return if (dom.bfcache.holds(global)) global else null;
}

fn attachDatabase(instance: *runtime.Instance, database: *BackendDatabase) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    // Backend names borrow their caller's string. The connection owns its copy.
    const name = try database.allocator.dupe(u8, database.name);
    internal.database.releaseHeapOwnership();
    if (database.owned_name) |old| database.allocator.free(old);
    database.owned_name = name;
    database.name = name;
    database.version_change_hook = .{ .context = instance, .call = versionChangeHook };
    internal.database = database;
}
fn beginUpgrade(instance: *runtime.Instance) !*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const transaction = try internal.allocator.create(storage.indexeddb.IDBTransaction);
    errdefer internal.allocator.destroy(transaction);
    transaction.* = storage.indexeddb.IDBTransaction.init(internal.allocator, internal.database, &.{}, .versionchange);
    errdefer transaction.deinit();
    // 5.7 step 3: the upgrade joins the server's scheduler - excluding every
    // other transaction, and holding its request's place in the queue until
    // it finishes (rolled back, if its agent ends).
    try transaction.register();
    const wrapper = try interfaces.IDBTransaction.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(wrapper);
    try dom.indexeddb.attachTransaction(wrapper, transaction, instance);
    internal.database.version_change_transaction = transaction;
    internal.upgrade_transaction = wrapper;
    engine.traceChild(instance, wrapper, .{ .name = "idb.upgrade" });
    return wrapper;
}
fn endUpgrade(instance: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    internal.database.version_change_transaction = null;
    internal.upgrade_transaction = null;
    engine.forgetTracedChild(instance, .{ .name = "idb.upgrade" });
}

fn setFactory(instance: *runtime.Instance, factory: *runtime.Instance) void {
    const internal = instance.getState(State).own._internal orelse return;
    internal.factory = factory;
    internal.factory_generation = runtime.SlabAllocator.generationOf(factory);
    engine.traceChild(instance, factory, .{ .name = "idb.factory" });
}

fn isClosing(instance: *runtime.Instance) bool {
    return (instance.getState(State).own._internal orelse return true).database.closed;
}
