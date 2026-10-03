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
    // What deinit reads, should anything below fail: the errdefer above runs
    // it, and an `_internal` never set read garbage (a failed allocation of
    // the state below crashed in deinit).
    state.own._internal = null;

    // Create internal state - this call's until it is complete, then deinit's.
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.allocator = allocator;

    // Create backend factory
    internal.factory = try allocator.create(BackendFactory);
    internal.factory.* = BackendFactory.init(allocator);

    // Set default storage key from context origin (if available)
    // TODO: Get origin from runtime context
    internal.factory.setStorageKey("default-origin");

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
    // Not connected to the wrapper yet (the TODO below): this call's.
    defer dropBackendRequest(internal.factory.allocator, request);

    // Wrap the backend request in a WebIDL IDBOpenDBRequest instance
    const request_instance = interfaces.IDBOpenDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend request in the WebIDL wrapper
    const request_state = request_instance.getState(interfaces.IDBOpenDBRequest.State);
    if (request_state.own._internal) |req_internal| {
        // Set the backend request reference
        _ = req_internal;
        // TODO: Connect backend request to WebIDL request wrapper
        // (and drop the defer'd free above then: the wrapper will own it).
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

    // Steps 1-2: the factory supplies the existing storage entry point.
    const db_list = try internal.factory.databases();
    defer internal.allocator.free(db_list);
    const realm = engine.currentRealm() orelse instance.ctx;

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
    // Not connected to the wrapper yet (the TODO below): this call's.
    defer dropBackendRequest(internal.factory.allocator, request);

    // Wrap the backend request in a WebIDL IDBOpenDBRequest instance
    const request_instance = interfaces.IDBOpenDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend request reference
    // TODO: Connect backend request to WebIDL request wrapper
    // (and drop the defer'd free above then: the wrapper will own it).

    return request_instance;
}

/// The backend's open request, and the connection `open` made as its result,
/// when the call that asked for them ends: nothing is connected to them yet
/// (the TODOs above), and the backend keeps neither - no table entry (a
/// database's metadata holds its name and version, its `connections` list is
/// never appended), no queued task, no handler (`setResult` calls
/// `onsuccess`, which nothing sets). Each open() and deleteDatabase() leaked
/// them (leaks lane, 2026-10-02: 56 in the 29 IndexedDB/ files of one sweep
/// shard, from the support code's deleteDatabase).
fn dropBackendRequest(allocator: std.mem.Allocator, request: *BackendOpenDBRequest) void {
    if (request.base.result) |result| switch (result) {
        .database => |connection| {
            connection.deinit();
            allocator.destroy(connection);
        },
        else => {},
    };
    request.deinit();
    allocator.destroy(request);
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
