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

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    cursor: ?*storage.indexeddb.IDBCursor = null,
    source: ?*runtime.Instance = null,
    request: ?*runtime.Instance = null,
};
pub fn installHooks() void {
    dom.indexeddb.installCursors(.{ .attach = attachCursor, .state = cursorState });
}
fn cursorState(instance: *runtime.Instance) ?*storage.indexeddb.IDBCursor {
    return (instance.getState(State).own._internal orelse return null).cursor;
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
    internal.request = request;
    engine.traceChild(instance, source, .{ .name = "idb.source" });
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
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        engine.forgetTracedChild(instance, .{ .name = "idb.source" });
        engine.forgetTracedChild(instance, .{ .name = "idb.request" });
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
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return .{ .instance = internal.source orelse return error.InvalidStateError };
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
    const cursor = cursorState(instance) orelse return error.InvalidStateError;
    const key = cursor.key orelse return .jsUndefined;
    return (try dom.indexeddb_keys.toValue(instance.ctx, key)).take();
}

/// Getter for primaryKey
pub fn get_primaryKey(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const cursor = cursorState(instance) orelse return error.InvalidStateError;
    const key = cursor.primary_key orelse return .jsUndefined;
    return (try dom.indexeddb_keys.toValue(instance.ctx, key)).take();
}

/// Getter for request
pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (instance.getState(State).own._internal orelse return error.InvalidStateError).request orelse error.InvalidStateError;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: continue
pub fn call_continue(instance: *runtime.Instance, key: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = instance;
    _ = key;
    return error.NotImplemented;
}

/// Operation: continuePrimaryKey
pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: runtime.JSValue, primaryKey: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = key;
    _ = primaryKey;
    return error.NotImplemented;
}

/// Operation: update
pub fn call_update(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: advance
pub fn call_advance(instance: *runtime.Instance, count: u32) anyerror!void {
    _ = instance;
    _ = count;
    return error.NotImplemented;
}
