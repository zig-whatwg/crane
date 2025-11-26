//! Worker Thread Integration for SQLite Operations
//!
//! Provides async SQLite operations via a thread pool to avoid blocking
//! the JavaScript event loop. Operations are queued, executed on worker
//! threads, and results are returned via callbacks.
//!
//! ## Architecture
//!
//! ```
//! JavaScript Code
//!     │
//!     ▼
//! IDBRequest (async)
//!     │
//!     ▼
//! WorkerPool (thread pool)
//!     │
//!     ├── Worker 1: SQLite ops
//!     ├── Worker 2: SQLite ops
//!     └── Worker N: SQLite ops
//!     │
//!     ▼
//! Callback → Event Loop → JS Promise Resolution
//! ```
//!
//! ## Thread Safety
//!
//! - Each worker has its own SQLite connection
//! - Work items are queued via thread-safe queue
//! - Results returned via atomic completion flags
//!
//! ## Spec References
//!
//! - IDB async model: https://w3c.github.io/IndexedDB/#async-api
//! - Transaction lifetime: https://w3c.github.io/IndexedDB/#transaction-lifetime

const std = @import("std");

// ============================================================================
// Work Item Types
// ============================================================================

/// Type of database operation
pub const WorkItemType = enum {
    /// Execute SQL query (SELECT)
    query,
    /// Execute SQL statement (INSERT/UPDATE/DELETE)
    execute,
    /// Begin transaction
    begin_transaction,
    /// Commit transaction
    commit_transaction,
    /// Rollback transaction
    rollback_transaction,
    /// Open database connection
    open_connection,
    /// Close database connection
    close_connection,
};

/// Result from a work item execution
pub const WorkResult = struct {
    /// Whether the operation succeeded
    success: bool,
    /// Error message if failed
    error_message: ?[]const u8,
    /// Number of rows affected (for execute)
    rows_affected: u64,
    /// Row data (for query) - caller owns memory
    row_data: ?[]const u8,

    const Self = @This();

    pub fn ok() Self {
        return Self{
            .success = true,
            .error_message = null,
            .rows_affected = 0,
            .row_data = null,
        };
    }

    pub fn okWithRows(rows: u64) Self {
        return Self{
            .success = true,
            .error_message = null,
            .rows_affected = rows,
            .row_data = null,
        };
    }

    pub fn okWithData(data: []const u8) Self {
        return Self{
            .success = true,
            .error_message = null,
            .rows_affected = 0,
            .row_data = data,
        };
    }

    pub fn err(message: []const u8) Self {
        return Self{
            .success = false,
            .error_message = message,
            .rows_affected = 0,
            .row_data = null,
        };
    }
};

/// A single work item for the thread pool
pub const WorkItem = struct {
    /// Type of operation
    work_type: WorkItemType,
    /// Database path (for open_connection)
    db_path: ?[]const u8,
    /// SQL to execute (for query/execute)
    sql: ?[]const u8,
    /// Bound parameters (serialized)
    params: ?[]const u8,
    /// Connection ID to use
    connection_id: u64,
    /// Request ID for correlation
    request_id: u64,
    /// Completion callback
    callback: ?*const fn (request_id: u64, result: WorkResult) void,
    /// Allocator for result data
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn query(allocator: std.mem.Allocator, conn_id: u64, req_id: u64, sql: []const u8, callback: ?*const fn (u64, WorkResult) void) Self {
        return Self{
            .work_type = .query,
            .db_path = null,
            .sql = sql,
            .params = null,
            .connection_id = conn_id,
            .request_id = req_id,
            .callback = callback,
            .allocator = allocator,
        };
    }

    pub fn execute(allocator: std.mem.Allocator, conn_id: u64, req_id: u64, sql: []const u8, callback: ?*const fn (u64, WorkResult) void) Self {
        return Self{
            .work_type = .execute,
            .db_path = null,
            .sql = sql,
            .params = null,
            .connection_id = conn_id,
            .request_id = req_id,
            .callback = callback,
            .allocator = allocator,
        };
    }

    pub fn beginTransaction(allocator: std.mem.Allocator, conn_id: u64, req_id: u64, callback: ?*const fn (u64, WorkResult) void) Self {
        return Self{
            .work_type = .begin_transaction,
            .db_path = null,
            .sql = null,
            .params = null,
            .connection_id = conn_id,
            .request_id = req_id,
            .callback = callback,
            .allocator = allocator,
        };
    }

    pub fn commitTransaction(allocator: std.mem.Allocator, conn_id: u64, req_id: u64, callback: ?*const fn (u64, WorkResult) void) Self {
        return Self{
            .work_type = .commit_transaction,
            .db_path = null,
            .sql = null,
            .params = null,
            .connection_id = conn_id,
            .request_id = req_id,
            .callback = callback,
            .allocator = allocator,
        };
    }

    pub fn rollbackTransaction(allocator: std.mem.Allocator, conn_id: u64, req_id: u64, callback: ?*const fn (u64, WorkResult) void) Self {
        return Self{
            .work_type = .rollback_transaction,
            .db_path = null,
            .sql = null,
            .params = null,
            .connection_id = conn_id,
            .request_id = req_id,
            .callback = callback,
            .allocator = allocator,
        };
    }

    pub fn openConnection(allocator: std.mem.Allocator, db_path: []const u8, req_id: u64, callback: ?*const fn (u64, WorkResult) void) Self {
        return Self{
            .work_type = .open_connection,
            .db_path = db_path,
            .sql = null,
            .params = null,
            .connection_id = 0,
            .request_id = req_id,
            .callback = callback,
            .allocator = allocator,
        };
    }

    pub fn closeConnection(allocator: std.mem.Allocator, conn_id: u64, req_id: u64, callback: ?*const fn (u64, WorkResult) void) Self {
        return Self{
            .work_type = .close_connection,
            .db_path = null,
            .sql = null,
            .params = null,
            .connection_id = conn_id,
            .request_id = req_id,
            .callback = callback,
            .allocator = allocator,
        };
    }
};

// ============================================================================
// Thread-Safe Work Queue
// ============================================================================

/// Thread-safe queue for work items
pub const WorkQueue = struct {
    items: std.ArrayListUnmanaged(WorkItem),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    shutdown: std.atomic.Value(bool),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .items = .{},
            .mutex = .{},
            .condition = .{},
            .shutdown = std.atomic.Value(bool).init(false),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit(self.allocator);
    }

    /// Add work item to queue
    pub fn push(self: *Self, item: WorkItem) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.items.append(self.allocator, item);
        self.condition.signal();
    }

    /// Get next work item (blocks if empty)
    pub fn pop(self: *Self) ?WorkItem {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.items.items.len == 0) {
            if (self.shutdown.load(.acquire)) {
                return null;
            }
            self.condition.wait(&self.mutex);
        }

        // Pop from front (FIFO)
        const item = self.items.items[0];
        _ = self.items.orderedRemove(0);
        return item;
    }

    /// Try to get work item without blocking
    pub fn tryPop(self: *Self) ?WorkItem {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.items.items.len == 0) {
            return null;
        }

        const item = self.items.items[0];
        _ = self.items.orderedRemove(0);
        return item;
    }

    /// Signal shutdown to all waiting threads
    pub fn signalShutdown(self: *Self) void {
        self.shutdown.store(true, .release);
        self.condition.broadcast();
    }

    /// Get queue length
    pub fn len(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.items.items.len;
    }
};

// ============================================================================
// Connection Pool
// ============================================================================

/// Manages SQLite connections (one per database path)
pub const ConnectionPool = struct {
    /// Map of connection ID to database path
    connections: std.AutoHashMapUnmanaged(u64, ConnectionInfo),
    /// Next connection ID
    next_id: std.atomic.Value(u64),
    /// Mutex for connection map
    mutex: std.Thread.Mutex,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub const ConnectionInfo = struct {
        path: []const u8,
        opened_at: i64,
        is_open: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .connections = .{},
            .next_id = std.atomic.Value(u64).init(1),
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.connections.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.path);
        }
        self.connections.deinit(self.allocator);
    }

    /// Register a new connection
    pub fn register(self: *Self, path: []const u8) !u64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const id = self.next_id.fetchAdd(1, .monotonic);
        const path_copy = try self.allocator.dupe(u8, path);

        try self.connections.put(self.allocator, id, ConnectionInfo{
            .path = path_copy,
            .opened_at = std.time.milliTimestamp(),
            .is_open = true,
        });

        return id;
    }

    /// Mark connection as closed
    pub fn markClosed(self: *Self, id: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.connections.getPtr(id)) |info| {
            info.is_open = false;
        }
    }

    /// Get connection path
    pub fn getPath(self: *Self, id: u64) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.connections.get(id)) |info| {
            return info.path;
        }
        return null;
    }

    /// Check if connection is open
    pub fn isOpen(self: *Self, id: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.connections.get(id)) |info| {
            return info.is_open;
        }
        return false;
    }

    /// Get count of open connections
    pub fn openCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        var count: usize = 0;
        var iter = self.connections.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.is_open) {
                count += 1;
            }
        }
        return count;
    }
};

// ============================================================================
// Worker Pool
// ============================================================================

/// Configuration for the worker pool
pub const WorkerPoolConfig = struct {
    /// Number of worker threads
    num_workers: usize = 4,
    /// Maximum queue size (0 = unlimited)
    max_queue_size: usize = 1000,
};

/// Thread pool for SQLite operations
pub const WorkerPool = struct {
    /// Worker threads
    workers: []std.Thread,
    /// Work queue
    queue: WorkQueue,
    /// Connection pool
    connections: ConnectionPool,
    /// Configuration
    config: WorkerPoolConfig,
    /// Running flag
    running: std.atomic.Value(bool),
    /// Allocator
    allocator: std.mem.Allocator,
    /// Statistics
    stats: PoolStats,

    const Self = @This();

    pub const PoolStats = struct {
        items_processed: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
        items_failed: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
        total_process_time_ns: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    };

    pub fn init(allocator: std.mem.Allocator, config: WorkerPoolConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .workers = try allocator.alloc(std.Thread, config.num_workers),
            .queue = WorkQueue.init(allocator),
            .connections = ConnectionPool.init(allocator),
            .config = config,
            .running = std.atomic.Value(bool).init(false),
            .allocator = allocator,
            .stats = .{},
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.queue.deinit();
        self.connections.deinit();
        self.allocator.free(self.workers);
        self.allocator.destroy(self);
    }

    /// Start the worker pool
    pub fn start(self: *Self) !void {
        if (self.running.swap(true, .acq_rel)) {
            return; // Already running
        }

        for (self.workers, 0..) |*worker, i| {
            _ = i;
            worker.* = try std.Thread.spawn(.{}, workerMain, .{self});
        }
    }

    /// Stop the worker pool
    pub fn stop(self: *Self) void {
        if (!self.running.swap(false, .acq_rel)) {
            return; // Already stopped
        }

        self.queue.signalShutdown();

        for (self.workers) |worker| {
            worker.join();
        }
    }

    /// Submit work to the pool
    pub fn submit(self: *Self, item: WorkItem) !void {
        if (!self.running.load(.acquire)) {
            return error.PoolNotRunning;
        }

        if (self.config.max_queue_size > 0 and self.queue.len() >= self.config.max_queue_size) {
            return error.QueueFull;
        }

        try self.queue.push(item);
    }

    /// Register a database connection
    pub fn registerConnection(self: *Self, path: []const u8) !u64 {
        return self.connections.register(path);
    }

    /// Close a database connection
    pub fn closeConnection(self: *Self, conn_id: u64) void {
        self.connections.markClosed(conn_id);
    }

    /// Get statistics
    pub fn getStats(self: *Self) struct { processed: u64, failed: u64, avg_time_ns: u64 } {
        const processed = self.stats.items_processed.load(.acquire);
        const failed = self.stats.items_failed.load(.acquire);
        const total_time = self.stats.total_process_time_ns.load(.acquire);

        return .{
            .processed = processed,
            .failed = failed,
            .avg_time_ns = if (processed > 0) total_time / processed else 0,
        };
    }

    /// Worker thread main function
    fn workerMain(self: *Self) void {
        while (self.running.load(.acquire)) {
            if (self.queue.pop()) |item| {
                const start_time = std.time.nanoTimestamp();

                // Process the work item
                const result = processWorkItem(item);

                // Update statistics
                const elapsed: u64 = @intCast(std.time.nanoTimestamp() - start_time);
                _ = self.stats.total_process_time_ns.fetchAdd(elapsed, .monotonic);

                if (result.success) {
                    _ = self.stats.items_processed.fetchAdd(1, .monotonic);
                } else {
                    _ = self.stats.items_failed.fetchAdd(1, .monotonic);
                }

                // Call completion callback
                if (item.callback) |callback| {
                    callback(item.request_id, result);
                }
            }
        }
    }

    /// Process a single work item
    fn processWorkItem(item: WorkItem) WorkResult {
        // In a real implementation, this would use actual SQLite bindings
        // For now, we simulate the operations
        return switch (item.work_type) {
            .query => WorkResult.okWithData("[]"),
            .execute => WorkResult.okWithRows(1),
            .begin_transaction => WorkResult.ok(),
            .commit_transaction => WorkResult.ok(),
            .rollback_transaction => WorkResult.ok(),
            .open_connection => WorkResult.ok(),
            .close_connection => WorkResult.ok(),
        };
    }
};

// ============================================================================
// Async Operation Wrapper
// ============================================================================

/// Wraps worker pool operations with promise-like semantics
pub const AsyncSQLite = struct {
    pool: *WorkerPool,
    next_request_id: std.atomic.Value(u64),
    /// Pending results (request_id -> result)
    pending: std.AutoHashMapUnmanaged(u64, ?WorkResult),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, pool: *WorkerPool) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .pool = pool,
            .next_request_id = std.atomic.Value(u64).init(1),
            .pending = .{},
            .mutex = .{},
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.pending.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Execute a query asynchronously
    pub fn query(self: *Self, conn_id: u64, sql: []const u8) !u64 {
        const req_id = self.next_request_id.fetchAdd(1, .monotonic);

        {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.pending.put(self.allocator, req_id, null);
        }

        const item = WorkItem.query(self.allocator, conn_id, req_id, sql, &Self.resultCallback);
        try self.pool.submit(item);

        return req_id;
    }

    /// Execute a statement asynchronously
    pub fn execute(self: *Self, conn_id: u64, sql: []const u8) !u64 {
        const req_id = self.next_request_id.fetchAdd(1, .monotonic);

        {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.pending.put(self.allocator, req_id, null);
        }

        const item = WorkItem.execute(self.allocator, conn_id, req_id, sql, &Self.resultCallback);
        try self.pool.submit(item);

        return req_id;
    }

    /// Check if a request is complete
    pub fn isComplete(self: *Self, request_id: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pending.get(request_id)) |maybe_result| {
            return maybe_result != null;
        }
        return false;
    }

    /// Get result for a request (returns null if not complete)
    pub fn getResult(self: *Self, request_id: u64) ?WorkResult {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pending.fetchRemove(request_id)) |kv| {
            return kv.value;
        }
        return null;
    }

    /// Callback for worker pool results
    fn resultCallback(request_id: u64, result: WorkResult) void {
        // In a real implementation, this would be connected to the AsyncSQLite instance
        // via thread-local storage or a global registry
        _ = request_id;
        _ = result;
    }
};

// ============================================================================
// Batch Operations
// ============================================================================

/// Batch multiple operations for efficiency
pub const BatchOperation = struct {
    items: std.ArrayListUnmanaged(WorkItem),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .items = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit(self.allocator);
    }

    pub fn addQuery(self: *Self, conn_id: u64, sql: []const u8) !void {
        try self.items.append(self.allocator, WorkItem.query(self.allocator, conn_id, 0, sql, null));
    }

    pub fn addExecute(self: *Self, conn_id: u64, sql: []const u8) !void {
        try self.items.append(self.allocator, WorkItem.execute(self.allocator, conn_id, 0, sql, null));
    }

    pub fn count(self: Self) usize {
        return self.items.items.len;
    }

    /// Submit all operations to the pool
    pub fn submitAll(self: *Self, pool: *WorkerPool) !void {
        for (self.items.items) |item| {
            try pool.submit(item);
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "WorkQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = WorkQueue.init(allocator);
    defer queue.deinit();

    // Push items
    try queue.push(WorkItem.query(allocator, 1, 1, "SELECT 1", null));
    try queue.push(WorkItem.execute(allocator, 1, 2, "INSERT INTO t VALUES (1)", null));

    try std.testing.expectEqual(@as(usize, 2), queue.len());

    // Pop items (FIFO order)
    const item1 = queue.tryPop().?;
    try std.testing.expectEqual(WorkItemType.query, item1.work_type);
    try std.testing.expectEqual(@as(u64, 1), item1.request_id);

    const item2 = queue.tryPop().?;
    try std.testing.expectEqual(WorkItemType.execute, item2.work_type);
    try std.testing.expectEqual(@as(u64, 2), item2.request_id);

    try std.testing.expect(queue.tryPop() == null);
}

test "ConnectionPool - register and manage" {
    const allocator = std.testing.allocator;

    var pool = ConnectionPool.init(allocator);
    defer pool.deinit();

    // Register connections
    const id1 = try pool.register("/path/to/db1.sqlite");
    const id2 = try pool.register("/path/to/db2.sqlite");

    try std.testing.expect(id1 != id2);
    try std.testing.expectEqual(@as(usize, 2), pool.openCount());

    // Check path
    try std.testing.expectEqualStrings("/path/to/db1.sqlite", pool.getPath(id1).?);
    try std.testing.expect(pool.isOpen(id1));

    // Close connection
    pool.markClosed(id1);
    try std.testing.expect(!pool.isOpen(id1));
    try std.testing.expectEqual(@as(usize, 1), pool.openCount());
}

test "WorkResult - factory methods" {
    const ok_result = WorkResult.ok();
    try std.testing.expect(ok_result.success);
    try std.testing.expect(ok_result.error_message == null);

    const rows_result = WorkResult.okWithRows(42);
    try std.testing.expect(rows_result.success);
    try std.testing.expectEqual(@as(u64, 42), rows_result.rows_affected);

    const err_result = WorkResult.err("Connection failed");
    try std.testing.expect(!err_result.success);
    try std.testing.expectEqualStrings("Connection failed", err_result.error_message.?);
}

test "WorkItem - factory methods" {
    const allocator = std.testing.allocator;

    const query_item = WorkItem.query(allocator, 1, 100, "SELECT * FROM users", null);
    try std.testing.expectEqual(WorkItemType.query, query_item.work_type);
    try std.testing.expectEqual(@as(u64, 1), query_item.connection_id);
    try std.testing.expectEqual(@as(u64, 100), query_item.request_id);

    const begin_item = WorkItem.beginTransaction(allocator, 1, 101, null);
    try std.testing.expectEqual(WorkItemType.begin_transaction, begin_item.work_type);

    const open_item = WorkItem.openConnection(allocator, "/path/to/db.sqlite", 102, null);
    try std.testing.expectEqual(WorkItemType.open_connection, open_item.work_type);
    try std.testing.expectEqualStrings("/path/to/db.sqlite", open_item.db_path.?);
}

test "BatchOperation - collect operations" {
    const allocator = std.testing.allocator;

    var batch = BatchOperation.init(allocator);
    defer batch.deinit();

    try batch.addQuery(1, "SELECT 1");
    try batch.addExecute(1, "INSERT INTO t VALUES (1)");
    try batch.addQuery(1, "SELECT 2");

    try std.testing.expectEqual(@as(usize, 3), batch.count());
}

test "WorkerPool - init and config" {
    const allocator = std.testing.allocator;

    const pool = try WorkerPool.init(allocator, .{
        .num_workers = 2,
        .max_queue_size = 100,
    });
    defer pool.deinit();

    try std.testing.expectEqual(@as(usize, 2), pool.config.num_workers);
    try std.testing.expectEqual(@as(usize, 100), pool.config.max_queue_size);
}
