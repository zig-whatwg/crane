//! IndexedDB storage shared per Browser: one `IDBServer` per Browser (a
//! BrowserScope supplement), shared by every agent and thread of that
//! Browser - its pages and frames on the window thread, each worker and
//! service worker on a thread of its own. Two Browsers have two scopes, so
//! two servers: isolated between Browsers.
//!
//! Names from WebKit (Source/WebCore/Modules/indexeddb/server/): `IDBServer`
//! per session, `UniqueIDBDatabase` per (storage key, name) with its pending
//! open/delete requests, open connections and transactions. Blink does the
//! same jobs (IndexedDBContextImpl, BucketContext, ConnectionCoordinator,
//! PartitionedLockManager).
//!
//! What lives here, per (storage key, name): the canonical database
//! (version, schema, records - the durable `IDBDatabase`), the CONNECTION
//! QUEUE of open/delete requests (ED 2.8.2), the set of open connections,
//! and the TRANSACTION SCHEDULER's records (ED 2.7.2, creation order across
//! every connection). The server never points into an agent's memory beyond
//! the one callback context each record names, which its agent removes - on
//! its own thread - before freeing: agent natives (the connection's
//! IDBDatabase, IDBTransaction, IDBRequest and their wrappers) stay in the
//! agent and refer to server records by id.
//!
//! THE LOCK. One mutex per server guards the map, each database's version,
//! store-id counter and schema map, its queue, connection set and
//! transaction records. It is never held across script, an engine call, or
//! a post to a task sink: what must be told is collected under the lock and
//! told after it drops (`Deliveries`). Records and index data inside a
//! store are guarded by the scheduler instead: a request runs only inside a
//! started transaction whose scope holds its store, so one store's records
//! are touched concurrently only by readonly transactions (Blink's
//! PartitionedLockManager: shared/exclusive locks per object store, held
//! from a transaction's start to its finish).
//!
//! CROSS-AGENT DELIVERY (the cookie-listener model; lesson
//! architecture-a-threadlocal-listener-list-splits-a-browser-when-its-work-moves-threads).
//! Each record keeps its agent's thread and retained task sink. A note for a
//! record on the telling thread is told directly, after the lock drops; one
//! for another thread is a task posted to its sink, which finds its record by
//! id under the lock when it runs (gone: nothing), and whose drop end -
//! that loop ended - does what the record's absence requires (a
//! versionchange's acknowledgement).
//!
//! AGENT END. Records are removed by their own objects' ends, ordered so no
//! other agent observes what a rollback has not yet restored: a transaction
//! record finishes at the END of its backend commit or abort; a connection
//! whose close is pending stays in the set until its last transaction
//! finishes; an open request withdrawn mid-upgrade keeps the queue's head
//! until its upgrade transaction finishes, and only then does the queue
//! advance.
//!
//! Spec: https://w3c.github.io/IndexedDB/ (2.7.2 transaction scheduling,
//! 2.8.2 connection queues, 5.1 opening, 5.2 closing, 5.3 deleting).

const std = @import("std");
const Allocator = std.mem.Allocator;
pub const StorageKey = @import("../standard.zig").StorageKey;

/// A key owning a copy of `key`'s parts (server allocator): the one place
/// the server copies a StorageKey - it keeps every part `equals` compares.
fn copyKey(allocator: Allocator, key: StorageKey) Allocator.Error!StorageKey {
    return key.clone(allocator);
}

/// The key of a top-level document of `origin` (BORROWED): what a native
/// caller with no environment - a test, the backend IDBFactory view - names
/// a database by.
pub fn firstPartyKey(origin: []const u8) StorageKey {
    return StorageKey.initBorrowed(origin, origin, false);
}
const database_mod = @import("database.zig");
const IDBDatabase = database_mod.IDBDatabase;
const IDBTransactionMode = @import("transaction.zig").IDBTransactionMode;
const IDBError = @import("errors.zig").IDBError;

pub const Id = u64;

/// A task for another thread's loop: `run` on that thread, or `drop` (any
/// thread) when it will never run. The shape of runtime.CrossThreadTask,
/// which this module cannot name.
pub const Task = struct {
    run: *const fn (data: ?*anyopaque) void,
    drop: *const fn (data: ?*anyopaque) void,
    data: ?*anyopaque,
};

/// How to reach an agent's loop from another thread: its task sink's
/// operations (runtime.TaskSink's, through src/dom/indexeddb.zig).
pub const SinkOps = struct {
    /// Take `task` whatever happens: run it on the sink's thread, or drop it
    /// (here, on failure). Returns whether it was accepted.
    post: *const fn (sink: *anyopaque, task: Task) bool,
    /// Give one reference back.
    release: *const fn (sink: *anyopaque) void,
};

/// The agent a record belongs to: its thread, and its loop's sink.
pub const Endpoint = struct {
    thread: std.Thread.Id,
    /// A reference to the agent's task sink, OWNED by the record that holds
    /// this endpoint (released when the record goes). Null: the agent hears
    /// only what is told on its own thread (a realm with no sink).
    sink: ?*anyopaque = null,
    ops: ?*const SinkOps = null,
    /// The execution context (its realm, opaque here) a connection was made
    /// in: its end closes the connection (`closeEnvironment`). Null for a
    /// native caller's.
    environment: ?*const anyopaque = null,

    /// An endpoint for the calling thread, with no sink.
    pub fn here() Endpoint {
        return .{ .thread = std.Thread.getCurrentId() };
    }

    fn isHere(self: Endpoint) bool {
        return self.thread == std.Thread.getCurrentId();
    }

    fn post(self: Endpoint, task: Task) void {
        const sink = self.sink orelse return task.drop(task.data);
        _ = self.ops.?.post(sink, task);
    }

    fn release(self: *Endpoint) void {
        if (self.sink) |sink| self.ops.?.release(sink);
        self.sink = null;
    }
};

/// What the server tells a record. Runs on the record's thread, never under
/// the lock.
pub const Note = union(enum) {
    /// A connection-queue entry: run its next step - it reached the head,
    /// its versionchange events were acknowledged, or a connection it waits
    /// on closed.
    advance,
    /// A connection: fire versionchange (ED 5.1 step 10.2). `posted` is
    /// true when this runs as a task of its own (from another thread), so
    /// the callee enters its realm; false when the opener's own database
    /// task tells it on this thread.
    versionchange: struct { old_version: u64, new_version: ?u64, posted: bool },
    /// A transaction: it may be able to start now.
    wake,
};

/// The agent-side object a record tells. `context` stays valid while the
/// record exists: its agent removes the record, on the agent's thread,
/// before freeing it.
pub const Client = struct {
    context: *anyopaque,
    call: *const fn (context: *anyopaque, note: Note) void,
};

/// IDBDatabaseInfo, OWNED: free with `freeInfos`.
pub const DatabaseInfo = struct { name: []u8, version: u64 };

pub fn freeInfos(allocator: Allocator, infos: []DatabaseInfo) void {
    for (infos) |info| allocator.free(info.name);
    allocator.free(infos);
}

const QueueEntry = struct {
    id: Id,
    endpoint: Endpoint,
    client: Client,
    /// Versionchange events posted to other threads and not yet
    /// acknowledged (ED 5.1 step 10.3 "wait for all of the events to be
    /// fired").
    pending_acks: u32 = 0,
    /// The entry waits for those acknowledgements: the last one advances it.
    awaiting_acks: bool = false,
    /// The entry waits for every connection to close (5.1 step 10.5, 5.3
    /// step 6): the last close advances it.
    awaiting_closes: bool = false,
    /// Its upgrade transaction, while it is unfinished.
    upgrade: ?Id = null,
    /// Its agent withdrew it mid-upgrade: it keeps the head, told nothing,
    /// until the upgrade transaction finishes (rolled back).
    abandoned: bool = false,
};

const ConnectionRecord = struct {
    id: Id,
    endpoint: Endpoint,
    client: Client,
    /// close() was called, or its agent ended: no versionchange is fired at
    /// it, and it is closed once its last transaction finishes.
    close_pending: bool = false,
    open_transactions: u32 = 0,
};

const TransactionRecord = struct {
    id: Id,
    /// Outlives this record: a connection stays in the set until its last
    /// transaction finishes.
    connection: *ConnectionRecord,
    mode: IDBTransactionMode,
    /// OWNED (server allocator).
    scope: [][]u8,
    started: bool = false,
    client: Client,

    fn overlaps(self: *const TransactionRecord, other: *const TransactionRecord) bool {
        for (self.scope) |name| for (other.scope) |other_name| {
            if (std.mem.eql(u8, name, other_name)) return true;
        };
        return false;
    }
};

/// One database name under one storage key: WebKit's UniqueIDBDatabase.
pub const UniqueIDBDatabase = struct {
    server: *IDBServer,
    /// OWNED (server allocator).
    storage_key: StorageKey,
    /// OWNED (server allocator).
    name: []u8,
    /// The canonical database - version, schema, records. Null while the
    /// database does not exist (never created, or deleted). One reference is
    /// the server's; every connection's `backing` holds another.
    durable: ?*IDBDatabase = null,
    queue: std.ArrayListUnmanaged(*QueueEntry) = .empty,
    connections: std.ArrayListUnmanaged(*ConnectionRecord) = .empty,
    /// ED 2.7.2: creation order across every connection.
    transactions: std.ArrayListUnmanaged(*TransactionRecord) = .empty,
    /// Agent natives and tasks in flight that point at this record.
    holders: u32 = 0,

    fn idle(self: *const UniqueIDBDatabase) bool {
        return self.holders == 0 and self.durable == null and self.queue.items.len == 0 and
            self.connections.items.len == 0 and self.transactions.items.len == 0;
    }

    fn findEntry(self: *UniqueIDBDatabase, id: Id) ?*QueueEntry {
        for (self.queue.items) |entry| if (entry.id == id) return entry;
        return null;
    }
    fn findConnection(self: *UniqueIDBDatabase, id: Id) ?*ConnectionRecord {
        for (self.connections.items) |connection| if (connection.id == id) return connection;
        return null;
    }
    fn findTransaction(self: *UniqueIDBDatabase, id: Id) ?*TransactionRecord {
        for (self.transactions.items) |transaction| if (transaction.id == id) return transaction;
        return null;
    }
    fn head(self: *UniqueIDBDatabase) ?*QueueEntry {
        return if (self.queue.items.len == 0) null else self.queue.items[0];
    }

    /// ED 2.7.2: a transaction can start when no transaction created before
    /// it with an overlapping scope is unfinished - two readonly ones aside -
    /// and an upgrade transaction excludes every other. Finished records are
    /// gone, so every earlier record is unfinished.
    fn canStart(self: *UniqueIDBDatabase, record: *const TransactionRecord) bool {
        for (self.transactions.items) |earlier| {
            if (earlier == record) return true;
            if (record.mode == .readonly and earlier.mode == .readonly) continue;
            if (record.mode == .versionchange or earlier.mode == .versionchange) return false;
            if (record.overlaps(earlier)) return false;
        }
        return true;
    }

    /// The durable database's version, or 0 when there is none.
    fn version(self: *const UniqueIDBDatabase) u64 {
        return if (self.durable) |durable| durable.version else 0;
    }
};

/// What to tell after the lock drops: a note for a record, by id. A local
/// note is looked up again when told (it may have gone meanwhile); a remote
/// one is posted as a task.
const Delivery = struct {
    database: *UniqueIDBDatabase,
    kind: enum { entry, connection, transaction },
    id: Id,
    note: Note,
    /// For a versionchange: the queue entry its acknowledgement goes to.
    ack_entry: Id = 0,
};

const Deliveries = struct {
    local: std.ArrayListUnmanaged(Delivery) = .empty,
    /// Posted tasks, made under the lock and posted after it.
    remote: std.ArrayListUnmanaged(struct { endpoint: Endpoint, task: Task }) = .empty,
    /// Endpoints of removed records, released after the lock: a sink's last
    /// reference closes it, and closing drops what it still holds - a drop
    /// that may come back here.
    releases: std.ArrayListUnmanaged(Endpoint) = .empty,
};

pub const IDBServer = struct {
    /// Thread-safe (a BrowserScope supplement's).
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    databases: std.HashMapUnmanaged(Key, *UniqueIDBDatabase, KeyContext, std.hash_map.default_max_load_percentage) = .empty,
    next_id: Id = 1,

    const Key = struct { storage_key: StorageKey, name: []const u8 };
    const KeyContext = struct {
        pub fn hash(_: KeyContext, key: Key) u64 {
            return std.hash.Wyhash.hash(key.storage_key.hash(), key.name);
        }
        pub fn eql(_: KeyContext, a: Key, b: Key) bool {
            return a.storage_key.equals(b.storage_key) and std.mem.eql(u8, a.name, b.name);
        }
    };

    /// A BrowserScope supplement's init.
    pub fn init(allocator: Allocator) IDBServer {
        return .{ .allocator = allocator };
    }

    /// With the Browser's scope, after every realm and loop of the Browser
    /// has ended: whatever is left has no agent remaining.
    pub fn deinit(self: *IDBServer) void {
        var it = self.databases.valueIterator();
        while (it.next()) |entry| self.destroyDatabase(entry.*);
        self.databases.deinit(self.allocator);
    }

    pub fn lock(self: *IDBServer) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }
    pub fn unlock(self: *IDBServer) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    fn nextId(self: *IDBServer) Id {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }

    fn destroyDatabase(self: *IDBServer, database: *UniqueIDBDatabase) void {
        for (database.queue.items) |entry| {
            entry.endpoint.release();
            self.allocator.destroy(entry);
        }
        database.queue.deinit(self.allocator);
        for (database.transactions.items) |transaction| self.destroyTransaction(transaction);
        database.transactions.deinit(self.allocator);
        for (database.connections.items) |connection| {
            connection.endpoint.release();
            self.allocator.destroy(connection);
        }
        database.connections.deinit(self.allocator);
        if (database.durable) |durable| durable.releaseHeapOwnership();
        var key = database.storage_key;
        key.deinit();
        self.allocator.free(database.name);
        self.allocator.destroy(database);
    }

    fn destroyTransaction(self: *IDBServer, transaction: *TransactionRecord) void {
        for (transaction.scope) |name| self.allocator.free(name);
        self.allocator.free(transaction.scope);
        self.allocator.destroy(transaction);
    }

    /// With the lock: forget `database` if nothing refers to it any more.
    fn maybeForget(self: *IDBServer, database: *UniqueIDBDatabase) void {
        if (!database.idle()) return;
        _ = self.databases.remove(.{ .storage_key = database.storage_key, .name = database.name });
        self.destroyDatabase(database);
    }

    // ---------------------------------------------------------------- databases

    /// The record of (`storage_key`, `name`), made on first use, held for
    /// the caller until `release`.
    pub fn uniqueDatabase(self: *IDBServer, storage_key: StorageKey, name: []const u8) Allocator.Error!*UniqueIDBDatabase {
        self.lock();
        defer self.unlock();
        const found = try self.databases.getOrPut(self.allocator, .{ .storage_key = storage_key, .name = name });
        if (found.found_existing) {
            found.value_ptr.*.holders += 1;
            return found.value_ptr.*;
        }
        errdefer _ = self.databases.remove(.{ .storage_key = storage_key, .name = name });
        const made = try self.allocator.create(UniqueIDBDatabase);
        errdefer self.allocator.destroy(made);
        var key_copy = try copyKey(self.allocator, storage_key);
        errdefer key_copy.deinit();
        const name_copy = try self.allocator.dupe(u8, name);
        made.* = .{ .server = self, .storage_key = key_copy, .name = name_copy, .holders = 1 };
        found.key_ptr.* = .{ .storage_key = made.storage_key, .name = made.name };
        found.value_ptr.* = made;
        return made;
    }

    /// Hold `database` once more (an agent native that keeps it).
    pub fn retain(self: *IDBServer, database: *UniqueIDBDatabase) void {
        self.lock();
        defer self.unlock();
        database.holders += 1;
    }

    /// Give back one hold. Any thread.
    pub fn release(self: *IDBServer, database: *UniqueIDBDatabase) void {
        self.lock();
        defer self.unlock();
        std.debug.assert(database.holders > 0);
        database.holders -= 1;
        self.maybeForget(database);
    }

    /// ED 4.3 databases() step 4.3: the name and version of every database
    /// of `storage_key`, omitting a version-zero one whose first upgrade has
    /// not committed (4.3.1). Copied out with `allocator`.
    pub fn databaseInfos(self: *IDBServer, storage_key: StorageKey, allocator: Allocator) Allocator.Error![]DatabaseInfo {
        var list: std.ArrayListUnmanaged(DatabaseInfo) = .empty;
        errdefer {
            for (list.items) |info| allocator.free(info.name);
            list.deinit(allocator);
        }
        self.lock();
        defer self.unlock();
        var it = self.databases.valueIterator();
        while (it.next()) |entry| {
            const database_record = entry.*;
            if (!database_record.storage_key.equals(storage_key)) continue;
            const version = database_record.version();
            if (version == 0) continue;
            const name = try allocator.dupe(u8, database_record.name);
            list.append(allocator, .{ .name = name, .version = version }) catch |err| {
                allocator.free(name);
                return err;
            };
        }
        return list.toOwnedSlice(allocator);
    }

    /// The durable database's version (0: none).
    pub fn currentVersion(self: *IDBServer, database: *UniqueIDBDatabase) u64 {
        self.lock();
        defer self.unlock();
        return database.version();
    }

    // ---------------------------------------------------------- the connection queue

    /// ED 2.8.2: append an open or delete request to the connection queue.
    /// `endpoint` (its sink reference) passes to the entry. Returns the
    /// entry's id and whether it is the head (its owner runs it now; any
    /// other is told `advance` when it becomes the head).
    pub fn enqueue(self: *IDBServer, database: *UniqueIDBDatabase, endpoint: Endpoint, client: Client) Allocator.Error!struct { id: Id, head: bool } {
        var owned = endpoint;
        errdefer owned.release();
        self.lock();
        defer self.unlock();
        const entry = try self.allocator.create(QueueEntry);
        errdefer self.allocator.destroy(entry);
        try database.queue.append(self.allocator, entry);
        entry.* = .{ .id = self.nextId(), .endpoint = owned, .client = client };
        return .{ .id = entry.id, .head = database.queue.items.len == 1 };
    }

    /// The request `id` is done (ED 5.1 / 5.3 last step): it leaves the
    /// queue, and the next one runs.
    pub fn dequeue(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) void {
        var deliveries: Deliveries = .{};
        {
            self.lock();
            defer self.unlock();
            self.removeEntryLocked(database, id, &deliveries);
        }
        self.deliver(&deliveries);
    }

    /// Its agent ended (or it could not continue) before request `id` was
    /// done. A request whose upgrade transaction is unfinished keeps the
    /// head, abandoned, until that transaction finishes - rolled back - so
    /// the next request never sees a half-upgraded database; any other
    /// leaves at once. Its client is never told again.
    pub fn withdraw(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) void {
        var deliveries: Deliveries = .{};
        {
            self.lock();
            defer self.unlock();
            const entry = database.findEntry(id) orelse return;
            if (entry.upgrade != null) {
                entry.abandoned = true;
                self.releaseLocked(&deliveries, &entry.endpoint);
            } else self.removeEntryLocked(database, id, &deliveries);
        }
        self.deliver(&deliveries);
    }

    fn removeEntryLocked(self: *IDBServer, database: *UniqueIDBDatabase, id: Id, deliveries: *Deliveries) void {
        for (database.queue.items, 0..) |entry, index| {
            if (entry.id != id) continue;
            _ = database.queue.orderedRemove(index);
            self.releaseLocked(deliveries, &entry.endpoint);
            self.allocator.destroy(entry);
            if (index == 0) self.advanceHeadLocked(database, deliveries);
            return;
        }
    }

    /// With the lock: the head changed; tell the new one to run.
    fn advanceHeadLocked(self: *IDBServer, database: *UniqueIDBDatabase, deliveries: *Deliveries) void {
        const entry = database.head() orelse return;
        if (entry.abandoned) return;
        self.noteLocked(deliveries, database, .entry, entry.id, entry.endpoint, .advance, 0);
    }

    pub const Start = union(enum) {
        /// ED 5.1 step 7: the requested version is lower.
        version_error: u64,
        proceed: struct {
            old_version: u64,
            /// Null for a deletion.
            new_version: ?u64,
            /// Whether connections must be told (5.1 step 10 / 5.3 step 5):
            /// the version rises, or this is a deletion.
            change: bool,
            /// The open connections on THIS thread to tell, in order, by the
            /// requester's own database tasks (`versionChangeWanted` before
            /// each). OWNED by the caller (its allocator).
            local: []Id,
        },
    };

    /// ED 5.1 steps 5-10.2 (open) / 5.3 steps 3-5 (delete), at the head of
    /// the queue: the version decision, then the snapshot of the open
    /// connections not close-pending (10.1-10.2). Those of other threads are
    /// told now, by a posted task each that the request waits on
    /// (`awaitAcknowledgements`); those of this thread are returned.
    pub fn start(self: *IDBServer, database: *UniqueIDBDatabase, id: Id, requested: ?u64, deletion: bool, allocator: Allocator) Allocator.Error!Start {
        var deliveries: Deliveries = .{};
        defer self.deliver(&deliveries);
        var local: std.ArrayListUnmanaged(Id) = .empty;
        errdefer local.deinit(allocator);
        self.lock();
        defer self.unlock();
        const old_version = database.version();
        const new_version: ?u64 = if (deletion) null else requested orelse if (old_version == 0) 1 else old_version;
        if (new_version) |target| if (target < old_version) return .{ .version_error = old_version };
        const change = deletion or new_version.? > old_version;
        if (change) {
            const entry = database.findEntry(id);
            for (database.connections.items) |connection| {
                if (connection.close_pending) continue;
                if (connection.endpoint.isHere()) {
                    try local.append(allocator, connection.id);
                    continue;
                }
                const note: Note = .{ .versionchange = .{ .old_version = old_version, .new_version = new_version, .posted = true } };
                if (entry) |owner| owner.pending_acks += 1;
                self.noteLocked(&deliveries, database, .connection, connection.id, connection.endpoint, note, id);
            }
        }
        return .{ .proceed = .{ .old_version = old_version, .new_version = new_version, .change = change, .local = try local.toOwnedSlice(allocator) } };
    }

    /// Whether connection `id` - on this thread - is still to be told
    /// versionchange: open, and its close not pending (ED 5.1 step 10.2's
    /// note: a connection closed meanwhile is skipped). Returns its client.
    pub fn versionChangeWanted(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) ?Client {
        self.lock();
        defer self.unlock();
        const connection = database.findConnection(id) orelse return null;
        if (connection.close_pending) return null;
        return connection.client;
    }

    /// ED 5.1 step 10.3: true when every posted versionchange has been
    /// acknowledged; otherwise the last acknowledgement tells request `id`
    /// `advance`.
    pub fn awaitAcknowledgements(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) bool {
        self.lock();
        defer self.unlock();
        const entry = database.findEntry(id) orelse return true;
        if (entry.pending_acks == 0) return true;
        entry.awaiting_acks = true;
        return false;
    }

    /// One posted versionchange was fired, skipped, or dropped.
    fn acknowledge(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) void {
        var deliveries: Deliveries = .{};
        {
            self.lock();
            defer self.unlock();
            const entry = database.findEntry(id) orelse return;
            std.debug.assert(entry.pending_acks > 0);
            entry.pending_acks -= 1;
            if (entry.pending_acks == 0 and entry.awaiting_acks and !entry.abandoned) {
                entry.awaiting_acks = false;
                self.noteLocked(&deliveries, database, .entry, entry.id, entry.endpoint, .advance, 0);
            }
        }
        self.deliver(&deliveries);
    }

    /// ED 5.1 step 10.4 / 5.3 step 6: whether any connection is not yet
    /// closed (a close-pending one counts until its transactions finish).
    pub fn hasConnections(self: *IDBServer, database: *UniqueIDBDatabase) bool {
        self.lock();
        defer self.unlock();
        return database.connections.items.len != 0;
    }

    /// ED 5.1 step 10.5 / 5.3 step 7: true when every connection is closed;
    /// otherwise the last close tells request `id` `advance`.
    pub fn awaitCloses(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) bool {
        self.lock();
        defer self.unlock();
        if (database.connections.items.len == 0) return true;
        const entry = database.findEntry(id) orelse return true;
        entry.awaiting_closes = true;
        return false;
    }

    /// ED 5.3 "delete a database" steps 8-11, every connection closed: the
    /// database goes; returns its version (0 when there was none).
    /// Connections still open (a native caller's) keep the old one.
    pub fn deleteDatabase(self: *IDBServer, database: *UniqueIDBDatabase) u64 {
        self.lock();
        defer self.unlock();
        const durable = database.durable orelse return 0;
        const old_version = durable.version;
        database.durable = null;
        durable.releaseHeapOwnership();
        return old_version;
    }

    pub const Opened = struct {
        /// The new connection, made with the caller's allocator; it holds
        /// `database` and its `backing`. Its client is its own
        /// (`IDBDatabase.serverNote`).
        connection: *IDBDatabase,
        old_version: u64,
    };

    /// ED 5.1 steps 4 and 11, every other connection closed: make the
    /// database if it does not exist (version 0), and a connection to it at
    /// `version`. With `pending_upgrade`, the version is published only by
    /// the upgrade transaction's commit (5.7); without, at once (a
    /// single-agent test's synchronous open). `endpoint` passes to the
    /// connection's record.
    pub fn openConnection(self: *IDBServer, database: *UniqueIDBDatabase, version: u64, pending_upgrade: bool, allocator: Allocator, endpoint: Endpoint) (Allocator.Error || IDBError)!Opened {
        var owned = endpoint;
        errdefer owned.release();
        const record = try self.allocator.create(ConnectionRecord);
        errdefer self.allocator.destroy(record);
        const connection = try allocator.create(IDBDatabase);
        // Until the connection holds its backing, its allocation is this
        // call's; after, its own deinit frees it.
        var connection_made = false;
        errdefer if (!connection_made) allocator.destroy(connection);
        errdefer if (connection_made) connection.releaseHeapOwnership();
        self.lock();
        defer self.unlock();
        // A database made here had no version before (ED 5.1 step 4).
        const made_now = database.durable == null;
        if (made_now) {
            const durable = try self.allocator.create(IDBDatabase);
            errdefer self.allocator.destroy(durable);
            const name = try self.allocator.dupe(u8, database.name);
            durable.* = IDBDatabase.init(self.allocator, name, if (pending_upgrade) 0 else version);
            durable.owned_name = name;
            durable.schema_mutex = &self.mutex;
            database.durable = durable;
        }
        const durable = database.durable.?;
        const old_version = if (made_now) 0 else durable.version;
        if (version < old_version) return IDBError.VersionError;
        connection.* = IDBDatabase.init(allocator, database.name, version);
        connection.backing = durable;
        durable.retain();
        connection_made = true;
        try connection.copyConnectionNames();
        try database.connections.append(self.allocator, record);
        record.* = .{ .id = self.nextId(), .endpoint = owned, .client = .{ .context = connection, .call = IDBDatabase.serverNote } };
        connection.server_database = database;
        connection.connection_id = record.id;
        database.holders += 1;
        if (!pending_upgrade) durable.version = version;
        return .{ .connection = connection, .old_version = old_version };
    }

    // -------------------------------------------------------------- connections

    /// ED 5.2 "close a database connection" step 1 - close() was called, or
    /// the connection's agent or wrapper ended: no versionchange is fired at
    /// it, and it is closed (leaves the set, waking a request that waits on
    /// closes) when its last transaction finishes. Idempotent.
    pub fn closePending(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) void {
        var deliveries: Deliveries = .{};
        {
            self.lock();
            defer self.unlock();
            const connection = database.findConnection(id) orelse return;
            connection.close_pending = true;
            if (connection.open_transactions == 0) self.removeConnectionLocked(database, connection, &deliveries);
        }
        self.deliver(&deliveries);
    }

    /// IndexedDB 2.? connection: "If the execution context where the
    /// connection was created is destroyed (for example due to the user
    /// navigating away from that page), the connection is closed."
    /// `environment` ended - a document unloaded or destroyed, a worker's
    /// global ended (dom.unloading_cleanup): every connection made in it is
    /// close-pending, closed once its transactions finish - and they finish:
    /// a realm that runs no task again aborts each one at its next run.
    pub fn closeEnvironment(self: *IDBServer, environment: *const anyopaque) void {
        var deliveries: Deliveries = .{};
        {
            self.lock();
            defer self.unlock();
            var it = self.databases.valueIterator();
            while (it.next()) |entry| {
                const database = entry.*;
                var index: usize = 0;
                while (index < database.connections.items.len) {
                    const connection = database.connections.items[index];
                    if (connection.endpoint.environment != environment) {
                        index += 1;
                        continue;
                    }
                    connection.close_pending = true;
                    if (connection.open_transactions == 0) {
                        self.removeConnectionLocked(database, connection, &deliveries);
                    } else index += 1;
                }
            }
        }
        self.deliver(&deliveries);
    }

    fn removeConnectionLocked(self: *IDBServer, database: *UniqueIDBDatabase, connection: *ConnectionRecord, deliveries: *Deliveries) void {
        for (database.connections.items, 0..) |entry, index| {
            if (entry != connection) continue;
            _ = database.connections.orderedRemove(index);
            break;
        }
        self.releaseLocked(deliveries, &connection.endpoint);
        self.allocator.destroy(connection);
        if (database.connections.items.len != 0) return;
        const entry = database.head() orelse return;
        if (!entry.awaiting_closes or entry.abandoned) return;
        entry.awaiting_closes = false;
        self.noteLocked(deliveries, database, .entry, entry.id, entry.endpoint, .advance, 0);
    }

    // ------------------------------------------------------------- transactions

    /// ED 4.4 transaction() step 8 / 5.7 step 3: a new transaction of
    /// connection `connection_id`, last in creation order. `client` is told
    /// `wake` when an earlier transaction finishes and it may start.
    pub fn createTransaction(self: *IDBServer, database: *UniqueIDBDatabase, connection_id: Id, mode: IDBTransactionMode, scope: []const []const u8, client: Client) Allocator.Error!Id {
        const names = try self.allocator.alloc([]u8, scope.len);
        var copied: usize = 0;
        errdefer {
            for (names[0..copied]) |name| self.allocator.free(name);
            self.allocator.free(names);
        }
        for (scope) |name| {
            names[copied] = try self.allocator.dupe(u8, name);
            copied += 1;
        }
        const record = try self.allocator.create(TransactionRecord);
        errdefer self.allocator.destroy(record);
        self.lock();
        defer self.unlock();
        const connection = database.findConnection(connection_id) orelse return error.OutOfMemory;
        try database.transactions.append(self.allocator, record);
        record.* = .{ .id = self.nextId(), .connection = connection, .mode = mode, .scope = names, .client = client };
        connection.open_transactions += 1;
        if (mode == .versionchange) if (database.head()) |entry| {
            entry.upgrade = record.id;
        };
        return record.id;
    }

    /// ED 2.7.2: whether transaction `id` can start; once it can, it is
    /// started for good (an earlier transaction only ever finishes).
    pub fn tryStart(self: *IDBServer, database: *UniqueIDBDatabase, id: Id) bool {
        self.lock();
        defer self.unlock();
        const record = database.findTransaction(id) orelse return true;
        if (record.started) return true;
        if (!database.canStart(record)) return false;
        record.started = true;
        return true;
    }

    /// Transaction `id` committed or aborted - and its rollback, if any, is
    /// done: it leaves the scheduler. `publish` is an upgrade's committed
    /// version (ED 5.7: the database's version changes only when the upgrade
    /// commits). Every transaction that can start now is woken; a
    /// close-pending connection left with no transaction is closed; an
    /// upgrade's abandoned request leaves the queue's head.
    pub fn finishTransaction(self: *IDBServer, database: *UniqueIDBDatabase, id: Id, publish: ?u64) void {
        var deliveries: Deliveries = .{};
        var finished: ?*TransactionRecord = null;
        {
            self.lock();
            defer self.unlock();
            for (database.transactions.items, 0..) |record, index| {
                if (record.id != id) continue;
                finished = database.transactions.orderedRemove(index);
                break;
            }
            const record = finished orelse return;
            if (publish) |committed| if (database.durable) |durable| {
                durable.version = committed;
            };
            if (record.mode == .versionchange) if (database.head()) |entry| {
                if (entry.upgrade == id) {
                    entry.upgrade = null;
                    if (entry.abandoned) self.removeEntryLocked(database, entry.id, &deliveries);
                }
            };
            const connection = record.connection;
            connection.open_transactions -= 1;
            if (connection.close_pending and connection.open_transactions == 0) self.removeConnectionLocked(database, connection, &deliveries);
            for (database.transactions.items) |waiting| {
                if (waiting.started or !database.canStart(waiting)) continue;
                self.noteLocked(&deliveries, database, .transaction, waiting.id, waiting.connection.endpoint, .wake, 0);
            }
        }
        self.destroyTransaction(finished.?);
        self.deliver(&deliveries);
    }

    // ----------------------------------------------------------------- delivery

    /// With the lock: tell record `id` `note` - directly after the lock
    /// drops when `endpoint` is this thread's, else by a task posted to it.
    fn noteLocked(self: *IDBServer, deliveries: *Deliveries, database: *UniqueIDBDatabase, kind: @FieldType(Delivery, "kind"), id: Id, endpoint: Endpoint, note: Note, ack_entry: Id) void {
        const delivery: Delivery = .{ .database = database, .kind = kind, .id = id, .note = note, .ack_entry = ack_entry };
        if (endpoint.isHere()) {
            deliveries.local.append(self.allocator, delivery) catch {
                // Never to be told: a versionchange counts as acknowledged.
                if (note == .versionchange) self.acknowledgeLocked(database, ack_entry);
            };
            return;
        }
        const posted = Posted.create(self, delivery) catch {
            if (note == .versionchange) self.acknowledgeLocked(database, ack_entry);
            return;
        };
        database.holders += 1;
        deliveries.remote.append(self.allocator, .{ .endpoint = endpoint, .task = posted.task() }) catch {
            database.holders -= 1;
            self.allocator.destroy(posted);
            if (note == .versionchange) self.acknowledgeLocked(database, ack_entry);
        };
    }

    /// With the lock: an acknowledgement that cannot be posted or told.
    /// Its advance, if it was the last, is lost with it - so it never is:
    /// the request waiting on acknowledgements is told directly when this is
    /// its thread, and is otherwise left for the next acknowledgement or
    /// close (allocation failure only).
    fn acknowledgeLocked(_: *IDBServer, database: *UniqueIDBDatabase, id: Id) void {
        const entry = database.findEntry(id) orelse return;
        if (entry.pending_acks > 0) entry.pending_acks -= 1;
    }

    /// With the lock: `endpoint`'s sink reference goes after the lock
    /// drops (`Deliveries.releases`).
    fn releaseLocked(self: *IDBServer, deliveries: *Deliveries, endpoint: *Endpoint) void {
        if (endpoint.sink == null) return;
        deliveries.releases.append(self.allocator, endpoint.*) catch {
            // No room to defer it: the sink is still held by its loop while
            // its agent has records here, so this is not its last reference.
            endpoint.release();
            return;
        };
        endpoint.sink = null;
    }

    /// After the lock: post what goes to other threads, then tell this
    /// thread's records, each looked up again by id.
    fn deliver(self: *IDBServer, deliveries: *Deliveries) void {
        for (deliveries.releases.items) |*endpoint| endpoint.release();
        deliveries.releases.deinit(self.allocator);
        for (deliveries.remote.items) |remote| remote.endpoint.post(remote.task);
        deliveries.remote.deinit(self.allocator);
        for (deliveries.local.items) |delivery| self.tell(delivery);
        deliveries.local.deinit(self.allocator);
    }

    /// On the record's thread: find it, and tell it.
    fn tell(self: *IDBServer, delivery: Delivery) void {
        const client = blk: {
            self.lock();
            defer self.unlock();
            break :blk self.clientLocked(delivery);
        };
        if (client) |found| found.call(found.context, delivery.note);
        if (delivery.note == .versionchange) self.acknowledge(delivery.database, delivery.ack_entry);
    }

    fn clientLocked(_: *IDBServer, delivery: Delivery) ?Client {
        const database = delivery.database;
        return switch (delivery.kind) {
            .entry => if (database.findEntry(delivery.id)) |entry| if (entry.abandoned) null else entry.client else null,
            .connection => if (database.findConnection(delivery.id)) |connection| if (connection.close_pending) null else connection.client else null,
            .transaction => if (database.findTransaction(delivery.id)) |transaction| transaction.client else null,
        };
    }

    /// A note posted to another thread's loop. Holds its database record
    /// (`holders`) until it runs or is dropped; the server outlives it (the
    /// Browser's scope ends after every loop of the Browser, and a loop's end
    /// drops what it did not run).
    const Posted = struct {
        server: *IDBServer,
        delivery: Delivery,

        fn create(server: *IDBServer, delivery: Delivery) Allocator.Error!*Posted {
            const self = try server.allocator.create(Posted);
            self.* = .{ .server = server, .delivery = delivery };
            return self;
        }

        fn task(self: *Posted) Task {
            return .{ .run = run, .drop = drop, .data = self };
        }

        fn run(data: ?*anyopaque) void {
            const self: *Posted = @ptrCast(@alignCast(data.?));
            const server = self.server;
            const delivery = self.delivery;
            server.allocator.destroy(self);
            server.tell(delivery);
            server.release(delivery.database);
        }

        /// Never to run (its loop ended): a versionchange counts as
        /// acknowledged, as for a connection found closed.
        fn drop(data: ?*anyopaque) void {
            const self: *Posted = @ptrCast(@alignCast(data.?));
            const server = self.server;
            const delivery = self.delivery;
            server.allocator.destroy(self);
            if (delivery.note == .versionchange) server.acknowledge(delivery.database, delivery.ack_entry);
            server.release(delivery.database);
        }
    };
};
