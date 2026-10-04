//! Implementation for IDBIndex interface

const std = @import("std");
const dom = @import("dom");
const engine = @import("engine");
const storage = @import("storage");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const IDBIndex = interfaces.IDBIndex;

pub const State = IDBIndex.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    index: ?*storage.indexeddb.IDBIndex = null,
    store: ?*runtime.Instance = null,
};
pub fn installHooks() void {
    dom.indexeddb.installIndexes(.{ .attach = attachIndex, .execute = executeOperation, .populate = populate });
}
fn populate(instance: *runtime.Instance) !void {
    try dom.indexeddb.populateIndex(instance.ctx, try indexState(instance));
}
fn attachIndex(instance: *runtime.Instance, index: *storage.indexeddb.IDBIndex, store: *runtime.Instance) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    std.debug.assert(internal.index == null);
    index.object_store.retain();
    index.object_store.transaction.retain();
    internal.index = index;
    internal.store = store;
    engine.traceChild(instance, store, .{ .name = "idb.store" });
}
fn indexState(instance: *runtime.Instance) !*storage.indexeddb.IDBIndex {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.index orelse error.InvalidStateError;
}

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
    state.own._internal = null;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        engine.forgetTracedChild(instance, .{ .name = "idb.store" });
        engine.forgetTracedChild(instance, .{ .name = "idb.keyPath" });
        if (internal.index) |index| {
            const store = index.object_store;
            const transaction = store.transaction;
            store.deinit();
            transaction.deinit();
        }
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try indexState(instance)).name);
}

/// Getter for objectStore
pub fn get_objectStore(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (instance.getState(State).own._internal orelse return error.InvalidStateError).store orelse error.InvalidStateError;
}

/// Getter for keyPath
pub fn get_keyPath(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const index = try indexState(instance);
    return dom.indexeddb_keys.keyPathValue(instance, index.effectiveKeyPath());
}

/// Getter for multiEntry
pub fn get_multiEntry(instance: *runtime.Instance) anyerror!bool {
    return (try indexState(instance)).multi_entry;
}

/// Getter for unique
pub fn get_unique(instance: *runtime.Instance) anyerror!bool {
    return (try indexState(instance)).unique;
}

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try (try indexState(instance)).rename(value.asSlice());
}

// ED 4.6: source deletion precedes active-transaction validation.
fn usable(instance: *runtime.Instance) !*InternalState {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const index = internal.index orelse return error.InvalidStateError;
    if (index.deleted or index.object_store.isDeleted()) return error.InvalidStateError;
    if (index.object_store.transaction.state != .active) return error.TransactionInactiveError;
    return internal;
}
fn enqueue(instance: *runtime.Instance, operation: dom.indexeddb.Operation) !*runtime.Instance {
    const internal = instance.getState(State).own._internal.?;
    const transaction = try interfaces.IDBObjectStore.get_transaction(internal.store.?);
    return dom.indexeddb.enqueueRequest(transaction, instance, operation, null);
}
fn queueQuery(instance: *runtime.Instance, kind: dom.indexeddb.OperationKind, query: runtime.JSValue, unbounded: bool) !*runtime.Instance {
    const internal = try usable(instance);
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = kind };
    errdefer operation.deinit();
    operation.range = try dom.indexeddb_keys.queryRange(instance.ctx, query, unbounded, internal.allocator);
    return enqueue(instance, operation);
}
pub fn call_get(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    return queueQuery(instance, .get, query, false);
}
pub fn call_getKey(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    return queueQuery(instance, .get_key, query, false);
}
pub fn call_count(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    return queueQuery(instance, .count, if (query.wasPassed()) query.value else .jsUndefined, true);
}
pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    return queueAll(instance, .all_values, queryOrOptions, count);
}
pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    return queueAll(instance, .all_keys, queryOrOptions, count);
}
fn queueAll(instance: *runtime.Instance, kind: dom.indexeddb.OperationKind, query: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) !*runtime.Instance {
    const internal = try usable(instance);
    var operation = try dom.indexeddb_keys.multipleItems(instance.ctx, kind, if (query.wasPassed()) query.value else .jsUndefined, if (count.wasPassed()) count.value else null, internal.allocator);
    errdefer operation.deinit();
    return enqueue(instance, operation);
}
pub fn call_getAllRecords(instance: *runtime.Instance, options: webidl.Opt(dictionaries.IDBGetAllOptions)) anyerror!*runtime.Instance {
    const internal = try usable(instance);
    const converted = if (options.wasPassed()) options.value else dictionaries.IDBGetAllOptions{};
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = .all_records, .limit = converted.count, .direction = dom.indexeddb_keys.cursorDirection(converted.direction orelse ._next_) };
    errdefer operation.deinit();
    operation.range = try dom.indexeddb_keys.queryRange(instance.ctx, converted.query orelse .jsUndefined, true, internal.allocator);
    return enqueue(instance, operation);
}
pub fn call_openCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    return queueCursor(instance, query, direction, false);
}
pub fn call_openKeyCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    return queueCursor(instance, query, direction, true);
}
fn queueCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection), key_only: bool) !*runtime.Instance {
    const internal = try usable(instance);
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = if (key_only) .open_key_cursor else .open_cursor, .direction = dom.indexeddb_keys.cursorDirection(if (direction.wasPassed()) direction.value else ._next_) };
    errdefer operation.deinit();
    operation.range = try dom.indexeddb_keys.queryRange(instance.ctx, if (query.wasPassed()) query.value else .jsUndefined, true, internal.allocator);
    return enqueue(instance, operation);
}
fn executeOperation(instance: *runtime.Instance, request: *runtime.Instance, operation: *dom.indexeddb.Operation) !void {
    const index = try indexState(instance);
    const native = switch (operation.kind) {
        .get => try index.get(operation.range),
        .get_key => try index.getKey(operation.range),
        .count => try index.count(operation.range),
        .all_values, .all_keys, .all_records, .open_cursor, .open_key_cursor => return dom.indexeddb.retrieve(instance, request, .{ .index = index }, operation),
        else => return error.InvalidStateError,
    };
    defer index.allocator.destroy(native);
    defer native.deinit();
    try dom.indexeddb.completeNativeRequest(request, native);
}
