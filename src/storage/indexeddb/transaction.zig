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
        return Self{
            .allocator = allocator,
            .db = db,
            .scope = scope,
            .mode = mode,
            .state = .active,
            .durability = .default,
            .err = null,
            .requests = .{},
            .object_stores = std.StringHashMap(*IDBObjectStore).init(allocator),
            .onabort = null,
            .oncomplete = null,
            .onerror = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.requests.deinit(self.allocator);

        var it = self.object_stores.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.object_stores.deinit();
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
        var found = false;
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

        // Get metadata from database
        if (self.db.object_stores.get(name)) |metadata| {
            store.key_path = metadata.key_path;
            store.auto_increment = metadata.auto_increment;
        }

        try self.object_stores.put(name, store);

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
        if (self.state != .active and self.state != .inactive) {
            return IDBError.InvalidStateError;
        }

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

        // Step 2: Set state to finished
        self.state = .finished;
        self.err = IDBError.AbortError;

        // Step 3: Undo changes (implementation-specific)
        // In a real implementation, this would rollback changes

        // Step 4: Fire abort event
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
