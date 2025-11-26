//! SQLite Transaction Mapping for IndexedDB
//!
//! Maps IndexedDB transactions to SQLite transactions, providing:
//! - Transaction isolation levels per IDB spec
//! - Deadlock prevention with IMMEDIATE mode for writes
//! - Savepoint support for nested transaction semantics
//! - Auto-commit handling for standalone operations
//!
//! ## Transaction Modes (W3C IndexedDB 3.0)
//!
//! | IDB Mode      | SQLite Mode     | Isolation | Concurrent Reads |
//! |---------------|-----------------|-----------|------------------|
//! | readonly      | DEFERRED        | Read      | Yes              |
//! | readwrite     | IMMEDIATE       | Write     | Yes (WAL mode)   |
//! | versionchange | EXCLUSIVE       | Exclusive | No               |
//!
//! ## Spec References
//!
//! - W3C IndexedDB 3.0 Transactions: https://w3c.github.io/IndexedDB/#transaction-concept
//! - SQLite Transaction Control: https://sqlite.org/lang_transaction.html

const std = @import("std");
const backend = @import("../backend.zig");
const TransactionMode = backend.TransactionMode;
const TransactionHandle = backend.TransactionHandle;
const BackendError = backend.BackendError;

// ============================================================================
// Transaction State Management
// ============================================================================

/// Transaction state per IDB spec
pub const TransactionState = enum {
    /// Transaction is active and can process requests
    active,
    /// Transaction is committing (no new requests)
    committing,
    /// Transaction has successfully committed
    finished,
    /// Transaction was aborted
    aborted,
};

/// Error reasons for transaction abort
pub const AbortReason = enum {
    /// Explicit abort() call
    explicit,
    /// Error during operation
    error_occurred,
    /// Constraint violation (unique key, etc.)
    constraint_violation,
    /// Database connection closed
    connection_closed,
    /// Timeout waiting for locks
    timeout,
    /// Unknown/internal error
    unknown,
};

/// SQLite transaction wrapper for IndexedDB
pub const SQLiteTransaction = struct {
    /// Unique transaction ID
    id: u64,
    /// IDB transaction mode
    mode: TransactionMode,
    /// Current state
    state: TransactionState,
    /// Object stores this transaction has access to
    scope: std.StringHashMap(void),
    /// Savepoint name for nested transactions
    savepoint_name: ?[]const u8,
    /// Error that caused abort (if any)
    abort_reason: ?AbortReason,
    /// Whether SQLite transaction has been started
    sqlite_started: bool,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, id: u64, mode: TransactionMode) Self {
        return Self{
            .id = id,
            .mode = mode,
            .state = .active,
            .scope = std.StringHashMap(void).init(allocator),
            .savepoint_name = null,
            .abort_reason = null,
            .sqlite_started = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all scope key copies
        var iter = self.scope.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.scope.deinit();
        if (self.savepoint_name) |name| {
            self.allocator.free(name);
        }
        self.* = undefined;
    }

    /// Add an object store to this transaction's scope
    pub fn addToScope(self: *Self, store_name: []const u8) !void {
        const name_copy = try self.allocator.dupe(u8, store_name);
        errdefer self.allocator.free(name_copy);
        try self.scope.put(name_copy, {});
    }

    /// Check if store is in scope
    pub fn hasInScope(self: Self, store_name: []const u8) bool {
        return self.scope.contains(store_name);
    }

    /// Check if transaction is active
    pub fn isActive(self: Self) bool {
        return self.state == .active;
    }

    /// Check if transaction can be modified (requests can be added)
    pub fn canAddRequests(self: Self) bool {
        return self.state == .active;
    }

    /// Mark transaction as committing
    pub fn startCommitting(self: *Self) void {
        if (self.state == .active) {
            self.state = .committing;
        }
    }

    /// Mark transaction as finished
    pub fn finish(self: *Self) void {
        self.state = .finished;
    }

    /// Mark transaction as aborted
    pub fn abort(self: *Self, reason: AbortReason) void {
        self.state = .aborted;
        self.abort_reason = reason;
    }
};

// ============================================================================
// Transaction Manager
// ============================================================================

/// Manages SQLite transactions for IndexedDB
pub const SQLiteTransactionManager = struct {
    /// Active transactions by ID
    transactions: std.AutoHashMap(u64, *SQLiteTransaction),
    /// Next transaction ID
    next_id: u64,
    /// Allocator
    allocator: std.mem.Allocator,
    /// Maximum concurrent transactions (0 = unlimited)
    max_transactions: u32,
    /// Lock timeout in milliseconds
    lock_timeout_ms: u32,

    const Self = @This();

    /// Default lock timeout: 5 seconds
    pub const DEFAULT_LOCK_TIMEOUT_MS: u32 = 5000;

    /// Default max transactions (for memory safety)
    pub const DEFAULT_MAX_TRANSACTIONS: u32 = 100;

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .transactions = std.AutoHashMap(u64, *SQLiteTransaction).init(allocator),
            .next_id = 1,
            .allocator = allocator,
            .max_transactions = DEFAULT_MAX_TRANSACTIONS,
            .lock_timeout_ms = DEFAULT_LOCK_TIMEOUT_MS,
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up all transactions
        var iter = self.transactions.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.transactions.deinit();
    }

    /// Begin a new transaction
    pub fn beginTransaction(self: *Self, mode: TransactionMode, store_names: []const []const u8) !*SQLiteTransaction {
        // Check transaction limit
        if (self.max_transactions > 0 and self.transactions.count() >= self.max_transactions) {
            return error.TooManyTransactions;
        }

        const txn_id = self.next_id;
        self.next_id += 1;

        const txn = try self.allocator.create(SQLiteTransaction);
        errdefer self.allocator.destroy(txn);

        txn.* = SQLiteTransaction.init(self.allocator, txn_id, mode);
        errdefer txn.deinit();

        // Add stores to scope
        for (store_names) |name| {
            try txn.addToScope(name);
        }

        try self.transactions.put(txn_id, txn);

        return txn;
    }

    /// Get a transaction by ID
    pub fn getTransaction(self: *Self, id: u64) ?*SQLiteTransaction {
        return self.transactions.get(id);
    }

    /// Commit a transaction
    pub fn commitTransaction(self: *Self, id: u64) !void {
        const txn = self.transactions.get(id) orelse return error.TransactionNotFound;

        if (!txn.isActive()) {
            return error.TransactionInactive;
        }

        txn.startCommitting();
        // Actual SQLite commit would happen here via backend
        txn.finish();

        // Remove from active transactions
        _ = self.transactions.remove(id);
        txn.deinit();
        self.allocator.destroy(txn);
    }

    /// Abort a transaction
    pub fn abortTransaction(self: *Self, id: u64, reason: AbortReason) void {
        const txn = self.transactions.get(id) orelse return;

        txn.abort(reason);

        // Remove from active transactions
        _ = self.transactions.remove(id);
        txn.deinit();
        self.allocator.destroy(txn);
    }

    /// Get count of active transactions
    pub fn activeCount(self: Self) usize {
        return self.transactions.count();
    }

    /// Check if any versionchange transaction is active
    pub fn hasVersionChange(self: Self) bool {
        var iter = self.transactions.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.mode == .versionchange) {
                return true;
            }
        }
        return false;
    }
};

// ============================================================================
// SQL Generation for Transaction Control
// ============================================================================

/// SQL statements for transaction control
pub const TransactionSQL = struct {
    /// Begin transaction based on mode
    pub fn beginStatement(mode: TransactionMode) []const u8 {
        return switch (mode) {
            .readonly => "BEGIN DEFERRED",
            .readwrite => "BEGIN IMMEDIATE",
            .versionchange => "BEGIN EXCLUSIVE",
        };
    }

    /// Commit transaction
    pub const commit = "COMMIT";

    /// Rollback transaction
    pub const rollback = "ROLLBACK";

    /// Create savepoint for nested transaction
    pub fn savepointStatement(buf: []u8, name: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "SAVEPOINT {s}", .{name}) catch error.BufferTooSmall;
    }

    /// Release savepoint (commit nested)
    pub fn releaseSavepointStatement(buf: []u8, name: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "RELEASE SAVEPOINT {s}", .{name}) catch error.BufferTooSmall;
    }

    /// Rollback to savepoint
    pub fn rollbackToSavepointStatement(buf: []u8, name: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "ROLLBACK TO SAVEPOINT {s}", .{name}) catch error.BufferTooSmall;
    }

    /// Set lock timeout pragma
    pub fn setLockTimeoutStatement(buf: []u8, timeout_ms: u32) ![]const u8 {
        return std.fmt.bufPrint(buf, "PRAGMA busy_timeout = {d}", .{timeout_ms}) catch error.BufferTooSmall;
    }
};

// ============================================================================
// Transaction Queue for Ordering
// ============================================================================

/// Request in a transaction queue
pub const QueuedRequest = struct {
    /// Request ID
    id: u64,
    /// Operation type
    operation: OperationType,
    /// Store name
    store_name: []const u8,
    /// Key (for single-key operations)
    key: ?[]const u8,
    /// Value (for write operations)
    value: ?[]const u8,
    /// Callback when complete
    callback: ?*const fn (result: RequestResult) void,

    pub const OperationType = enum {
        get,
        get_all,
        get_all_keys,
        put,
        add,
        delete,
        delete_all,
        count,
        open_cursor,
        open_key_cursor,
    };
};

/// Result of a queued request
pub const RequestResult = union(enum) {
    success: struct {
        value: ?[]const u8,
        key: ?[]const u8,
    },
    error_result: struct {
        code: BackendError,
        message: ?[]const u8,
    },
};

/// Queue of requests for a transaction
pub const TransactionQueue = struct {
    /// Pending requests
    requests: std.ArrayListUnmanaged(QueuedRequest),
    /// Transaction ID
    transaction_id: u64,
    /// Allocator
    allocator: std.mem.Allocator,
    /// Next request ID
    next_request_id: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, transaction_id: u64) Self {
        return Self{
            .requests = .{},
            .transaction_id = transaction_id,
            .allocator = allocator,
            .next_request_id = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        self.requests.deinit(self.allocator);
    }

    /// Add a request to the queue
    pub fn enqueue(self: *Self, operation: QueuedRequest.OperationType, store_name: []const u8, key: ?[]const u8, value: ?[]const u8) !u64 {
        const request_id = self.next_request_id;
        self.next_request_id += 1;

        try self.requests.append(self.allocator, QueuedRequest{
            .id = request_id,
            .operation = operation,
            .store_name = store_name,
            .key = key,
            .value = value,
            .callback = null,
        });

        return request_id;
    }

    /// Get next request (FIFO)
    pub fn dequeue(self: *Self) ?QueuedRequest {
        if (self.requests.items.len == 0) {
            return null;
        }
        return self.requests.orderedRemove(0);
    }

    /// Check if queue is empty
    pub fn isEmpty(self: Self) bool {
        return self.requests.items.len == 0;
    }

    /// Get queue length
    pub fn len(self: Self) usize {
        return self.requests.items.len;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "SQLiteTransaction - init and deinit" {
    const allocator = std.testing.allocator;

    var txn = SQLiteTransaction.init(allocator, 1, .readwrite);
    defer txn.deinit();

    try std.testing.expectEqual(@as(u64, 1), txn.id);
    try std.testing.expectEqual(TransactionMode.readwrite, txn.mode);
    try std.testing.expectEqual(TransactionState.active, txn.state);
    try std.testing.expect(txn.isActive());
}

test "SQLiteTransaction - scope management" {
    const allocator = std.testing.allocator;

    var txn = SQLiteTransaction.init(allocator, 1, .readwrite);
    defer txn.deinit();

    try txn.addToScope("store1");
    try txn.addToScope("store2");

    try std.testing.expect(txn.hasInScope("store1"));
    try std.testing.expect(txn.hasInScope("store2"));
    try std.testing.expect(!txn.hasInScope("store3"));
}

test "SQLiteTransaction - state transitions" {
    const allocator = std.testing.allocator;

    var txn = SQLiteTransaction.init(allocator, 1, .readwrite);
    defer txn.deinit();

    // Active -> Committing
    try std.testing.expect(txn.canAddRequests());
    txn.startCommitting();
    try std.testing.expectEqual(TransactionState.committing, txn.state);
    try std.testing.expect(!txn.canAddRequests());

    // Committing -> Finished
    txn.finish();
    try std.testing.expectEqual(TransactionState.finished, txn.state);
}

test "SQLiteTransaction - abort" {
    const allocator = std.testing.allocator;

    var txn = SQLiteTransaction.init(allocator, 1, .readwrite);
    defer txn.deinit();

    txn.abort(.constraint_violation);

    try std.testing.expectEqual(TransactionState.aborted, txn.state);
    try std.testing.expectEqual(AbortReason.constraint_violation, txn.abort_reason.?);
}

test "SQLiteTransactionManager - begin and commit" {
    const allocator = std.testing.allocator;

    var mgr = SQLiteTransactionManager.init(allocator);
    defer mgr.deinit();

    const txn = try mgr.beginTransaction(.readwrite, &.{ "store1", "store2" });

    try std.testing.expectEqual(@as(usize, 1), mgr.activeCount());
    try std.testing.expect(txn.hasInScope("store1"));
    try std.testing.expect(txn.hasInScope("store2"));

    try mgr.commitTransaction(txn.id);
    try std.testing.expectEqual(@as(usize, 0), mgr.activeCount());
}

test "SQLiteTransactionManager - abort" {
    const allocator = std.testing.allocator;

    var mgr = SQLiteTransactionManager.init(allocator);
    defer mgr.deinit();

    const txn = try mgr.beginTransaction(.readonly, &.{"store1"});
    const txn_id = txn.id;

    mgr.abortTransaction(txn_id, .explicit);
    try std.testing.expectEqual(@as(usize, 0), mgr.activeCount());
}

test "SQLiteTransactionManager - versionchange detection" {
    const allocator = std.testing.allocator;

    var mgr = SQLiteTransactionManager.init(allocator);
    defer mgr.deinit();

    try std.testing.expect(!mgr.hasVersionChange());

    _ = try mgr.beginTransaction(.versionchange, &.{});
    try std.testing.expect(mgr.hasVersionChange());
}

test "TransactionSQL - statement generation" {
    try std.testing.expectEqualStrings("BEGIN DEFERRED", TransactionSQL.beginStatement(.readonly));
    try std.testing.expectEqualStrings("BEGIN IMMEDIATE", TransactionSQL.beginStatement(.readwrite));
    try std.testing.expectEqualStrings("BEGIN EXCLUSIVE", TransactionSQL.beginStatement(.versionchange));
}

test "TransactionQueue - enqueue and dequeue" {
    const allocator = std.testing.allocator;

    var queue = TransactionQueue.init(allocator, 1);
    defer queue.deinit();

    _ = try queue.enqueue(.get, "store1", "key1", null);
    _ = try queue.enqueue(.put, "store1", "key2", "value2");

    try std.testing.expectEqual(@as(usize, 2), queue.len());

    const req1 = queue.dequeue().?;
    try std.testing.expectEqual(QueuedRequest.OperationType.get, req1.operation);

    const req2 = queue.dequeue().?;
    try std.testing.expectEqual(QueuedRequest.OperationType.put, req2.operation);

    try std.testing.expect(queue.isEmpty());
}
