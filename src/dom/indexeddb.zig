//! Non-IDL IndexedDB steps, installed once by their owning interfaces.
//!
//! lint-impls: hook for IDBFactory, IDBRequest, IDBOpenDBRequest, IDBDatabase, IDBTransaction, IDBObjectStore, IDBIndex, IDBCursor, IDBKeyRange, IDBRecord
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const storage = @import("storage");
const process_start = @import("process_start.zig");

pub const FactorySteps = struct {
    register: *const fn (*runtime.Instance, *runtime.Instance, []const u8, []const u8) anyerror!void,
    unregister: *const fn (*runtime.Instance, *runtime.Instance) void,
    advance: *const fn (*runtime.Instance, []const u8, []const u8) void,
};
pub const RequestSteps = struct {
    set_pending: *const fn (*runtime.Instance) void,
    set_source: *const fn (*runtime.Instance, ?*runtime.Instance) void,
    complete_serialized: *const fn (*runtime.Instance, []const u8) anyerror!void,
    get_the_parent: *const fn (*runtime.Instance) ?*runtime.Instance,
    /// Set the done flag, result and error. The platform-object result is borrowed.
    complete: *const fn (*runtime.Instance, runtime.JSValue, ?*runtime.Instance) anyerror!void,
    set_transaction: *const fn (*runtime.Instance, ?*runtime.Instance) void,
};
pub const OpenRequestSteps = struct {
    /// Transfer the backend request to its wrapper.
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBOpenDBRequest) void,
};
pub const DatabaseSteps = struct {
    close_if_ready: *const fn (*runtime.Instance) void,
    is_closing: *const fn (*runtime.Instance) bool,
    set_factory: *const fn (*runtime.Instance, *runtime.Instance) void,
    /// Transfer the backend connection to its wrapper.
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBDatabase) anyerror!void,
    begin_upgrade: *const fn (*runtime.Instance) anyerror!*runtime.Instance,
    end_upgrade: *const fn (*runtime.Instance) void,
};
pub const StoreSteps = struct {
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBObjectStore, *runtime.Instance, bool) anyerror!void,
};
pub const IndexSteps = struct {
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBIndex, *runtime.Instance) anyerror!void,
};
pub const CursorSteps = struct {
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBCursor, *runtime.Instance, *runtime.Instance) anyerror!void,
    /// Native cursor state for the descendant's value getter, borrowed for call.
    state: *const fn (*runtime.Instance) ?*storage.indexeddb.IDBCursor,
};

pub const KeyRangeSteps = struct {
    copy: *const fn (*runtime.Instance, std.mem.Allocator) anyerror!storage.indexeddb.IDBKeyRange,
};
pub const RecordSteps = struct {
    attach_snapshot: *const fn (*runtime.Instance, storage.indexeddb.IDBKey, storage.indexeddb.IDBKey, []const u8) anyerror!void,
};

// process-wide: hook table written once at process start by IDBRecord.installHooks (B0); comptime in B9
var records: ?RecordSteps = null;

pub fn installRecords(steps: RecordSteps) void {
    process_start.assertInstalling();
    records = steps;
}
pub fn attachRecordSnapshot(instance: *runtime.Instance, key: storage.indexeddb.IDBKey, primary_key: storage.indexeddb.IDBKey, bytes: []const u8) !void {
    try (records orelse return error.NotSupported).attach_snapshot(instance, key, primary_key, bytes);
}
pub const TransactionSteps = struct {
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBTransaction, *runtime.Instance) anyerror!void,
    end_event: *const fn (*runtime.Instance, bool) anyerror!bool,
    finish: *const fn (*runtime.Instance, bool) anyerror!bool,
    get_the_parent: *const fn (*runtime.Instance) ?*runtime.Instance,
    /// Cleanup IndexedDB transactions step 2: deactivate and clear cleanup event loop.
    cleanup: *const fn (*runtime.Instance) void,
};

// process-wide: hook table written once at process start by IDBFactory.installHooks (B0); comptime in B9
var factories: ?FactorySteps = null;

// process-wide: hook table written once at process start by IDBRequest.installHooks (B0); comptime in B9
var requests: ?RequestSteps = null;
// process-wide: hook table written once at process start by IDBOpenDBRequest.installHooks (B0); comptime in B9
var open_requests: ?OpenRequestSteps = null;
// process-wide: hook table written once at process start by IDBDatabase.installHooks (B0); comptime in B9
var databases: ?DatabaseSteps = null;
// process-wide: hook table written once at process start by IDBTransaction.installHooks (B0); comptime in B9
var transactions: ?TransactionSteps = null;

// process-wide: hook table written once at process start by IDBObjectStore.installHooks (B0); comptime in B9
var stores: ?StoreSteps = null;
// process-wide: hook table written once at process start by IDBIndex.installHooks (B0); comptime in B9
var indexes: ?IndexSteps = null;
// process-wide: hook table written once at process start by IDBCursor.installHooks (B0); comptime in B9
var cursors: ?CursorSteps = null;

pub fn installStores(steps: StoreSteps) void {
    process_start.assertInstalling();
    stores = steps;
}
pub fn installIndexes(steps: IndexSteps) void {
    process_start.assertInstalling();
    indexes = steps;
}
pub fn installCursors(steps: CursorSteps) void {
    process_start.assertInstalling();
    cursors = steps;
}
pub fn attachStore(instance: *runtime.Instance, store: *storage.indexeddb.IDBObjectStore, transaction: *runtime.Instance, transfer: bool) !void {
    try (stores orelse return error.NotSupported).attach(instance, store, transaction, transfer);
}
pub fn attachIndex(instance: *runtime.Instance, index: *storage.indexeddb.IDBIndex, store: *runtime.Instance) !void {
    try (indexes orelse return error.NotSupported).attach(instance, index, store);
}
pub fn attachCursor(instance: *runtime.Instance, cursor: *storage.indexeddb.IDBCursor, source: *runtime.Instance, request: *runtime.Instance) !void {
    try (cursors orelse return error.NotSupported).attach(instance, cursor, source, request);
}
pub fn cursorState(instance: *runtime.Instance) ?*storage.indexeddb.IDBCursor {
    return (cursors orelse return null).state(instance);
}

pub fn installRequests(steps: RequestSteps) void {
    process_start.assertInstalling();
    requests = steps;
}
pub fn installOpenRequests(steps: OpenRequestSteps) void {
    process_start.assertInstalling();
    open_requests = steps;
}
pub fn installDatabases(steps: DatabaseSteps) void {
    process_start.assertInstalling();
    databases = steps;
}
pub fn installTransactions(steps: TransactionSteps) void {
    process_start.assertInstalling();
    transactions = steps;
}

pub fn completeRequest(instance: *runtime.Instance, result: runtime.JSValue, exception: ?*runtime.Instance) !void {
    return (requests orelse return error.NotSupported).complete(instance, result, exception);
}
pub fn setRequestTransaction(instance: *runtime.Instance, transaction: ?*runtime.Instance) void {
    (requests orelse return).set_transaction(instance, transaction);
}
pub fn attachOpenRequest(instance: *runtime.Instance, request: *storage.indexeddb.IDBOpenDBRequest) void {
    (open_requests orelse @panic("IDBOpenDBRequest hooks missing")).attach(instance, request);
}
pub fn attachDatabase(instance: *runtime.Instance, database: *storage.indexeddb.IDBDatabase) !void {
    try (databases orelse return error.NotSupported).attach(instance, database);
}
pub fn cleanupTransaction(instance: *runtime.Instance) void {
    (transactions orelse return).cleanup(instance);
}

/// Agent-owned transaction cleanup list (IndexedDB 2.7). Entries are borrowed;
/// the transaction removes itself before destruction.
pub const CleanupList = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(*runtime.Instance) = .empty,

    pub fn init(allocator: std.mem.Allocator) CleanupList {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *CleanupList) void {
        self.entries.deinit(self.allocator);
    }
    pub fn add(self: *CleanupList, transaction: *runtime.Instance) !void {
        for (self.entries.items) |entry| if (entry == transaction) return;
        try self.entries.append(self.allocator, transaction);
    }
    pub fn remove(self: *CleanupList, transaction: *runtime.Instance) void {
        for (self.entries.items, 0..) |entry, index| {
            if (entry == transaction) {
                _ = self.entries.orderedRemove(index);
                return;
            }
        }
    }
    pub fn cleanup(self: *CleanupList) void {
        // Steps 1-2: consume each transaction before invoking its cleanup.
        // The owning hook can remove another entry without invalidating iteration.
        while (self.entries.items.len != 0) {
            const transaction = self.entries.orderedRemove(0);
            cleanupTransaction(transaction);
        }
    }
};

test "IndexedDB cleanup list owns storage but borrows unique transactions" {
    var list = CleanupList.init(std.testing.allocator);
    defer list.deinit();
    var first: runtime.Instance = undefined;
    var second: runtime.Instance = undefined;
    try list.add(&first);
    try list.add(&first);
    try list.add(&second);
    try std.testing.expectEqual(@as(usize, 2), list.entries.items.len);
    list.remove(&first);
    try std.testing.expectEqual(&second, list.entries.items[0]);
    list.remove(&second);
    try std.testing.expectEqual(@as(usize, 0), list.entries.items.len);
}

/// The four IndexedDB get-the-parent algorithms (ED 2.7, 2.8).
pub fn getTheParent(target: *runtime.Instance) ?*runtime.Instance {
    if (target.stateAs(interfaces.IDBOpenDBRequest.State) != null) return null;
    if (target.stateAs(interfaces.IDBRequest.State) != null) {
        return (requests orelse return null).get_the_parent(target);
    }
    if (target.stateAs(interfaces.IDBTransaction.State) != null) {
        return (transactions orelse return null).get_the_parent(target);
    }
    // A connection, and every other non-IDB target, has no IDB parent.
    return null;
}

pub fn beginUpgrade(instance: *runtime.Instance) !*runtime.Instance {
    return (databases orelse return error.NotSupported).begin_upgrade(instance);
}
pub fn endUpgrade(instance: *runtime.Instance) void {
    (databases orelse return).end_upgrade(instance);
}
pub fn attachTransaction(instance: *runtime.Instance, transaction: *storage.indexeddb.IDBTransaction, database: *runtime.Instance) !void {
    try (transactions orelse return error.NotSupported).attach(instance, transaction, database);
}
pub fn finishTransaction(instance: *runtime.Instance, abort: bool) !bool {
    return (transactions orelse return error.NotSupported).finish(instance, abort);
}

/// Q5's accepted interim: registration needs the not-yet-landed agent host
/// protocol operation. No transaction registry belongs to a process or thread.
pub fn agentCleanupList(realm: runtime.Context) ?*CleanupList {
    _ = realm;
    return null;
}

pub fn setRequestPending(instance: *runtime.Instance) void {
    (requests orelse return).set_pending(instance);
}
pub fn setRequestSource(instance: *runtime.Instance, source: ?*runtime.Instance) void {
    (requests orelse return).set_source(instance, source);
}
pub fn completeSerializedRequest(instance: *runtime.Instance, bytes: []const u8) !void {
    try (requests orelse return error.NotSupported).complete_serialized(instance, bytes);
}

pub fn installFactories(steps: FactorySteps) void {
    process_start.assertInstalling();
    factories = steps;
}
pub fn registerConnection(factory: *runtime.Instance, connection: *runtime.Instance, origin: []const u8, name: []const u8) !void {
    try (factories orelse return error.NotSupported).register(factory, connection, origin, name);
}
pub fn unregisterConnection(factory: *runtime.Instance, connection: *runtime.Instance) void {
    (factories orelse return).unregister(factory, connection);
}
pub fn advanceConnectionQueue(factory: *runtime.Instance, origin: []const u8, name: []const u8) void {
    (factories orelse return).advance(factory, origin, name);
}
pub fn setDatabaseFactory(connection: *runtime.Instance, factory: *runtime.Instance) void {
    (databases orelse return).set_factory(connection, factory);
}

pub fn closeConnectionIfReady(connection: *runtime.Instance) void {
    (databases orelse return).close_if_ready(connection);
}
pub fn connectionIsClosing(connection: *runtime.Instance) bool {
    return (databases orelse return true).is_closing(connection);
}
pub fn endTransactionEvent(transaction: *runtime.Instance, did_throw: bool) !bool {
    return (transactions orelse return error.NotSupported).end_event(transaction, did_throw);
}

// process-wide: hook table written once at process start by IDBKeyRange.installHooks (B0); comptime in B9
var key_ranges: ?KeyRangeSteps = null;
pub fn installKeyRanges(steps: KeyRangeSteps) void {
    process_start.assertInstalling();
    key_ranges = steps;
}
pub fn copyKeyRange(instance: *runtime.Instance, allocator: std.mem.Allocator) !storage.indexeddb.IDBKeyRange {
    return (key_ranges orelse return error.NotSupported).copy(instance, allocator);
}
