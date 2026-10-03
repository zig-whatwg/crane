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
    rollback_version: u64 = 0,

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
        if (self.rollback_schema) |*schema_map| IDBDatabase.deinitSchema(schema_map, self.allocator);
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

    /// IDB 5.5 step 2: keep the pre-write schema, records and generators until
    /// commit succeeds. Native storage is synchronous; dispatch remains queued.
    pub fn ensureRollbackSnapshot(self: *Self) !void {
        if (self.rollback_schema != null) return;
        if (self.mode == .readonly) return;
        self.rollback_schema = try self.db.cloneSchema();
        self.rollback_version = if (self.db.backing) |database| database.version else self.db.version;
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
            store.auto_increment = metadata.auto_increment;
            store.attachRecords(metadata.record_data);
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
    pub fn commit(self: *Self) IDBError!void {
        // Step 1: Check state
        if (self.state == .finished) {
            return IDBError.InvalidStateError;
        }

        if (self.mode == .versionchange) self.db.publishVersion();
        if (self.rollback_schema) |*schema_map| IDBDatabase.deinitSchema(schema_map, self.allocator);
        self.rollback_schema = null;

        // Step 2: Set state to committing
        self.state = .committing;

        // Step 3: Process pending requests (simplified - synchronous)
        // In a real implementation, this would be async
        self.state = .finished;

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

        // IDB 5.5 step 2: restore schema, records and key generators atomically.
        if (self.rollback_schema) |snapshot| {
            if (self.mode == .versionchange) {
                var changed = self.db.schema().*;
                self.db.schema().* = snapshot;
                self.rollback_schema = null;
                IDBDatabase.deinitSchema(&changed, self.allocator);
                self.db.version = self.rollback_version;
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

        // Step 4: Set state to finished
        self.state = .finished;
        self.err = IDBError.AbortError;

        // Native notification; the binding queues the DOM abort event (step 7).
        if (self.onabort) |handler| {
            handler(self);
        }
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
