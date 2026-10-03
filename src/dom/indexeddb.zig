//! Non-IDL IndexedDB steps, installed once by their owning interfaces.
//!
//! lint-impls: hook for IDBFactory, IDBRequest, IDBOpenDBRequest, IDBDatabase, IDBTransaction, IDBObjectStore, IDBIndex, IDBCursor, IDBKeyRange, IDBRecord
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const storage = @import("storage");
const process_start = @import("process_start.zig");
const engine = @import("engine");

pub const FactorySteps = struct {
    register: *const fn (*runtime.Instance, *runtime.Instance, []const u8, []const u8) anyerror!void,
    unregister: *const fn (*runtime.Instance, *runtime.Instance) void,
    advance: *const fn (*runtime.Instance, []const u8, []const u8) void,
    wake_transactions: ?*const fn (*runtime.Instance) void = null,
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
    register_transaction: ?*const fn (*runtime.Instance, *runtime.Instance) anyerror!void = null,
    remove_transaction: ?*const fn (*runtime.Instance, *runtime.Instance) void = null,
    wake_transactions: ?*const fn (*runtime.Instance) void = null,
    transaction_finished: ?*const fn (*runtime.Instance) void = null,
};
pub const StoreSteps = struct {
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBObjectStore, *runtime.Instance, bool) anyerror!void,
    execute: ?*const fn (*runtime.Instance, *runtime.Instance, *Operation) anyerror!void = null,
};
pub const IndexSteps = struct {
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBIndex, *runtime.Instance) anyerror!void,
    execute: ?*const fn (*runtime.Instance, *runtime.Instance, *Operation) anyerror!void = null,
    populate: ?*const fn (*runtime.Instance) anyerror!void = null,
};
pub const CursorSteps = struct {
    attach: *const fn (*runtime.Instance, *storage.indexeddb.IDBCursor, *runtime.Instance, *runtime.Instance) anyerror!void,
    /// Native cursor state for the descendant's value getter, borrowed for call.
    state: *const fn (*runtime.Instance) ?*storage.indexeddb.IDBCursor,
    /// Target realm of the iteration that produced the visible value.
    value_realm: *const fn (*runtime.Instance) runtime.Context,
    execute: ?*const fn (*runtime.Instance, *runtime.Instance, *Operation) anyerror!void = null,
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
    enqueue: ?*const fn (*runtime.Instance, *runtime.Instance, Operation, ?*runtime.Instance) anyerror!*runtime.Instance = null,
    enqueue_internal: ?*const fn (*runtime.Instance, *runtime.Instance, Operation) anyerror!void = null,
    outcome: ?*const fn (*runtime.Instance) ?bool = null,
    wake: ?*const fn (*runtime.Instance) void = null,
};

/// Owned arguments accepted by ED 5.6. Native pointers remain borrowed from
/// the request's traced source; byte strings and keys are copied at placement.
pub const OperationKind = enum { put, add, get, get_key, count, delete, clear, all_values, all_keys, all_records, open_cursor, open_key_cursor, iterate_cursor, populate_index };
pub const Operation = struct {
    allocator: std.mem.Allocator,
    kind: OperationKind,
    /// ED 4.5/4.6/4.9 capture the current realm for retrieval/iteration.
    /// Borrowed and not a root: these tasks run only on their own agent's
    /// event loop, so the inert Context record outlives them (Q22 contract).
    /// A queued step must check hasEngine() before using this realm.
    target_realm: ?runtime.Context = null,
    key: ?storage.indexeddb.IDBKey = null,
    primary_key: ?storage.indexeddb.IDBKey = null,
    range: storage.indexeddb.IDBKeyRange = storage.indexeddb.IDBKeyRange.unbounded(),
    bytes: ?[]const u8 = null,
    limit: ?u32 = null,
    direction: storage.indexeddb.IDBCursorDirection = .next,
    cursor: ?*runtime.Instance = null,
    advance: ?u32 = null,
    /// The traced source retains these handles, including any subsequently
    /// deleted index. Waiting transactions refresh each handle when started.
    indexes: ?[]*storage.indexeddb.IDBIndex = null,

    pub fn deinit(self: *Operation) void {
        if (self.key) |*key| key.deinit();
        if (self.primary_key) |*key| key.deinit();
        self.range.deinit();
        if (self.bytes) |bytes| self.allocator.free(bytes);
        if (self.indexes) |handles| self.allocator.free(handles);
    }
};

/// Transfer the operation's native arguments on success only.
pub fn enqueueRequest(transaction: *runtime.Instance, source: *runtime.Instance, operation: Operation, request: ?*runtime.Instance) !*runtime.Instance {
    const enqueue = (transactions orelse return error.NotSupported).enqueue orelse return error.NotSupported;
    return enqueue(transaction, source, operation, request);
}
/// Schema population occupies the same FIFO, without an observable request.
pub fn enqueueInternal(transaction: *runtime.Instance, source: *runtime.Instance, operation: Operation) !void {
    const enqueue = (transactions orelse return error.NotSupported).enqueue_internal orelse return error.NotSupported;
    try enqueue(transaction, source, operation);
}
pub fn executeInternal(source: *runtime.Instance) !void {
    const populate = (indexes orelse return error.NotSupported).populate orelse return error.NotSupported;
    try populate(source);
}
pub fn transactionOutcome(transaction: *runtime.Instance) ?bool {
    const outcome = (transactions orelse return null).outcome orelse return null;
    return outcome(transaction);
}
pub fn registerDatabaseTransaction(database: *runtime.Instance, transaction: *runtime.Instance) !void {
    const register = (databases orelse return error.NotSupported).register_transaction orelse return error.NotSupported;
    try register(database, transaction);
}
pub fn removeDatabaseTransaction(database: *runtime.Instance, transaction: *runtime.Instance) void {
    const remove = (databases orelse return).remove_transaction orelse return;
    remove(database, transaction);
}
pub fn wakeDatabaseTransactions(database: *runtime.Instance) void {
    const wake = (databases orelse return).wake_transactions orelse return;
    wake(database);
}
pub fn databaseTransactionFinished(database: *runtime.Instance) void {
    const finished = (databases orelse return).transaction_finished orelse return;
    finished(database);
}
pub fn wakeFactoryTransactions(factory: *runtime.Instance) void {
    const wake = (factories orelse return).wake_transactions orelse return;
    wake(factory);
}
pub fn wakeTransaction(transaction: *runtime.Instance) void {
    const wake = (transactions orelse return).wake orelse return;
    wake(transaction);
}
pub fn executeRequest(source: *runtime.Instance, request: *runtime.Instance, operation: *Operation) !void {
    if (operation.cursor) |cursor| {
        const execute = (cursors orelse return error.NotSupported).execute orelse return error.NotSupported;
        return execute(cursor, request, operation);
    }
    if (source.stateAs(interfaces.IDBObjectStore.State) != null) {
        const execute = (stores orelse return error.NotSupported).execute orelse return error.NotSupported;
        return execute(source, request, operation);
    }
    if (source.stateAs(interfaces.IDBIndex.State) != null) {
        const execute = (indexes orelse return error.NotSupported).execute orelse return error.NotSupported;
        return execute(source, request, operation);
    }
    return error.InvalidStateError;
}

/// Deliver a synchronous native operation's result before its borrowed data
/// can change. The request owner copies bytes or traces the produced value.
pub fn completeNativeRequest(request: *runtime.Instance, native: *storage.indexeddb.IDBRequest) !void {
    if (native.err) |err| return err;
    const result: storage.indexeddb.request.RequestResult = native.result orelse .{ .undefined = {} };
    switch (result) {
        .undefined => try completeRequest(request, .jsUndefined, null),
        .count => |count| try completeRequest(request, .{ .number = @floatFromInt(count) }, null),
        .value => |bytes| try completeSerializedRequest(request, bytes),
        .key => |key| {
            const value = try @import("indexeddb_keys.zig").toValue(request.ctx, key);
            defer value.release();
            try completeRequest(request, value.value, null);
        },
        else => return error.InvalidStateError,
    }
}

/// Snapshot the definitions that apply to an accepted write (ED 6.1 step 5).
/// A native handle survives logical deletion and is refreshed on transaction
/// start, so both schema ordering and waiting writers use the right records.
pub fn captureWriteIndexes(store: *storage.indexeddb.IDBObjectStore, operation: *Operation) !void {
    const names = try store.indexNames();
    defer store.allocator.free(names);
    const handles = try operation.allocator.alloc(*storage.indexeddb.IDBIndex, names.len);
    errdefer operation.allocator.free(handles);
    for (names, 0..) |name, i| handles[i] = try store.index(name);
    operation.indexes = handles;
}

pub fn storeKeyPath(store: *const storage.indexeddb.IDBObjectStore) ?storage.indexeddb.KeyPath {
    if (store.compound_key_path) |paths| return .{ .array = paths };
    if (store.key_path) |path| return .{ .single = path };
    return null;
}

/// ED 6.1 plus 5.6.5.4: finish all allocation and uniqueness checks before
/// publishing a record or any of its indexes. The native write is the last
/// fallible operation; index publication thereafter cannot fail.
pub fn executeStorageWrite(realm: runtime.Context, store: *storage.indexeddb.IDBObjectStore, operation: *Operation) anyerror!*storage.indexeddb.IDBRequest {
    const clone = try engine.structuredDeserialize(realm, operation.bytes.?);
    defer clone.release();
    const key = operation.key orelse blk: {
        const number = store.getCurrentKeyGeneratorValue();
        if (number > 9007199254740992) return error.ConstraintError;
        break :blk storage.indexeddb.IDBKey.number(@floatFromInt(number));
    };
    // Step 1.1.3: inject only into the clone, before extracting index keys.
    if (operation.key == null) if (storeKeyPath(store)) |path| {
        if (path != .single) return error.DataError;
        try @import("indexeddb_keys.zig").inject(realm, clone.value, key, path.single);
    };
    const bytes = try engine.structuredSerializeForStorage(realm, clone.value, operation.allocator);
    defer operation.allocator.free(bytes);
    const handles = operation.indexes orelse &.{};
    const staged = try operation.allocator.alloc(storage.indexeddb.IDBIndex.PreparedEntries, handles.len);
    var made: usize = 0;
    defer {
        for (staged[0..made]) |*entries| entries.deinit();
        operation.allocator.free(staged);
    }
    for (handles, 0..) |index, i| {
        var extracted = try extractIndexKey(realm, index, clone.value, operation.allocator);
        defer if (extracted) |*owned| owned.deinit();
        var single: [1]storage.indexeddb.IDBKey = undefined;
        const keys: []const storage.indexeddb.IDBKey = if (extracted) |owned| blk: {
            if (index.multi_entry and owned.key_type == .array) break :blk owned.value.array;
            single[0] = owned;
            break :blk &single;
        } else &.{};
        staged[i] = try index.prepareReplacementEntries(keys, key);
        made += 1;
    }
    const native = if (operation.kind == .add) try store.add(bytes, key) else try store.put(bytes, key);
    // Steps 3 and 5.5-5.6: old entries disappear even if extraction failed.
    for (handles, staged) |index, *entries| {
        index.removeEntriesForPrimaryKey(key);
        entries.commit(index);
    }
    return native;
}

/// createIndex's asynchronous population runs at its own position in the
/// upgrade FIFO. A failure aborts the transaction; it fires no request event.
pub fn populateIndex(realm: runtime.Context, index: *storage.indexeddb.IDBIndex) anyerror!void {
    for (index.object_store.recordsList().items) |record| {
        const value = try engine.structuredDeserialize(realm, record.value);
        defer value.release();
        var key = try extractIndexKey(realm, index, value.value, index.allocator) orelse continue;
        defer key.deinit();
        const keys: []const storage.indexeddb.IDBKey = if (index.multi_entry and key.key_type == .array) key.value.array else &.{key};
        var staged = try index.prepareEntries(keys, record.key);
        defer staged.deinit();
        staged.commit(index);
    }
}

fn extractIndexKey(realm: runtime.Context, index: *storage.indexeddb.IDBIndex, value: runtime.JSValue, allocator: std.mem.Allocator) anyerror!?storage.indexeddb.IDBKey {
    const Extraction = struct {
        realm: runtime.Context,
        index: *storage.indexeddb.IDBIndex,
        value: runtime.JSValue,
        allocator: std.mem.Allocator,
        result: @import("indexeddb_keys.zig").Extraction = .failure,
        fn steps(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const path = self.index.effectiveKeyPath() orelse return;
            self.result = @import("indexeddb_keys.zig").extract(self.realm, self.value, path, self.index.multi_entry, self.allocator) catch |err| switch (err) {
                error.ExceptionPending => return error.ExceptionPending,
                error.OutOfMemory => return error.OutOfMemory,
                else => return,
            };
        }
    };
    var extraction = Extraction{ .realm = realm, .index = index, .value = value, .allocator = allocator };
    // Step 5.2 consumes an abrupt completion; it must not remain pending.
    if (try engine.completionOf(realm, Extraction.steps, &extraction)) |thrown| {
        thrown.release();
        return null;
    }
    return if (extraction.result == .key) extraction.result.key else null;
}

/// ED 6.2/6.3 retrieval: native cursors already implement sorted direction
/// and duplicate selection, while the realm owns all returned values.
pub fn retrieve(source: *runtime.Instance, request: *runtime.Instance, native_source: storage.indexeddb.cursor.CursorSource, operation: *Operation) !void {
    const allocator = operation.allocator;
    const realm = operation.target_realm orelse request.ctx;
    const cursor = try allocator.create(storage.indexeddb.IDBCursor);
    cursor.* = (switch (native_source) {
        .object_store => |store| storage.indexeddb.IDBCursor.init(allocator, store, operation.range, operation.direction),
        .index => |index| storage.indexeddb.IDBCursor.initForIndex(allocator, index, operation.range, operation.direction),
    }) catch |err| {
        allocator.destroy(cursor);
        return err;
    };
    var transferred = false;
    defer if (!transferred) {
        cursor.deinit();
        allocator.destroy(cursor);
    };
    if (operation.kind == .open_cursor or operation.kind == .open_key_cursor) {
        if (!cursor.got_value) return completeRequest(request, .jsNull, null);
        cursor.key_only = operation.kind == .open_key_cursor;
        const wrapper = if (cursor.key_only) try interfaces.IDBCursor.init(realm.allocator, realm) else try interfaces.IDBCursorWithValue.init(realm.allocator, realm);
        errdefer if (!engine.hasWrapper(wrapper)) runtime.Instance.deinit(wrapper);
        try attachCursor(wrapper, cursor, source, request);
        transferred = true;
        return completeRequest(request, .{ .instance = wrapper }, null);
    }
    var values: std.ArrayList(runtime.JSValue) = .empty;
    defer {
        for (values.items) |value| (engine.Owned{ .value = value }).release();
        values.deinit(allocator);
    }
    const limit: usize = if (operation.limit) |count| if (count == 0) std.math.maxInt(usize) else count else std.math.maxInt(usize);
    while (cursor.got_value and values.items.len < limit) {
        const value = switch (operation.kind) {
            .all_keys => try @import("indexeddb_keys.zig").toValue(realm, cursor.primary_key.?),
            .all_values => try engine.structuredDeserialize(realm, cursor.value.?),
            .all_records => blk: {
                const record = try interfaces.IDBRecord.init(realm.allocator, realm);
                errdefer if (!engine.hasWrapper(record)) runtime.Instance.deinit(record);
                try attachRecordSnapshot(record, cursor.key.?, cursor.primary_key.?, cursor.value.?);
                break :blk try engine.retainValue(realm, .{ .instance = record });
            },
            else => return error.InvalidStateError,
        };
        values.append(allocator, value.value) catch |err| {
            value.release();
            return err;
        };
        try cursor.@"continue"(null);
    }
    const result = try engine.createSequenceOfValues(realm, values.items);
    defer result.release();
    try completeRequest(request, result.value, null);
}

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
/// Borrow the visible value's realm; check hasEngine() before using it.
pub fn cursorValueRealm(instance: *runtime.Instance) runtime.Context {
    return (cursors orelse return instance.ctx).value_realm(instance);
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
