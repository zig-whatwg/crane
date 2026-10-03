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
    dom.indexeddb.installIndexes(.{ .attach = attachIndex });
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
    return if (index.key_path) |path| runtime.JSValue.fromStringRef(path) else .jsNull;
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
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getAll
pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    _ = instance;
    _ = queryOrOptions;
    _ = count;
    return error.NotImplemented;
}

/// Operation: openKeyCursor
pub fn call_openKeyCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    _ = instance;
    _ = query;
    _ = direction;
    return error.NotImplemented;
}

/// Operation: getAllRecords
pub fn call_getAllRecords(instance: *runtime.Instance, options: webidl.Opt(dictionaries.IDBGetAllOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: count
pub fn call_count(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: getKey
pub fn call_getKey(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, query: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: getAllKeys
pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: webidl.Opt(runtime.JSValue), count: webidl.Opt(u32)) anyerror!*runtime.Instance {
    _ = instance;
    _ = queryOrOptions;
    _ = count;
    return error.NotImplemented;
}

/// Operation: openCursor
pub fn call_openCursor(instance: *runtime.Instance, query: webidl.Opt(runtime.JSValue), direction: webidl.Opt(enums.IDBCursorDirection)) anyerror!*runtime.Instance {
    _ = instance;
    _ = query;
    _ = direction;
    return error.NotImplemented;
}
