//! IndexedDB ED 2.12 and 4.8: an independently owned record snapshot.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const storage = @import("storage");
const dom = @import("dom");
const engine = @import("engine");
const IDBRecord = interfaces.IDBRecord;

pub const State = IDBRecord.State;

pub const ImplError = error{
    InvalidStateError,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    snapshot: ?storage.indexeddb.RecordSnapshot = null,
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
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.snapshot) |*snapshot| snapshot.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

pub fn installHooks() void {
    dom.indexeddb.installRecords(.{ .attach_snapshot = attachSnapshot });
}
fn attachSnapshot(instance: *runtime.Instance, key: storage.indexeddb.IDBKey, primary_key: storage.indexeddb.IDBKey, bytes: []const u8) !void {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    std.debug.assert(internal.snapshot == null);
    internal.snapshot = try storage.indexeddb.RecordSnapshot.init(internal.allocator, key, primary_key, bytes);
}

/// Getter for key
pub fn get_key(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return readKey(instance);
}

/// Getter for primaryKey
pub fn get_primaryKey(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return readPrimaryKey(instance);
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return readValue(instance);
}

fn snapshotFor(instance: *runtime.Instance) !*const storage.indexeddb.RecordSnapshot {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return if (internal.snapshot) |*snapshot| snapshot else error.InvalidStateError;
}
// 4.8 key and primaryKey getters: convert owned native keys in this realm.
fn readKey(instance: *runtime.Instance) !runtime.JSValue {
    return (try dom.indexeddb_keys.toValue(instance.ctx, (try snapshotFor(instance)).key)).take();
}
fn readPrimaryKey(instance: *runtime.Instance) !runtime.JSValue {
    return (try dom.indexeddb_keys.toValue(instance.ctx, (try snapshotFor(instance)).primary_key)).take();
}
// Q12/Q17 accepted interim until REALMS3 ON MAIN: one rebuild site, no strong
// value root field. Value identity remains pinned by the pending Crane test.
fn readValue(instance: *runtime.Instance) !runtime.JSValue {
    return (try engine.structuredDeserialize(instance.ctx, (try snapshotFor(instance)).value)).take();
}
