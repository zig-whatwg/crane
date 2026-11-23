//! IndexedDB Transaction Implementation
//!
//! Implements IDBTransaction per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbtransaction
//!
//! ## Properties
//!
//! - `objectStoreNames` - Names of object stores in scope
//! - `mode` - Transaction mode (readonly, readwrite, versionchange)
//! - `durability` - Durability hint
//! - `db` - Associated database
//! - `error` - Error that caused abort
//!
//! ## Methods
//!
//! - `objectStore(name)` - Access an object store
//! - `commit()` - Commit the transaction
//! - `abort()` - Abort the transaction
//!
//! ## Spec Reference
//!
//! Algorithm: "transaction/lifetime"
//! Location: specs/algorithms/IndexedDB-3.json lines 187-211

const std = @import("std");
const IDBDatabase = @import("database.zig").IDBDatabase;
const IDBObjectStore = @import("object_store.zig").IDBObjectStore;
const IDBRequest = @import("request.zig").IDBRequest;
const IDBError = @import("errors.zig").IDBError;
const server_mod = @import("server.zig");
const backing_store = @import("backing_store.zig");
const stored_schema = @import("stored_schema.zig");
const IDBKey = @import("key.zig").IDBKey;

/// Transaction mode
/// https://w3c.github.io/IndexedDB/#transaction-mode
pub const IDBTransactionMode = enum {
    /// Read-only transaction
    readonly,
    /// Read-write transaction
    readwrite,
    /// Version change transaction
    versionchange,
};

/// Transaction state
/// https://w3c.github.io/IndexedDB/#transaction-state
pub const IDBTransactionState = enum {
    /// Transaction is active and can accept requests
    active,
    /// Transaction is inactive (between request handlers)
    inactive,
    /// Transaction is committing
    committing,
    /// Transaction is finished (committed or aborted)
    finished,
};

/// Durability hint
/// https://w3c.github.io/IndexedDB/#transaction-durability
pub const IDBTransactionDurability = enum {
    /// Default durability (implementation-defined)
    default,
    /// Strict durability (must be persisted)
    strict,
    /// Relaxed durability (may be batched)
    relaxed,
};

/// IDBTransaction interface
/// https://w3c.github.io/IndexedDB/#idbtransaction
///
/// Groups database operations atomically.
pub const IDBTransaction = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Associated database
    db: *IDBDatabase,

    /// Object store names in scope
    scope: []const []const u8,
    owns_scope: bool,
    references: usize = 1,
    destroy_on_release: bool = false,
    rollback_schema: ?IDBDatabase.Schema = null,
    rollback_names: ?IDBDatabase.NameSet = null,
    rollback_version: u64 = 0,
    executing_request: bool = false,
    started: bool = false,
    /// Its record in its connection's server's scheduler (ED 2.7.2), while
    /// unfinished; null for a standalone database's transaction.
    server_id: ?server_mod.Id = null,
    /// The scheduler let it start (it stays started).
    server_started: bool = false,
    /// Tells its owner it may be able to start (`serverNote`). Set by the
    /// owner of the transaction's task while that task lives.
    wake_hook: ?WakeHook = null,
    /// Its view of the backing store - a snapshot taken at its first
    /// request, after the scheduler started it, and its write batch
    /// (backing_store.zig; lane prof1, D6 step 4). Written at commit, dropped
    /// at abort.
    backing_txn: ?*backing_store.Transaction = null,
    /// The stores and indexes this upgrade deleted, whose records, index
    /// entries and reverse rows go from the batch when it is written
    /// (`writeChanges`), not at the deletion: a request accepted before the
    /// deletion still runs after it and reads them, as its operation is
    /// queued before the deletion's in Chromium's transaction
    /// (IndexedDBDatabase::DeleteObjectStoreOperation, scheduled with
    /// IndexedDBTransaction::ScheduleTask after the earlier requests' tasks)
    /// and Firefox's (DeleteObjectStoreOp, dispatched in order). Definition
    /// ids are never reused, so nothing a later store or index writes is
    /// under them. Cleared with the batch.
    dropped: std.ArrayListUnmanaged(Dropped) = .empty,
    /// The results its requests read from the backing store - a value's
    /// bytes, a key - each freed when its request is consumed, or with the
    /// transaction (what a native request held as a borrow of its records).
    owned_results: std.ArrayListUnmanaged(OwnedResult) = .empty,
    /// Its commit, handed to the Browser's storage sequence and not yet
    /// answered (lane prof2): the transaction is committing until the job
    /// says the batch was written - then it completes, or (the write
    /// failed) aborts. The waiter reference is the transaction's.
    pending_commit: ?*backing_store.CommitJob = null,

    /// Transaction mode
    mode: IDBTransactionMode,

    /// Transaction state
    state: IDBTransactionState,

    /// Durability hint
    durability: IDBTransactionDurability,

    /// Error that caused abort (if any)
    err: ?IDBError,

    /// Requests in this transaction
    requests: std.ArrayListUnmanaged(*IDBRequest),

    /// Object store handles
    object_stores: std.StringHashMap(*IDBObjectStore),
    retired_stores: std.ArrayListUnmanaged(*IDBObjectStore) = .empty,

    /// Event handlers
    onabort: ?*const fn (*Self) void,
    oncomplete: ?*const fn (*Self) void,
    onerror: ?*const fn (*Self) void,

    pub const OwnedResult = struct {
        request: *IDBRequest,
        result: union(enum) { value: []u8, key: IDBKey },

        fn deinit(self: *OwnedResult, allocator: std.mem.Allocator) void {
            switch (self.result) {
                .value => |bytes| allocator.free(bytes),
                .key => |*key| key.deinit(),
            }
        }
    };

    /// Keep `result` for `request` (IDBRequest.prepare reserved the slot).
    pub fn keepResult(self: *Self, request: *IDBRequest, result: @FieldType(OwnedResult, "result")) void {
        self.owned_results.appendAssumeCapacity(.{ .request = request, .result = result });
    }

    /// `request` was consumed: its kept result goes.
    pub fn releaseResult(self: *Self, request: *IDBRequest) void {
        var i: usize = 0;
        while (i < self.owned_results.items.len) {
            if (self.owned_results.items[i].request != request) {
                i += 1;
                continue;
            }
            var kept = self.owned_results.swapRemove(i);
            kept.deinit(self.allocator);
        }
    }

    pub const WakeHook = struct {
        context: *anyopaque,
        call: *const fn (context: *anyopaque) void,
    };

    /// The server's note for this transaction (its record's client).
    pub fn serverNote(context: *anyopaque, note: server_mod.Note) void {
        const self: *Self = @ptrCast(@alignCast(context));
        if (note != .wake) return;
        if (self.wake_hook) |hook| hook.call(hook.context);
    }

    /// ED 4.4 transaction() step 8 / 5.7 step 3: join the scheduler of the
    /// connection's server, last in creation order. Nothing for a
    /// standalone database.
    pub fn register(self: *Self) !void {
        std.debug.assert(self.server_id == null);
        const database = self.db.server_database orelse return;
        self.server_id = try database.server.createTransaction(database, self.db.connection_id, self.mode, self.scope, .{ .context = self, .call = serverNote });
    }

    /// The transaction finished (committed or aborted, rollback done): it
    /// leaves the scheduler, which wakes whatever may start now. `publish`
    /// is an upgrade's committed version.
    fn finishServerRecord(self: *Self, publish: ?u64) void {
        const id = self.server_id orelse return;
        self.server_id = null;
        const database = self.db.server_database orelse return;
        database.server.finishTransaction(database, id, publish);
    }

    /// Initialize a new transaction
    pub fn init(
        allocator: std.mem.Allocator,
        db: *IDBDatabase,
        scope: []const []const u8,
        mode: IDBTransactionMode,
    ) Self {
        db.retain();
        return Self{
            .allocator = allocator,
            .db = db,
            .scope = scope,
            .owns_scope = false,
            // ED 5.8.3 applies even when no write creates a lazy snapshot.
            .rollback_version = if (db.backing) |database| database.version else db.version,
            .mode = mode,
            .state = .active,
            .durability = .default,
            .err = null,
            .requests = .empty,
            .object_stores = std.StringHashMap(*IDBObjectStore).init(allocator),
            .onabort = null,
            .oncomplete = null,
            .onerror = null,
        };
    }

    /// Store/index/cursor wrappers hold leases independently of GC order.
    pub fn retain(self: *Self) void {
        std.debug.assert(self.references > 0);
        self.references += 1;
    }
    /// Transfer destruction of a heap transaction to its final wrapper lease.
    pub fn releaseHeapOwnership(self: *Self) void {
        self.destroy_on_release = true;
        self.deinit();
    }
    /// Clean up resources
    pub fn deinit(self: *Self) void {
        std.debug.assert(self.references > 0);
        self.references -= 1;
        if (self.references != 0) return;
        // A commit still being written decides how this ends: its outcome
        // is waited for (the agent's end), never rolled back under it.
        if (self.pending_commit != null) self.finishCommit() catch {};
        // A transaction that never finished (its task never ran) must not
        // hold up the scheduler; its batch is never written.
        self.dropBacking();
        self.dropped.deinit(self.allocator);
        for (self.owned_results.items) |*kept| kept.deinit(self.allocator);
        self.owned_results.deinit(self.allocator);
        self.finishServerRecord(null);
        if (self.rollback_schema) |*schema_map| IDBDatabase.deinitSchema(schema_map, self.allocator);
        if (self.rollback_names) |*names| IDBDatabase.deinitNames(self.allocator, names);
        if (self.owns_scope) {
            for (self.scope) |name| self.allocator.free(name);
            self.allocator.free(self.scope);
        }
        // The database borrows live transactions; remove before destruction.
        for (self.db.transactions.items, 0..) |transaction, index| {
            if (transaction == self) {
                _ = self.db.transactions.orderedRemove(index);
                break;
            }
        }
        for (self.db.transactionQueue().items, 0..) |transaction, index| {
            if (transaction == self) {
                _ = self.db.transactionQueue().orderedRemove(index);
                break;
            }
        }
        self.requests.deinit(self.allocator);

        var it = self.object_stores.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.object_stores.deinit();
        for (self.retired_stores.items) |store| {
            store.deinit();
            self.allocator.destroy(store);
        }
        self.retired_stores.deinit(self.allocator);
        self.db.deinit();
        if (self.destroy_on_release) self.allocator.destroy(self);
    }

    /// The transaction's view of the backing store, begun on first use.
    pub fn backingTransaction(self: *Self) IDBError!*backing_store.Transaction {
        if (self.backing_txn) |txn| return txn;
        const store = try self.db.backingStore();
        const txn = store.begin() catch |err| return backing_store.idbError(err);
        self.backing_txn = txn;
        return txn;
    }

    fn dropBacking(self: *Self) void {
        self.dropped.clearRetainingCapacity();
        const txn = self.backing_txn orelse return;
        self.backing_txn = null;
        txn.destroy();
    }

    /// A deleted store's or index's data, to go when the batch is written.
    const Dropped = union(enum) {
        store: u64,
        index: struct { store: u64, index: u64 },
    };

    /// deleteObjectStore: the store `definition_id`'s schema record goes
    /// from this upgrade's batch now; its records, index entries and reverse
    /// rows when the batch is written (`dropped`).
    pub fn dropStoreData(self: *Self, definition_id: u64) IDBError!void {
        const txn = try self.backingTransaction();
        try self.dropped.ensureUnusedCapacity(self.allocator, 1);
        const schema_key = txn.buffer(.key);
        try backing_store.storeSchemaKey(schema_key, txn.gpa(), self.db.databaseId(), definition_id);
        try txn.delete(schema_key.items);
        self.dropped.appendAssumeCapacity(.{ .store = definition_id });
    }

    /// deleteIndex: the index's entries go when the batch is written
    /// (`dropped`; its reverse rows are left to the next write of each
    /// record, which drops every row it had).
    pub fn dropIndexData(self: *Self, store_id: u64, index_id: u64) IDBError!void {
        try self.dropped.ensureUnusedCapacity(self.allocator, 1);
        self.dropped.appendAssumeCapacity(.{ .index = .{ .store = store_id, .index = index_id } });
    }

    /// The range deletions of every store and index this upgrade deleted.
    fn writeDropped(self: *Self, txn: *backing_store.Transaction) IDBError!void {
        const alloc = txn.gpa();
        const db = self.db.databaseId();
        for (self.dropped.items) |dropped| switch (dropped) {
            .store => |definition_id| for ([_]u8{ backing_store.tag_record, backing_store.tag_index, backing_store.tag_reverse }) |tag| {
                const prefix = txn.buffer(.prefix);
                try prefix.append(alloc, tag);
                try backing_store.appendU64(prefix, alloc, db);
                try backing_store.appendU64(prefix, alloc, definition_id);
                const end = txn.buffer(.upper);
                try backing_store.prefixEnd(end, alloc, prefix.items);
                try txn.deleteRange(prefix.items, end.items);
            },
            .index => |index| {
                const prefix = txn.buffer(.prefix);
                try backing_store.indexPrefix(prefix, alloc, db, index.store, index.index);
                const end = txn.buffer(.upper);
                try backing_store.prefixEnd(end, alloc, prefix.items);
                try txn.deleteRange(prefix.items, end.items);
            },
        };
    }

    /// IDB 5.4 step 3: the transaction's changes, written to the database -
    /// its batch, and the schema records of what it may have changed: an
    /// upgrade's database record and every store's, a readwrite
    /// transaction's scope's (their key generators). A database an upgrade
    /// made gets its directory entry.
    fn writeChanges(self: *Self) IDBError!void {
        if (self.mode == .readonly) return;
        // A readwrite transaction that wrote nothing (its first write takes
        // the rollback snapshot) has nothing to write: no store transaction.
        if (self.mode == .readwrite and self.rollback_schema == null) return;
        const txn = try self.backingTransaction();
        const alloc = txn.gpa();
        const db = self.db.databaseId();
        try self.writeDropped(txn);
        self.db.lockSchema();
        defer self.db.unlockSchema();
        const schema_map = self.db.schema();
        if (self.mode == .versionchange) {
            const durable = self.db.backing orelse self.db;
            const record = try stored_schema.encodeDatabase(alloc, self.db.version, durable.next_store_id);
            defer alloc.free(record);
            const key = txn.buffer(.key);
            try backing_store.databaseKey(key, alloc, db);
            try txn.put(key.items, record);
            if (self.db.server_database) |database| if (!database.persisted) {
                const serialized = try database.storage_key.serialize(alloc);
                defer alloc.free(serialized);
                const directory = txn.buffer(.key);
                try backing_store.directoryKey(directory, alloc, serialized, database.name);
                var id: [8]u8 = undefined;
                std.mem.writeInt(u64, &id, db, .big);
                try txn.put(directory.items, &id);
            };
            var stores = schema_map.valueIterator();
            while (stores.next()) |metadata| try putStoreSchema(txn, db, metadata);
            return;
        }
        for (self.scope) |name| {
            const metadata = schema_map.getPtr(name) orelse continue;
            try putStoreSchema(txn, db, metadata);
        }
    }

    fn putStoreSchema(txn: *backing_store.Transaction, db: u64, metadata: *const @import("database.zig").ObjectStoreMetadata) IDBError!void {
        const alloc = txn.gpa();
        const record = try stored_schema.encodeStore(alloc, metadata);
        defer alloc.free(record);
        const key = txn.buffer(.key);
        try backing_store.storeSchemaKey(key, alloc, db, metadata.record_data.definition_id);
        try txn.put(key.items, record);
    }

    /// IDB 5.5 step 2: keep the pre-write schema, records and generators until
    /// commit succeeds. Native storage is synchronous; dispatch remains queued.
    pub fn ensureRollbackSnapshot(self: *Self) !void {
        if (self.rollback_schema != null) return;
        if (self.mode == .readonly) return;
        // An upgrade may change any store, so it keeps them all; a readwrite
        // transaction only its scope - another store's records may be
        // another transaction's, on another thread, while this one runs.
        self.db.lockSchema();
        defer self.db.unlockSchema();
        var snapshot = try self.db.cloneSchemaOf(if (self.mode == .versionchange) null else self.scope);
        errdefer IDBDatabase.deinitSchema(&snapshot, self.allocator);
        const names = if (self.mode == .versionchange) try self.db.cloneConnectionNames() else null;
        self.rollback_schema = snapshot;
        self.rollback_names = names;
    }

    /// ED 2.7.2: only earlier, unfinished transactions with overlapping
    /// scopes constrain a start. Two readers can run together.
    pub fn canStart(self: *Self) bool {
        if (self.server_started) return true;
        if (self.server_id) |id| {
            const database = self.db.server_database.?;
            self.server_started = database.server.tryStart(database, id);
            return self.server_started;
        }
        if (self.db.server_database != null) return true;
        for (self.db.transactionQueue().items) |earlier| {
            if (earlier == self) break;
            if (earlier.state == .finished) continue;
            if (self.mode == .readonly and earlier.mode == .readonly) continue;
            if (self.mode == .versionchange or earlier.mode == .versionchange) return false;
            for (self.scope) |name| for (earlier.scope) |other| {
                if (std.mem.eql(u8, name, other)) return false;
            };
        }
        return true;
    }

    /// ED 5.6: accepted work executes after script's active period, including
    /// after commit(). This does not make the transaction active for script.
    pub fn beginRequestExecution(self: *Self) IDBError!void {
        if (self.state == .finished or !self.canStart()) return IDBError.TransactionInactiveError;
        std.debug.assert(!self.executing_request);
        if (!self.started and self.mode != .versionchange) {
            // A previous writer may have aborted after these handles were
            // made. Their first operation uses the restored canonical data.
            self.db.lockSchema();
            defer self.db.unlockSchema();
            var stores = self.object_stores.valueIterator();
            while (stores.next()) |entry| {
                const store = entry.*;
                const metadata = self.db.schema().get(store.name) orelse return IDBError.NotFoundError;
                const fresh = metadata.record_data;
                if (store.record_data == fresh) continue;
                var indexes = store.indexes.valueIterator();
                while (indexes.next()) |index_entry| {
                    const index = index_entry.*;
                    const index_data = fresh.indexes.get(index.name) orelse return IDBError.NotFoundError;
                    const old = index.data;
                    index.data = null;
                    try index.attachData(index_data);
                    if (old) |data| data.release();
                }
                const old = store.record_data;
                store.record_data = null;
                store.attachRecords(fresh);
                if (old) |data| data.release();
            }
        }
        self.started = true;
        self.executing_request = true;
    }

    pub fn endRequestExecution(self: *Self) void {
        std.debug.assert(self.executing_request);
        self.executing_request = false;
    }

    pub fn canExecuteRequest(self: *const Self) bool {
        return self.state == .active or (self.executing_request and self.state != .finished);
    }

    /// Snapshot converted scope names before their caller releases them.
    pub fn copyScope(self: *Self, names: []const []const u8) !void {
        const copies = try self.allocator.alloc([]const u8, names.len);
        errdefer self.allocator.free(copies);
        var copied: usize = 0;
        errdefer for (copies[0..copied]) |name| self.allocator.free(name);
        for (names, 0..) |name, index| {
            copies[index] = try self.allocator.dupe(u8, name);
            copied += 1;
        }
        if (self.owns_scope) {
            for (self.scope) |name| self.allocator.free(name);
            self.allocator.free(self.scope);
        }
        self.scope = copies;
        self.owns_scope = true;
    }

    /// Get an object store
    /// https://w3c.github.io/IndexedDB/#dom-idbtransaction-objectstore
    ///
    /// Steps:
    /// 1. If this transaction is not active, throw TransactionInactiveError.
    /// 2. If name is not in scope, throw NotFoundError.
    /// 3. Return an IDBObjectStore for the object store.
    pub fn objectStore(self: *Self, name: []const u8) IDBError!*IDBObjectStore {
        // Step 1: Check transaction state
        if (self.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // The schema map is read under its lock (a readwrite abort on another
        // thread may swap an entry).
        self.db.lockSchema();
        defer self.db.unlockSchema();

        // Step 2: Check name is in scope
        var found = self.mode == .versionchange and self.db.schema().contains(name);
        for (self.scope) |scope_name| {
            if (std.mem.eql(u8, scope_name, name)) {
                found = true;
                break;
            }
        }
        if (!found) {
            return IDBError.NotFoundError;
        }

        // Check if we already have a handle
        if (self.object_stores.get(name)) |store| {
            return store;
        }

        // Create new handle
        const store = try self.allocator.create(IDBObjectStore);
        errdefer self.allocator.destroy(store);

        store.* = IDBObjectStore.init(self.allocator, name, self);

        errdefer store.deinit();

        // Get metadata from database
        if (self.db.schema().get(name)) |metadata| {
            try store.copyDefinition(metadata.name, metadata.key_path);
            if (metadata.compound_key_path) |paths| try store.copyCompoundKeyPath(paths);
            store.auto_increment = metadata.auto_increment;
            store.attachRecords(metadata.record_data);
            try store.snapshotIndexNames();
        }

        try self.object_stores.put(store.name, store);

        return store;
    }

    /// Commit the transaction
    /// https://w3c.github.io/IndexedDB/#dom-idbtransaction-commit
    ///
    /// Steps:
    /// 1. If state is not active, throw InvalidStateError.
    /// 2. Set state to committing.
    /// 3. Process pending requests and commit.
    ///
    /// The whole commit, written before this returns: on this thread, or -
    /// a storage sequence (a profile directory) - waited for here. A caller
    /// with an event loop uses `startCommit`, and is told.
    pub fn commit(self: *Self) IDBError!void {
        _ = try self.startCommit(null);
        // A write that failed aborted the transaction instead (IDB 5.4 step
        // 3.1): the engine-free caller, which hears no abort event, is told
        // the error the abort carries - as the binding's caller is told by
        // its "abort" (impls/IDBTransaction). Silent, the allocation-failure
        // walks went on with a schema the abort had rolled back (lane tpg).
        if (self.state == .finished) if (self.err) |err| return err;
    }

    pub const CommitProgress = enum {
        /// Committed, or aborted (`err` says which): finished.
        done,
        /// The batch is on the storage sequence: committing until the
        /// waiter's endpoint is told (`wake_hook`), then `startCommit` again
        /// answers.
        writing,
    };

    /// Whether a commit is being written on the storage sequence now.
    pub fn commitWriting(self: *const Self) bool {
        const job = self.pending_commit orelse return false;
        return !job.isDone();
    }

    /// Whether this transaction's commit would be written on the Browser's
    /// storage sequence: its caller then makes an endpoint to be told on
    /// (dom.indexeddb.endpointOf) - and only then, so a Browser with no
    /// profile directory makes none.
    pub fn commitsOnSequence(self: *Self) bool {
        if (self.mode == .readonly or self.pending_commit != null) return false;
        const store = self.db.backingStore() catch return false;
        return store.sequence != null;
    }

    /// IDB 5.4 "commit a transaction", as far as it can go now. Its step 3,
    /// writing the changes, is the storage sequence's with a profile
    /// directory (lane prof2): the batch moves into a job and this answers
    /// `writing`; `notify` (OWNED: an endpoint of the transaction's agent,
    /// with a sink) is told when it was written, through the transaction's
    /// `wake_hook`, and the next call takes the answer - the complete
    /// steps, or "abort a transaction" with the write's error (step 3.1).
    /// Chromium commits on its backing store's sequence and posts complete
    /// to the renderer only after (IndexedDBTransaction::CommitPhaseTwo).
    /// With no `notify` the write is waited for here; with no sequence
    /// (kit/memory_store) it is made here, as before.
    pub fn startCommit(self: *Self, notify: ?server_mod.Endpoint) IDBError!CommitProgress {
        var endpoint = notify;
        defer if (endpoint) |*owned| owned.release();
        if (endpoint) |*owned| if (owned.sink == null) {
            // Nothing could be posted to it: the write is waited for here.
            owned.release();
            endpoint = null;
        };
        // Step 1: Check state
        if (self.state == .finished) {
            return IDBError.InvalidStateError;
        }
        if (self.pending_commit) |job| {
            if (!job.isDone()) return .writing;
            try self.finishCommit();
            return .done;
        }

        // IDB 5.4 step 3: write the changes; "if an error occurs while
        // writing the changes to the database, then abort a transaction
        // with transaction and an appropriate DOMException" - and nothing
        // of them is written.
        const written: ?IDBError = blk: {
            self.writeChanges() catch |err| break :blk err;
            const txn = self.backing_txn orelse break :blk null;
            if (txn.backing.sequence != null and txn.hasChanges()) {
                const told = endpoint != null;
                const job = txn.prepareCommit(endpoint, null) catch |err| {
                    endpoint = null;
                    break :blk backing_store.idbError(err);
                };
                endpoint = null;
                self.pending_commit = job;
                // The waiter is set before the post, so the task the job
                // posts to this thread finds it.
                if (told) job.waiter = .{ .context = self, .call = commitWritten };
                job.post();
                if (told) return .writing;
                job.wait();
                try self.finishCommit();
                return .done;
            }
            txn.commit() catch |err| break :blk backing_store.idbError(err);
            break :blk null;
        };
        if (written) |err| {
            try self.abortForError(err);
            return .done;
        }
        self.completeCommit();
        return .done;
    }

    /// The job's task, on this transaction's agent's thread: it was written;
    /// the transaction's owner is woken to take the answer.
    fn commitWritten(context: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context));
        if (self.wake_hook) |hook| hook.call(hook.context);
    }

    /// The written commit's answer, taken: completed, or aborted with the
    /// write's error. Waits for it if it is still being written (an agent's
    /// end: the one wait on the sequence an agent makes).
    fn finishCommit(self: *Self) IDBError!void {
        const job = self.pending_commit.?;
        self.pending_commit = null;
        job.wait();
        job.take() catch |err| return self.abortForError(backing_store.idbError(err));
        self.completeCommit();
    }

    /// IDB 5.4 steps 4-5, the changes written: the transaction is finished,
    /// and leaves the scheduler.
    fn completeCommit(self: *Self) void {
        self.dropBacking();
        if (self.mode == .versionchange) if (self.db.server_database) |database| {
            database.server.lock();
            database.persisted = true;
            database.server.unlock();
        };

        // ED 5.7: an upgrade's version becomes the database's when it
        // commits - in its server, with the scheduler record, under its lock.
        if (self.mode == .versionchange and self.server_id == null) self.db.publishVersion();
        if (self.rollback_schema) |*schema_map| IDBDatabase.deinitSchema(schema_map, self.allocator);
        self.rollback_schema = null;
        if (self.rollback_names) |*names| IDBDatabase.deinitNames(self.allocator, names);
        self.rollback_names = null;

        // Step 2: Set state to committing
        self.state = .committing;

        // Step 3: Process pending requests (simplified - synchronous)
        // In a real implementation, this would be async
        self.state = .finished;
        self.finishServerRecord(if (self.mode == .versionchange) self.db.version else null);

        // Fire complete event
        if (self.oncomplete) |handler| {
            handler(self);
        }
    }

    /// Abort the transaction
    /// https://w3c.github.io/IndexedDB/#dom-idbtransaction-abort
    ///
    /// Steps:
    /// 1. If state is committing or finished, throw InvalidStateError.
    /// 2. Set state to finished.
    /// 3. Undo all changes.
    /// 4. Fire abort event.
    pub fn abort(self: *Self) IDBError!void {
        // Step 1: Check state
        if (self.state == .committing or self.state == .finished) {
            return IDBError.InvalidStateError;
        }
        return self.abortForError(IDBError.AbortError);
    }

    /// ED 5.5 is also used when an accepted operation fails during commit.
    /// The IDL abort() state restriction does not apply to this algorithm.
    pub fn abortForError(self: *Self, reason: IDBError) IDBError!void {
        // Step 1: an already finished transaction is unchanged.
        if (self.state == .finished) return;
        // A commit already handed to the storage sequence is past
        // aborting: its write decides (an agent ending meanwhile waits for
        // it), so a durable commit is never rolled back in memory.
        if (self.pending_commit != null) return self.finishCommit();

        // IDB 5.5 step 2: the batch is dropped - none of its records or
        // index entries was written - and the schema and key generators are
        // restored atomically, under the schema lock: other threads read the
        // map meanwhile.
        self.dropBacking();
        if (self.rollback_schema) |snapshot| {
            self.db.lockSchema();
            defer self.db.unlockSchema();
            self.restoreSnapshot(snapshot);
        }

        // ED 5.8.3: version changes belong to every upgrade, including an
        // otherwise empty transaction with no record/schema rollback snapshot.
        if (self.mode == .versionchange) self.db.version = self.rollback_version;

        // Step 4: Set state to finished
        self.state = .finished;
        self.err = reason;

        // Native notification; the binding queues the DOM abort event (step 7).
        if (self.onabort) |handler| {
            handler(self);
        }
        // Rolled back: only now may another agent see the database.
        self.finishServerRecord(null);
    }

    fn restoreSnapshot(self: *Self, snapshot: IDBDatabase.Schema) void {
        if (self.mode == .versionchange) {
            var changed = self.db.schema().*;
            self.db.schema().* = snapshot;
            self.rollback_schema = null;
            // 5.8 step 4 restores the connection's own set too.
            var changed_names = self.db.connection_names;
            self.db.connection_names = self.rollback_names.?;
            self.rollback_names = null;
            IDBDatabase.deinitNames(self.allocator, &changed_names);
            // 5.8 steps 5-6 restore every associated handle by definition
            // identity, including handles retired by deletion/recreation.
            var handles = self.object_stores.valueIterator();
            while (handles.next()) |handle| self.rollbackStoreHandle(handle.*);
            for (self.retired_stores.items) |handle| self.rollbackStoreHandle(handle);
            IDBDatabase.deinitSchema(&changed, self.allocator);
        } else {
            // Disjoint scopes may commit independently. Restore only this
            // transaction's stores, preserving other committed changes.
            var backup = snapshot;
            for (self.scope) |name| {
                const live = self.db.schema().getEntry(name) orelse continue;
                const previous = backup.getEntry(name) orelse continue;
                std.mem.swap(@import("database.zig").ObjectStoreMetadata, live.value_ptr, previous.value_ptr);
                live.key_ptr.* = live.value_ptr.name;
                previous.key_ptr.* = previous.value_ptr.name;
            }
            self.rollback_schema = null;
            IDBDatabase.deinitSchema(&backup, self.allocator);
        }
    }

    fn rollbackStoreHandle(self: *Self, store: *IDBObjectStore) void {
        const data = store.record_data orelse return;
        var definitions = self.db.schema().valueIterator();
        while (definitions.next()) |metadata| {
            if (metadata.record_data.definition_id == data.definition_id) {
                store.rollbackSchema(metadata);
                return;
            }
        }
        store.rollbackSchema(null);
    }

    /// Add a request to this transaction
    pub fn addRequest(self: *Self, request: *IDBRequest) !void {
        try self.requests.append(self.allocator, request);
    }

    /// Set state to inactive (called after event dispatch)
    pub fn setInactive(self: *Self) void {
        if (self.state == .active) {
            self.state = .inactive;
        }
    }

    /// Set state to active (called during event dispatch)
    pub fn setActive(self: *Self) void {
        if (self.state == .inactive) {
            self.state = .active;
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBTransaction - init" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readonly);
    defer txn.deinit();

    try std.testing.expectEqual(IDBTransactionMode.readonly, txn.mode);
    try std.testing.expectEqual(IDBTransactionState.active, txn.state);
}

test "IDBTransaction - commit" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    try txn.commit();
    try std.testing.expectEqual(IDBTransactionState.finished, txn.state);
}

test "IDBTransaction - abort" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    try txn.abort();
    try std.testing.expectEqual(IDBTransactionState.finished, txn.state);
    try std.testing.expectEqual(IDBError.AbortError, txn.err.?);
}

test "IDBTransaction - cannot commit after abort" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    try txn.abort();

    const result = txn.commit();
    try std.testing.expectError(IDBError.InvalidStateError, result);
}

test "IDBTransaction - objectStore not in scope" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readonly);
    defer txn.deinit();

    const result = txn.objectStore("store2");
    try std.testing.expectError(IDBError.NotFoundError, result);
}

/// An engine-free agent loop for the storage sequence tests: a task sink
/// the job posts to from the sequence's thread, drained on this one.
const TestSink = struct {
    mutex: std.Io.Mutex = .init,
    inbox: std.ArrayListUnmanaged(server_mod.Task) = .empty,

    fn endpoint(self: *TestSink) server_mod.Endpoint {
        return .{ .thread = std.Thread.getCurrentId(), .sink = self, .ops = &ops };
    }

    const ops: server_mod.SinkOps = .{ .post = post, .release = release };

    fn post(sink: *anyopaque, task: server_mod.Task) bool {
        const self: *TestSink = @ptrCast(@alignCast(sink));
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const accepted = if (self.inbox.append(std.testing.allocator, task)) true else |_| false;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        if (!accepted) task.drop(task.data);
        return accepted;
    }

    /// The test owns the sink: no reference is counted.
    fn release(_: *anyopaque) void {}

    /// Run what was posted until `flag` is set.
    fn runUntil(self: *TestSink, flag: *const bool) void {
        while (!@atomicLoad(bool, flag, .acquire)) {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            var taken = self.inbox;
            self.inbox = .empty;
            std.Io.Threaded.mutexUnlock(&self.mutex);
            defer taken.deinit(std.testing.allocator);
            for (taken.items) |task| task.run(task.data);
            if (taken.items.len == 0) std.Thread.yield() catch {};
        }
    }

    fn deinit(self: *TestSink) void {
        for (self.inbox.items) |task| task.drop(task.data);
        self.inbox.deinit(std.testing.allocator);
    }
};

/// A job that holds the storage sequence until its gate is set.
const HeldSequence = struct {
    job: @import("../sequence.zig").Job = .{ .run = run, .drop = drop },
    gate: @import("../sequence.zig").Done = .{},

    fn run(job: *@import("../sequence.zig").Job) void {
        const self: *HeldSequence = @fieldParentPtr("job", job);
        self.gate.wait();
    }

    fn drop(_: *@import("../sequence.zig").Job) void {}
};

fn setWoken(context: *anyopaque) void {
    const flag: *bool = @ptrCast(@alignCast(context));
    @atomicStore(bool, flag, true, .release);
}

fn ignorePlatformEvent(context: ?*anyopaque, event: *const @import("platform").PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

test "on the storage sequence a commit completes only once it was written, and a failed write aborts the transaction" {
    const allocator = std.testing.allocator;
    const platform = @import("platform");
    const StorageSequence = @import("../sequence.zig").StorageSequence;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(base);
    const directory = try std.fs.path.join(allocator, &.{ base, "profile" });
    defer allocator.free(directory);
    const browser = try platform.createBrowserPlatform(allocator, &.{ .profile_dir = platform.Str.from(directory) }, .{ .context = null, .post = ignorePlatformEvent });
    defer platform.destroyBrowserPlatform(browser);
    var server = server_mod.IDBServer.init(allocator);
    defer server.deinit();
    try server.attachPlatform(browser);
    // Stopped before the server and the platform state end (the defers run
    // in reverse), as at a Browser's end.
    var sequence = StorageSequence.init(allocator);
    defer sequence.deinit();
    try sequence.start();
    server.attachSequence(&sequence);
    var sink: TestSink = .{};
    defer sink.deinit();

    const unique = try server.uniqueDatabase(server_mod.firstPartyKey("https://sequence.test"), "db");
    defer server.release(unique);
    const opened = try server.openConnection(unique, 1, false, allocator, sink.endpoint());
    const database = opened.connection;
    defer database.releaseHeapOwnership();
    {
        // An upgrade committed with no endpoint: written, and waited for.
        var upgrade = IDBTransaction.init(allocator, database, &.{}, .versionchange);
        defer upgrade.deinit();
        database.version_change_transaction = &upgrade;
        const created = try database.createObjectStore("s", .{});
        created.deinit();
        allocator.destroy(created);
        try upgrade.commit();
        database.version_change_transaction = null;
        try std.testing.expectEqual(IDBTransactionState.finished, upgrade.state);
    }

    // A readwrite transaction, its commit handed to a held sequence: it is
    // committing - not finished, no complete - until the write is done.
    var held: HeldSequence = .{};
    sequence.post(&held.job);
    const write = try database.transaction(&.{"s"}, .readwrite, .{});
    defer {
        write.deinit();
        allocator.destroy(write);
    }
    var woken = false;
    write.wake_hook = .{ .context = &woken, .call = setWoken };
    const put = try (try write.objectStore("s")).put("value", IDBKey.number(1));
    defer allocator.destroy(put);
    write.state = .committing;
    try std.testing.expectEqual(IDBTransaction.CommitProgress.writing, try write.startCommit(sink.endpoint()));
    try std.testing.expect(write.commitWriting());
    try std.testing.expectEqual(IDBTransactionState.committing, write.state);
    // Asked again before the write is done: still writing.
    try std.testing.expectEqual(IDBTransaction.CommitProgress.writing, try write.startCommit(null));
    held.gate.set();
    // The job's task, run on this thread, wakes the transaction's owner.
    sink.runUntil(&woken);
    try std.testing.expectEqual(IDBTransaction.CommitProgress.done, try write.startCommit(null));
    try std.testing.expectEqual(IDBTransactionState.finished, write.state);
    try std.testing.expect(write.err == null);

    // The store's one writer, held on this thread: the sequence's write of
    // the next commit fails (Conflict), and the transaction aborts with an
    // UnknownError (IDB 5.4 step 3.1), its record never written.
    const store = try platform.openStore(browser, platform.Str.from(backing_store.store_name), .{});
    defer platform.closeStore(store);
    const blocker = try platform.beginTransaction(store, .write);
    const failing = try database.transaction(&.{"s"}, .readwrite, .{});
    defer {
        failing.deinit();
        allocator.destroy(failing);
    }
    var failed_woken = false;
    failing.wake_hook = .{ .context = &failed_woken, .call = setWoken };
    const lost = try (try failing.objectStore("s")).put("lost", IDBKey.number(2));
    defer allocator.destroy(lost);
    failing.state = .committing;
    try std.testing.expectEqual(IDBTransaction.CommitProgress.writing, try failing.startCommit(sink.endpoint()));
    sink.runUntil(&failed_woken);
    try std.testing.expectEqual(IDBTransaction.CommitProgress.done, try failing.startCommit(null));
    platform.abortTransaction(blocker);
    try std.testing.expectEqual(IDBTransactionState.finished, failing.state);
    try std.testing.expectEqual(IDBError.UnknownError, failing.err.?);

    // What is in the store: the first commit's record, not the second's.
    const read = try database.transaction(&.{"s"}, .readonly, .{});
    defer {
        read.deinit();
        allocator.destroy(read);
    }
    const records = try read.objectStore("s");
    try std.testing.expectEqual(@as(u64, 1), try records.recordCount(null));
    try read.commit();
}

test "with no storage sequence a commit is written on the committing thread, as before" {
    const allocator = std.testing.allocator;
    var server = server_mod.IDBServer.init(allocator);
    defer server.deinit();
    const unique = try server.uniqueDatabase(server_mod.firstPartyKey("https://inline.test"), "db");
    defer server.release(unique);
    const opened = try server.openConnection(unique, 1, false, allocator, server_mod.Endpoint.here());
    const database = opened.connection;
    defer database.releaseHeapOwnership();
    {
        var upgrade = IDBTransaction.init(allocator, database, &.{}, .versionchange);
        defer upgrade.deinit();
        database.version_change_transaction = &upgrade;
        const created = try database.createObjectStore("s", .{});
        created.deinit();
        allocator.destroy(created);
        try upgrade.commit();
        database.version_change_transaction = null;
    }
    const write = try database.transaction(&.{"s"}, .readwrite, .{});
    defer {
        write.deinit();
        allocator.destroy(write);
    }
    const put = try (try write.objectStore("s")).put("value", IDBKey.number(1));
    defer allocator.destroy(put);
    // No sequence: no endpoint is wanted, and the commit is done at once.
    try std.testing.expect(!write.commitsOnSequence());
    try std.testing.expectEqual(IDBTransaction.CommitProgress.done, try write.startCommit(null));
    try std.testing.expectEqual(IDBTransactionState.finished, write.state);
    try std.testing.expect(write.pending_commit == null);
    try std.testing.expect(server.backingStore().?.sequence == null);
}
