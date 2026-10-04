//! Implementation for IDBObjectStore interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/object_store.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbobjectstore
//!
//! IDBObjectStore represents an object store in a database. It provides CRUD operations.

const std = @import("std");
const dom = @import("dom");
const engine = @import("engine");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IDBObjectStoreInterface = interfaces.IDBObjectStore;

// Backend imports
const storage = @import("storage");
const BackendObjectStore = storage.indexeddb.object_store.IDBObjectStore;
const BackendKeyRange = storage.indexeddb.IDBKeyRange;
const BackendCursorDirection = storage.indexeddb.cursor.IDBCursorDirection;

pub const State = IDBObjectStoreInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    NotFound,
    DataError,
    ReadOnlyError,
    TransactionInactiveError,
    ConstraintError,
};

/// Internal state for IDBObjectStore
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend object store (borrowed, owned by transaction/database)
    store: ?*BackendObjectStore,

    /// Parent transaction instance
    transaction: ?*runtime.Instance,
    index_wrappers: std.ArrayListUnmanaged(IndexWrapper) = .empty,
    next_index_slot: usize = 0,

    const IndexWrapper = struct {
        index: *storage.indexeddb.IDBIndex,
        instance: *runtime.Instance,
        slot: []const u8,
    };

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.store) |store| {
            const transaction = store.transaction;
            store.deinit();
            transaction.deinit();
        }
        for (self.index_wrappers.items) |wrapper| allocator.free(wrapper.slot);
        self.index_wrappers.deinit(allocator);
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

    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.store = null;
    internal.transaction = null;
    internal.index_wrappers = .empty;
    internal.next_index_slot = 0;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        engine.forgetTracedChild(instance, .{ .name = "idb.transaction" });
        engine.forgetTracedChild(instance, .{ .name = "idb.keyPath" });
        for (internal.index_wrappers.items) |wrapper|
            engine.forgetTracedChild(instance, .{ .name = wrapper.slot });
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

pub fn installHooks() void {
    dom.indexeddb.installStores(.{ .attach = attachStore, .execute = executeOperation });
}
fn attachStore(instance: *runtime.Instance, store: *BackendObjectStore, transaction: *runtime.Instance, transfer: bool) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    std.debug.assert(internal.store == null);
    store.retain();
    store.transaction.retain();
    if (transfer) store.releaseHeapOwnership();
    internal.store = store;
    internal.transaction = transaction;
    engine.traceChild(instance, transaction, .{ .name = "idb.transaction" });
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;
    return runtime.DOMString.initInterned(store.name);
}

/// Getter for keyPath
pub fn get_keyPath(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    return dom.indexeddb_keys.keyPathValue(instance, dom.indexeddb.storeKeyPath(store));
}

/// Getter for indexNames
pub fn get_indexNames(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const names = try store.indexNames();
    defer store.allocator.free(names);
    // create a sorted name list step 1: UTF-16 code unit order.
    std.mem.sort([]const u8, names, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return storage.indexeddb.key.compareStrings(a, b) < 0;
        }
    }.lessThan);
    return dom.string_lists.create(instance.ctx, names);
}

/// Getter for transaction
pub fn get_transaction(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.transaction orelse error.InvalidState;
}

/// Getter for autoIncrement
pub fn get_autoIncrement(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;
    return store.auto_increment;
}

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    // ED 4.5 name setter: native schema and this handle change together.
    try store.rename(value.asSlice());
}

/// ED 4.5 add-or-put: validate and clone at placement, execute later.
pub fn call_put(instance: *runtime.Instance, value: runtime.JSValue, key: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    return addOrPut(instance, value, key, false);
}
pub fn call_add(instance: *runtime.Instance, value: runtime.JSValue, key: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    return addOrPut(instance, value, key, true);
}
fn usable(instance: *runtime.Instance, writing: bool) !*InternalState {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const store = internal.store orelse return error.InvalidStateError;
    // ED 4.5 steps 3-5: deletion precedes transaction state, then mode.
    if (store.isDeleted()) return error.InvalidStateError;
    if (store.transaction.state != .active) return error.TransactionInactiveError;
    if (writing and store.transaction.mode == .readonly) return error.ReadOnlyError;
    return internal;
}
fn addOrPut(instance: *runtime.Instance, value: runtime.JSValue, key: webidl.Opt(runtime.JSValue), no_overwrite: bool) !*runtime.Instance {
    const internal = try usable(instance, true);
    const store = internal.store.?;
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = if (no_overwrite) .add else .put };
    errdefer operation.deinit();
    // Steps 6-8: an explicitly undefined optional key is absent.
    const given = key.wasPassed() and !key.value.isUndefined();
    if (store.usesInlineKeys() and given) return error.DataError;
    if (!store.usesInlineKeys() and !store.auto_increment and !given) return error.DataError;
    if (given) operation.key = try dom.indexeddb_keys.require(instance.ctx, key.value, internal.allocator);
    // Steps 9-11 / 5.11 steps 2-5: getters run while inactive.
    const clone = blk: {
        store.transaction.state = .inactive;
        // Deviation: ED 5.11 steps 3-5's ? skips restoration on failure
        // (w3c/IndexedDB#490). WPT key-conversion-exceptions/keypath-exceptions
        // and WebKit IDBObjectStore::putOrAdd restore before propagating it.
        defer if (store.transaction.state == .inactive) {
            store.transaction.state = .active;
        };
        operation.bytes = try engine.structuredSerializeForStorage(instance.ctx, value, internal.allocator);
        break :blk try engine.structuredDeserialize(instance.ctx, operation.bytes.?);
    };
    defer clone.release();
    if (dom.indexeddb.storeKeyPath(store)) |path| {
        switch (try dom.indexeddb_keys.extract(instance.ctx, clone.value, path, false, internal.allocator)) {
            .key => |extracted| operation.key = extracted,
            .invalid => return error.DataError,
            .failure => {
                if (!store.auto_increment or path != .single) return error.DataError;
                if (!try dom.indexeddb_keys.canInject(instance.ctx, clone.value, path.single)) return error.DataError;
            },
        }
    }
    // Steps 12-13: the queue takes ownership only after placement succeeds.
    try dom.indexeddb.captureWriteIndexes(store, &operation);
    return dom.indexeddb.enqueueRequest(internal.transaction.?, instance, operation, null);
}
fn queueQuery(instance: *runtime.Instance, kind: dom.indexeddb.OperationKind, query: runtime.JSValue, unbounded: bool, writing: bool) !*runtime.Instance {
    const internal = try usable(instance, writing);
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = kind };
    errdefer operation.deinit();
    operation.range = try dom.indexeddb_keys.queryRange(instance.ctx, query, unbounded, internal.allocator);
    return dom.indexeddb.enqueueRequest(internal.transaction.?, instance, operation, null);
}
pub fn call_delete(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    return queueQuery(instance, .delete, query, false, true);
}
pub fn call_clear(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return queueQuery(instance, .clear, .jsUndefined, true, true);
}
pub fn call_get(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    return queueQuery(instance, .get, query, false, false);
}
pub fn call_getKey(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    return queueQuery(instance, .get_key, query, false, false);
}
pub fn call_count(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    return queueQuery(instance, .count, if (query.wasPassed()) query.value else .jsUndefined, true, false);
}
pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    return queueAll(instance, .all_values, queryOrOptions, count);
}
pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    return queueAll(instance, .all_keys, queryOrOptions, count);
}
fn queueAll(instance: *runtime.Instance, kind: dom.indexeddb.OperationKind, query: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) !*runtime.Instance {
    const internal = try usable(instance, false);
    var operation = try dom.indexeddb_keys.multipleItems(instance.ctx, kind, if (query.wasPassed()) query.value else .jsUndefined, if (count.wasPassed()) count.value else null, internal.allocator);
    errdefer operation.deinit();
    return dom.indexeddb.enqueueRequest(internal.transaction.?, instance, operation, null);
}
pub fn call_getAllRecords(instance: *runtime.Instance, options: webidl.Opt(dictionaries.IDBGetAllOptions)) anyerror!*runtime.Instance {
    const internal = try usable(instance, false);
    const converted = if (options.wasPassed()) options.value else dictionaries.IDBGetAllOptions{};
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = .all_records, .limit = converted.count, .direction = dom.indexeddb_keys.cursorDirection(converted.direction orelse ._next_) };
    errdefer operation.deinit();
    operation.range = try dom.indexeddb_keys.queryRange(instance.ctx, converted.query orelse .jsUndefined, true, internal.allocator);
    return dom.indexeddb.enqueueRequest(internal.transaction.?, instance, operation, null);
}
pub fn call_openCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    return queueCursor(instance, query, direction, false);
}
pub fn call_openKeyCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    return queueCursor(instance, query, direction, true);
}
fn queueCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection), key_only: bool) !*runtime.Instance {
    const internal = try usable(instance, false);
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = if (key_only) .open_key_cursor else .open_cursor, .direction = dom.indexeddb_keys.cursorDirection(if (direction.wasPassed()) direction.value else ._next_) };
    errdefer operation.deinit();
    operation.range = try dom.indexeddb_keys.queryRange(instance.ctx, if (query.wasPassed()) query.value else .jsUndefined, true, internal.allocator);
    return dom.indexeddb.enqueueRequest(internal.transaction.?, instance, operation, null);
}
fn executeOperation(instance: *runtime.Instance, request: *runtime.Instance, operation: *dom.indexeddb.Operation) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const store = internal.store orelse return error.InvalidStateError;
    switch (operation.kind) {
        .all_values, .all_keys, .all_records, .open_cursor, .open_key_cursor => return dom.indexeddb.retrieve(instance, request, .{ .object_store = store }, operation),
        else => {},
    }
    const native = switch (operation.kind) {
        .put, .add => try dom.indexeddb.executeStorageWrite(instance.ctx, store, operation),
        .get => try store.get(operation.range),
        .get_key => try store.getKey(operation.range),
        .count => try store.count(operation.range),
        .delete => try store.delete(operation.range),
        .clear => try store.clear(),
        else => unreachable,
    };
    defer internal.allocator.destroy(native);
    defer native.deinit();
    try dom.indexeddb.completeNativeRequest(request, native);
}

/// Operation: index
pub fn call_index(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const name_slice = name.asSlice();

    // index steps 3-5: validate deletion, finished state, and the name.
    const index = try store.index(name_slice);
    // Step 6: preserve identity for this store handle.
    return wrapIndex(instance, internal, index);
}

fn wrapIndex(instance: *runtime.Instance, internal: *InternalState, index: *storage.indexeddb.IDBIndex) !*runtime.Instance {
    for (internal.index_wrappers.items) |wrapper|
        if (wrapper.index == index) return wrapper.instance;
    try internal.index_wrappers.ensureUnusedCapacity(internal.allocator, 1);
    const slot = try std.fmt.allocPrint(internal.allocator, "idb.index.{d}", .{internal.next_index_slot});
    errdefer internal.allocator.free(slot);
    const wrapper = try interfaces.IDBIndex.init(internal.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(wrapper);
    try dom.indexeddb.attachIndex(wrapper, index, instance);
    internal.index_wrappers.appendAssumeCapacity(.{ .index = index, .instance = wrapper, .slot = slot });
    internal.next_index_slot += 1;
    engine.traceChild(instance, wrapper, .{ .name = slot });
    return wrapper;
}

/// Operation: createIndex
pub fn call_createIndex(instance: *runtime.Instance, name: runtime.DOMString, keyPath: runtime.JSValue, options: webidl.Opt(dictionaries.IDBIndexParameters)) anyerror!*runtime.Instance {
    // WebIDL union conversion precedes the algorithm's duplicate/path checks.
    var path = try dom.indexeddb_keys.keyPath(instance.ctx, keyPath, instance.ctx.allocator);
    defer path.deinit();
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const store = internal.store orelse return error.InvalidStateError;
    const backend_options = storage.indexeddb.object_store.IDBIndexParameters{
        .unique = if (options.wasPassed()) options.value.unique orelse false else false,
        .multi_entry = if (options.wasPassed()) options.value.multiEntry orelse false else false,
    };

    const index = store.createIndexWithKeyPath(name.asSlice(), path.value, backend_options) catch |err| {
        return switch (err) {
            error.InvalidKeyPathError => error.SyntaxError,
            else => err,
        };
    };
    const wrapper = try wrapIndex(instance, internal, index);
    // ED 4.5 createIndex: the handle exists synchronously, but population
    // follows earlier requests and any failure aborts the whole upgrade.
    try dom.indexeddb.enqueueInternal(internal.transaction.?, wrapper, .{ .allocator = internal.allocator, .kind = .populate_index });
    return wrapper;
}

/// Operation: deleteIndex
pub fn call_deleteIndex(instance: *runtime.Instance, name: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const name_slice = name.asSlice();

    try store.deleteIndex(name_slice);
    // Remove the cache edge; script may still keep the deleted index itself.
    var i: usize = 0;
    while (i < internal.index_wrappers.items.len) {
        const wrapper = internal.index_wrappers.items[i];
        if (!wrapper.index.deleted) {
            i += 1;
            continue;
        }
        _ = internal.index_wrappers.orderedRemove(i);
        engine.forgetTracedChild(instance, .{ .name = wrapper.slot });
        internal.allocator.free(wrapper.slot);
    }
}
