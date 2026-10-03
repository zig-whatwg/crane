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
        for (internal.index_wrappers.items) |wrapper|
            engine.forgetTracedChild(instance, .{ .name = wrapper.slot });
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

pub fn installHooks() void {
    dom.indexeddb.installStores(.{ .attach = attachStore });
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

    if (store.getKeyPathString()) |path| return runtime.JSValue.fromStringRef(path);
    if (store.getKeyPathArray()) |paths| {
        const values = try internal.allocator.alloc(runtime.JSValue, paths.len);
        defer internal.allocator.free(values);
        for (paths, 0..) |path, i| values[i] = runtime.JSValue.fromStringRef(path);
        return (try engine.createSequenceOfValues(instance.ctx, values)).take();
    }
    return .jsNull;
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

    // Renaming object stores is only allowed during versionchange transactions
    _ = store;
    _ = value;
    return error.InvalidState; // TODO: Implement rename
}

/// Operation: put
pub fn call_put(instance: *runtime.Instance, value: runtime.JSValue, key: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    // TODO: Convert JS value to serialized bytes
    // TODO: Convert JS key to IDBKey
    _ = value;
    _ = key;

    const request = store.put(&.{}, null) catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            error.DataError => error.DataError,
            error.ConstraintError => error.ConstraintError,
            else => error.InvalidState,
        };
    };

    // Create WebIDL IDBRequest wrapper
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, value: runtime.JSValue, key: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = value;
    _ = key;

    const request = store.add(&.{}, null) catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            error.DataError => error.DataError,
            error.ConstraintError => error.ConstraintError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.delete(BackendKeyRange.unbounded()) catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const request = store.clear() catch |err| {
        return switch (err) {
            error.ReadOnlyError => error.ReadOnlyError,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.get(BackendKeyRange.unbounded()) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: getKey
pub fn call_getKey(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.getKey(BackendKeyRange.unbounded()) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: getAll
pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = queryOrOptions;
    _ = count;

    // TODO: Implement getAll with proper query conversion
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
}

/// Operation: getAllKeys
pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = queryOrOptions;
    _ = count;

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
}

/// Operation: getAllRecords
pub fn call_getAllRecords(instance: *runtime.Instance, options: webidl.Opt(dictionaries.IDBGetAllOptions)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = options;

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
}

/// Operation: count
pub fn call_count(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    const request = store.count(null) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: openCursor
pub fn call_openCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    _ = query;

    // Unwrap Opt for direction (default to "next")
    const direction_val = if (direction.wasPassed()) direction.value else ._next_;
    const backend_direction = switch (direction_val) {
        ._next_ => BackendCursorDirection.next,
        ._nextunique_ => BackendCursorDirection.nextunique,
        ._prev_ => BackendCursorDirection.prev,
        ._prevunique_ => BackendCursorDirection.prevunique,
    };

    const request = store.openCursor(BackendKeyRange.unbounded(), backend_direction) catch |err| {
        return switch (err) {
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    _ = request;
    return req_instance;
}

/// Operation: openKeyCursor
pub fn call_openKeyCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    _ = internal.store orelse return error.InvalidState;

    _ = query;
    _ = direction;

    // TODO: Implement openKeyCursor
    const req_instance = interfaces.IDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    return req_instance;
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
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const store = internal.store orelse return error.InvalidState;

    const name_slice = name.asSlice();
    _ = keyPath;

    // Unwrap Opt for options
    const backend_options = storage.indexeddb.object_store.IDBIndexParameters{
        .unique = if (options.wasPassed()) options.value.unique orelse false else false,
        .multi_entry = if (options.wasPassed()) options.value.multiEntry orelse false else false,
    };

    const index = store.createIndex(name_slice, "", backend_options) catch |err| {
        return switch (err) {
            error.ConstraintError => error.ConstraintError,
            error.InvalidStateError => error.InvalidState,
            error.TransactionInactiveError => error.TransactionInactiveError,
            else => error.InvalidState,
        };
    };

    return wrapIndex(instance, internal, index);
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
