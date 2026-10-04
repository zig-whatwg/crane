//! Implementation for IDBCursor interface

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
const IDBCursor = interfaces.IDBCursor;

pub const State = IDBCursor.State;

pub const ImplError = error{InvalidStateError};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    cursor: ?*storage.indexeddb.IDBCursor = null,
    source: ?*runtime.Instance = null,
    source_realm: ?runtime.Context = null,
    request: ?*runtime.Instance = null,
    request_realm: ?runtime.Context = null,
    /// Realm captured by the iteration that produced the visible value.
    value_realm: runtime.Context,
    /// Each lazy key getter captures its own conversion realm (ED 4.9/7.3).
    key_realm: ?runtime.Context = null,
    primary_key_realm: ?runtime.Context = null,
};
pub fn installHooks() void {
    dom.indexeddb.installCursors(.{ .attach = attachCursor, .state = cursorState, .value_realm = valueRealm, .execute = executeOperation });
}
fn cursorState(instance: *runtime.Instance) ?*storage.indexeddb.IDBCursor {
    return (instance.getState(State).own._internal orelse return null).cursor;
}
fn valueRealm(instance: *runtime.Instance) runtime.Context {
    return (instance.getState(State).own._internal orelse return instance.ctx).value_realm;
}
fn attachCursor(instance: *runtime.Instance, cursor: *storage.indexeddb.IDBCursor, source: *runtime.Instance, request: *runtime.Instance) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    std.debug.assert(internal.cursor == null);
    const store = switch (cursor.source) {
        .object_store => |store| store,
        .index => |index| index.object_store,
    };
    store.retain();
    store.transaction.retain();
    internal.cursor = cursor;
    internal.source = source;
    internal.source_realm = source.ctx;
    internal.request = request;
    internal.request_realm = request.ctx;
    // ED 4.5/4.6 openCursor step 7: the first iteration captured the same
    // current realm as the request, independently of this cursor's realm.
    internal.value_realm = request.ctx;
    engine.traceValue(instance, .{ .instance = source }, .{ .name = "idb.source" });
    engine.traceChild(instance, request, .{ .name = "idb.request" });
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
    // Initialize this owner's state even when the wrapper is IDBCursorWithValue.
    const state = instance.getState(State);
    state.own._internal = null;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .value_realm = ctx };
    state.own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        engine.forgetTracedChild(instance, .{ .name = "idb.source" });
        engine.forgetTracedChild(instance, .{ .name = "idb.request" });
        engine.forgetTracedChild(instance, .{ .name = "idb.cursor.key" });
        engine.forgetTracedChild(instance, .{ .name = "idb.cursor.primaryKey" });
        if (internal.cursor) |cursor| {
            const store = switch (cursor.source) {
                .object_store => |store| store,
                .index => |index| index.object_store,
            };
            const transaction = store.transaction;
            cursor.deinit();
            cursor.allocator.destroy(cursor);
            store.deinit();
            transaction.deinit();
        }
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

/// Getter for source
pub fn get_source(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (instance.getState(State).own._internal == null or !instance.ctx.hasEngine()) return error.InvalidStateError;
    // ED 4.9 returns the source object itself, including after its realm
    // retires and its native wrapper association has been severed.
    return (engine.tracedValue(instance, .{ .name = "idb.source" }) orelse return error.InvalidStateError).take();
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) anyerror!enums.IDBCursorDirection {
    const cursor = cursorState(instance) orelse return error.InvalidStateError;
    return switch (cursor.direction) {
        .next => ._next_,
        .nextunique => ._nextunique_,
        .prev => ._prev_,
        .prevunique => ._prevunique_,
    };
}

/// Getter for key
pub fn get_key(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (!instance.ctx.hasEngine()) return error.InvalidStateError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (internal.key_realm) |realm| if (!realm.hasEngine()) return error.InvalidStateError;
    if (engine.tracedValue(instance, .{ .name = "idb.cursor.key" })) |value| return value.take();
    const cursor = internal.cursor orelse return error.InvalidStateError;
    const key = cursor.key orelse return .jsUndefined;
    // ED 4.9 key getter / 7.3: convert in this getter's current realm,
    // then preserve object identity until iteration changes the native key.
    const realm = engine.currentRealm() orelse instance.ctx;
    if (!realm.hasEngine()) return error.InvalidStateError;
    const value = try dom.indexeddb_keys.toValue(realm, key);
    engine.traceValue(instance, value.value, .{ .name = "idb.cursor.key" });
    internal.key_realm = realm;
    return value.take();
}

/// Getter for primaryKey
pub fn get_primaryKey(instance: *runtime.Instance) anyerror!runtime.JSValue {
    if (!instance.ctx.hasEngine()) return error.InvalidStateError;
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (internal.primary_key_realm) |realm| if (!realm.hasEngine()) return error.InvalidStateError;
    if (engine.tracedValue(instance, .{ .name = "idb.cursor.primaryKey" })) |value| return value.take();
    const cursor = internal.cursor orelse return error.InvalidStateError;
    const key = cursor.primary_key orelse return .jsUndefined;
    // ED 4.9 primaryKey getter / 7.3 has the same lazy conversion rule.
    const realm = engine.currentRealm() orelse instance.ctx;
    if (!realm.hasEngine()) return error.InvalidStateError;
    const value = try dom.indexeddb_keys.toValue(realm, key);
    engine.traceValue(instance, value.value, .{ .name = "idb.cursor.primaryKey" });
    internal.primary_key_realm = realm;
    return value.take();
}

/// Getter for request
pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    if (!(internal.request_realm orelse return error.InvalidStateError).hasEngine()) return error.InvalidStateError;
    return internal.request orelse error.InvalidStateError;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = try usable(instance, true);
    const cursor = internal.cursor.?;
    // ED 4.9 delete steps 5-8: snapshot the effective key at placement.
    if (!cursor.got_value or cursor.key_only) return error.InvalidStateError;
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = .delete };
    errdefer operation.deinit();
    operation.cursor_write = try cursor.captureWriteSource(internal.allocator);
    return dom.indexeddb.enqueueRequest(try requestTransaction(internal), instance, operation, null);
}

/// Operation: continue
pub fn call_continue(instance: *runtime.Instance, key: webidl.Opt(runtime.JSValue)) anyerror!void {
    const internal = try usable(instance, false);
    const cursor = internal.cursor.?;
    if (!cursor.got_value) return error.InvalidStateError;
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = .iterate_cursor, .cursor = instance };
    errdefer operation.deinit();
    // continue step 5: undefined is the optional argument's missing value.
    if (key.wasPassed() and !key.value.isUndefined()) {
        operation.key = try dom.indexeddb_keys.require(instance.ctx, key.value, internal.allocator);
        const order = storage.indexeddb.compareKeys(operation.key.?, cursor.key.?);
        if ((forward(cursor) and order <= 0) or (!forward(cursor) and order >= 0)) return error.DataError;
    }
    try enqueueIteration(internal, operation);
}

/// Operation: continuePrimaryKey
pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: runtime.JSValue, primaryKey: runtime.JSValue) anyerror!void {
    const internal = try usable(instance, false);
    const cursor = internal.cursor.?;
    // continuePrimaryKey steps 4-6 precede either argument's key conversion.
    if (cursor.source != .index or (cursor.direction != .next and cursor.direction != .prev)) return error.InvalidAccessError;
    if (!cursor.got_value) return error.InvalidStateError;
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = .iterate_cursor, .cursor = instance };
    errdefer operation.deinit();
    operation.key = try dom.indexeddb_keys.require(instance.ctx, key, internal.allocator);
    operation.primary_key = try dom.indexeddb_keys.require(instance.ctx, primaryKey, internal.allocator);
    // Steps 13-16 compare the saved (index key, object-store key) position.
    const order = storage.indexeddb.compareKeys(operation.key.?, cursor.key.?);
    const primary_order = storage.indexeddb.compareKeys(operation.primary_key.?, cursor.primary_key.?);
    if (cursor.direction == .next) {
        if (order < 0 or (order == 0 and primary_order <= 0)) return error.DataError;
    } else if (order > 0 or (order == 0 and primary_order >= 0)) return error.DataError;
    try enqueueIteration(internal, operation);
}

/// Operation: update
pub fn call_update(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
    const internal = try usable(instance, true);
    const cursor = internal.cursor.?;
    if (!cursor.got_value or cursor.key_only) return error.InvalidStateError;
    const store = effectiveStore(cursor);
    var operation = dom.indexeddb.Operation{ .allocator = internal.allocator, .kind = .put };
    errdefer operation.deinit();
    operation.cursor_write = try cursor.captureWriteSource(internal.allocator);
    // update step 8 / 5.11 steps 2-5: clone while inactive.
    const clone = blk: {
        store.transaction.state = .inactive;
        // Deviation: ED 5.11 steps 3-5's ? skips restoration on failure
        // (w3c/IndexedDB#490). WPT key-conversion-exceptions/keypath-exceptions
        // and WebKit IDBCursor::update restore before propagating the error.
        defer if (store.transaction.state == .inactive) {
            store.transaction.state = .active;
        };
        operation.bytes = try engine.structuredSerializeForStorage(instance.ctx, value, internal.allocator);
        break :blk try engine.structuredDeserialize(instance.ctx, operation.bytes.?);
    };
    defer clone.release();
    // Step 9: an inline key must equal the cursor's saved effective key.
    if (dom.indexeddb.storeKeyPath(store)) |path| {
        var key = switch (try dom.indexeddb_keys.extract(instance.ctx, clone.value, path, false, internal.allocator)) {
            .key => |extracted| extracted,
            .invalid, .failure => return error.DataError,
        };
        defer key.deinit();
        if (storage.indexeddb.compareKeys(key, operation.cursor_write.?.key) != 0) return error.DataError;
    }
    try dom.indexeddb.captureWriteIndexes(store, &operation);
    return dom.indexeddb.enqueueRequest(try requestTransaction(internal), instance, operation, null);
}

/// Operation: advance
pub fn call_advance(instance: *runtime.Instance, count: u32) anyerror!void {
    // advance step 1 runs even for an inactive transaction or deleted source.
    if (count == 0) return error.TypeError;
    const internal = try usable(instance, false);
    if (!internal.cursor.?.got_value) return error.InvalidStateError;
    try enqueueIteration(internal, .{ .allocator = internal.allocator, .kind = .iterate_cursor, .cursor = instance, .advance = count });
}

fn effectiveStore(cursor: *storage.indexeddb.IDBCursor) *storage.indexeddb.IDBObjectStore {
    return switch (cursor.source) {
        .object_store => |store| store,
        .index => |index| index.object_store,
    };
}
fn usable(instance: *runtime.Instance, writing: bool) !*InternalState {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const cursor = internal.cursor orelse return error.InvalidStateError;
    const store = effectiveStore(cursor);
    // ED 4.9: active, mode (for writes), then source deletion, in that order.
    if (store.transaction.state != .active) return error.TransactionInactiveError;
    if (writing and store.transaction.mode == .readonly) return error.ReadOnlyError;
    if (store.isDeleted() or (cursor.source == .index and cursor.source.index.deleted)) return error.InvalidStateError;
    return internal;
}
fn requestTransaction(internal: *InternalState) !*runtime.Instance {
    if (!(internal.request_realm orelse return error.InvalidStateError).hasEngine()) return error.InvalidStateError;
    return (try interfaces.IDBRequest.get_transaction(internal.request.?)) orelse error.InvalidStateError;
}
fn forward(cursor: *storage.indexeddb.IDBCursor) bool {
    return cursor.direction == .next or cursor.direction == .nextunique;
}
fn enqueueIteration(internal: *InternalState, operation: dom.indexeddb.Operation) !void {
    // advance 6-11, continue 6-11, continuePrimaryKey 17-22: reuse the same
    // request, preserving its source and the visible cursor snapshot for now.
    const transaction = try requestTransaction(internal);
    if (!(internal.source_realm orelse return error.InvalidStateError).hasEngine()) return error.InvalidStateError;
    _ = try dom.indexeddb.enqueueRequest(transaction, internal.source.?, operation, internal.request.?);
    internal.cursor.?.got_value = false;
}
fn executeOperation(instance: *runtime.Instance, request: *runtime.Instance, operation: *dom.indexeddb.Operation) !void {
    if (operation.kind != .iterate_cursor) return error.InvalidStateError;
    const cursor = cursorState(instance) orelse return error.InvalidStateError;
    // Placement already validated the got-value flag. Temporarily restore
    // it for the native iteration entry point, without running script.
    cursor.got_value = true;
    if (operation.advance) |count| {
        try cursor.advance(count);
    } else if (operation.primary_key) |primary| {
        try cursor.continuePrimaryKey(operation.key.?, primary);
    } else try cursor.@"continue"(operation.key);
    // 6.7 steps 10-14 replace the JS snapshots only as data is loaded.
    // Step 13 captures each invocation's realm, including when the
    // original request and cursor were created in a different realm.
    const internal = instance.getState(State).own._internal.?;
    internal.value_realm = operation.target_realm orelse request.ctx;
    engine.forgetTracedChild(instance, .{ .name = "idb.cursor.key" });
    engine.forgetTracedChild(instance, .{ .name = "idb.cursor.primaryKey" });
    engine.forgetTracedChild(instance, .{ .name = "idb.cursor.value" });
    internal.key_realm = null;
    internal.primary_key_realm = null;
    return dom.indexeddb.completeRequest(request, if (cursor.got_value) .{ .instance = instance } else .jsNull, null);
}
