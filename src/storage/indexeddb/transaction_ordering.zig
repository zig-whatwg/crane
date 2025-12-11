//! Transaction Ordering via Event Loop
//!
//! Ensures IndexedDB transaction callbacks execute in the correct order
//! as specified by the W3C IndexedDB 3.0 standard. Transaction operations
//! are queued and dispatched through the event loop to maintain proper
//! ordering guarantees.
//!
//! ## Ordering Rules
//!
//! Per the spec, transactions have these ordering requirements:
//!
//! 1. **Request order within transaction**: Requests execute in order they
//!    were issued within a transaction
//! 2. **Transaction activation**: A transaction is "active" during event
//!    callbacks but becomes "inactive" between callbacks
//! 3. **Transaction commit**: Auto-commits when all requests complete and
//!    no new requests are pending
//! 4. **Versionchange exclusivity**: versionchange transactions have
//!    exclusive access to the database
//!
//! ## Event Loop Integration
//!
//! ```
//! IDBRequest → Queue Request → Event Loop Task → Process Request
//!                                    │
//!                                    ├── Fire "success" event
//!                                    ├── Fire "error" event
//!                                    └── Transaction state update
//! ```
//!
//! ## Spec References
//!
//! - Transaction lifetime: https://w3c.github.io/IndexedDB/#transaction-lifetime
//! - Request processing: https://w3c.github.io/IndexedDB/#request-api

const std = @import("std");

// ============================================================================
// Transaction Request
// ============================================================================

/// State of a queued request
pub const RequestState = enum {
    /// Request is queued but not yet processed
    pending,
    /// Request is currently being processed
    processing,
    /// Request completed successfully
    done,
    /// Request failed with error
    failed,
};

/// A request queued within a transaction
pub const TransactionRequest = struct {
    /// Unique request ID
    id: u64,
    /// Transaction this request belongs to
    transaction_id: u64,
    /// Current state
    state: RequestState,
    /// Operation type name (for debugging)
    operation: []const u8,
    /// Created timestamp
    created_at: i64,
    /// Processed timestamp
    processed_at: ?i64,
    /// Error message if failed
    error_message: ?[]const u8,

    const Self = @This();

    pub fn init(id: u64, transaction_id: u64, operation: []const u8) Self {
        return Self{
            .id = id,
            .transaction_id = transaction_id,
            .state = .pending,
            .operation = operation,
            .created_at = std.time.milliTimestamp(),
            .processed_at = null,
            .error_message = null,
        };
    }

    pub fn markProcessing(self: *Self) void {
        self.state = .processing;
    }

    pub fn markDone(self: *Self) void {
        self.state = .done;
        self.processed_at = std.time.milliTimestamp();
    }

    pub fn markFailed(self: *Self, err: []const u8) void {
        self.state = .failed;
        self.processed_at = std.time.milliTimestamp();
        self.error_message = err;
    }

    pub fn isComplete(self: Self) bool {
        return self.state == .done or self.state == .failed;
    }
};

// ============================================================================
// Transaction Queue
// ============================================================================

/// Manages request ordering within a transaction
pub const TransactionRequestQueue = struct {
    /// Transaction ID
    transaction_id: u64,
    /// Requests in order
    requests: std.ArrayListUnmanaged(TransactionRequest),
    /// Index of next request to process
    next_index: usize,
    /// Whether transaction is active (can accept new requests)
    is_active: bool,
    /// Whether transaction is committing
    is_committing: bool,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, transaction_id: u64) Self {
        return Self{
            .transaction_id = transaction_id,
            .requests = .{},
            .next_index = 0,
            .is_active = true,
            .is_committing = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.requests.deinit(self.allocator);
    }

    /// Queue a new request
    pub fn enqueue(self: *Self, id: u64, operation: []const u8) !void {
        if (!self.is_active) {
            return error.TransactionInactive;
        }
        if (self.is_committing) {
            return error.TransactionCommitting;
        }

        try self.requests.append(self.allocator, TransactionRequest.init(id, self.transaction_id, operation));
    }

    /// Get next pending request
    pub fn nextPending(self: *Self) ?*TransactionRequest {
        while (self.next_index < self.requests.items.len) {
            const req = &self.requests.items[self.next_index];
            if (req.state == .pending) {
                return req;
            }
            self.next_index += 1;
        }
        return null;
    }

    /// Check if all requests are complete
    pub fn allComplete(self: Self) bool {
        for (self.requests.items) |req| {
            if (!req.isComplete()) {
                return false;
            }
        }
        return true;
    }

    /// Get request by ID
    pub fn getRequest(self: *Self, id: u64) ?*TransactionRequest {
        for (self.requests.items) |*req| {
            if (req.id == id) {
                return req;
            }
        }
        return null;
    }

    /// Count pending requests
    pub fn pendingCount(self: Self) usize {
        var count: usize = 0;
        for (self.requests.items) |req| {
            if (req.state == .pending) {
                count += 1;
            }
        }
        return count;
    }

    /// Mark transaction as inactive
    pub fn deactivate(self: *Self) void {
        self.is_active = false;
    }

    /// Mark transaction as active
    pub fn activate(self: *Self) void {
        self.is_active = true;
    }

    /// Start commit process
    pub fn startCommit(self: *Self) void {
        self.is_committing = true;
        self.is_active = false;
    }
};

// ============================================================================
// Event Loop Task Types
// ============================================================================

/// Type of event loop task for IndexedDB
pub const IDBTaskType = enum {
    /// Process next request in transaction
    process_request,
    /// Fire success event
    fire_success,
    /// Fire error event
    fire_error,
    /// Fire complete event (transaction done)
    fire_complete,
    /// Fire abort event (transaction aborted)
    fire_abort,
    /// Fire upgradeneeded event
    fire_upgradeneeded,
    /// Fire blocked event
    fire_blocked,
    /// Check transaction commit
    check_commit,
};

/// A task to be executed by the event loop
pub const IDBTask = struct {
    /// Task type
    task_type: IDBTaskType,
    /// Transaction ID
    transaction_id: u64,
    /// Request ID (if applicable)
    request_id: ?u64,
    /// Additional data (event-specific)
    /// KEEP: anyopaque is intentional - task data is polymorphic and varies
    /// by task_type (e.g., request results, error info, etc.). Type erasure
    /// allows the task queue to handle different task types uniformly.
    data: ?*anyopaque,
    /// Priority (lower = higher priority)
    priority: u8,
    /// Created timestamp
    created_at: i64,

    const Self = @This();

    pub fn processRequest(txn_id: u64, req_id: u64) Self {
        return Self{
            .task_type = .process_request,
            .transaction_id = txn_id,
            .request_id = req_id,
            .data = null,
            .priority = 10,
            .created_at = std.time.milliTimestamp(),
        };
    }

    pub fn fireSuccess(txn_id: u64, req_id: u64) Self {
        return Self{
            .task_type = .fire_success,
            .transaction_id = txn_id,
            .request_id = req_id,
            .data = null,
            .priority = 10,
            .created_at = std.time.milliTimestamp(),
        };
    }

    pub fn fireError(txn_id: u64, req_id: u64) Self {
        return Self{
            .task_type = .fire_error,
            .transaction_id = txn_id,
            .request_id = req_id,
            .data = null,
            .priority = 10,
            .created_at = std.time.milliTimestamp(),
        };
    }

    pub fn fireComplete(txn_id: u64) Self {
        return Self{
            .task_type = .fire_complete,
            .transaction_id = txn_id,
            .request_id = null,
            .data = null,
            .priority = 5, // Higher priority than regular events
            .created_at = std.time.milliTimestamp(),
        };
    }

    pub fn fireAbort(txn_id: u64) Self {
        return Self{
            .task_type = .fire_abort,
            .transaction_id = txn_id,
            .request_id = null,
            .data = null,
            .priority = 5,
            .created_at = std.time.milliTimestamp(),
        };
    }

    pub fn fireUpgradeneeded(txn_id: u64) Self {
        return Self{
            .task_type = .fire_upgradeneeded,
            .transaction_id = txn_id,
            .request_id = null,
            .data = null,
            .priority = 1, // Highest priority
            .created_at = std.time.milliTimestamp(),
        };
    }

    pub fn fireBlocked(txn_id: u64) Self {
        return Self{
            .task_type = .fire_blocked,
            .transaction_id = txn_id,
            .request_id = null,
            .data = null,
            .priority = 2,
            .created_at = std.time.milliTimestamp(),
        };
    }

    pub fn checkCommit(txn_id: u64) Self {
        return Self{
            .task_type = .check_commit,
            .transaction_id = txn_id,
            .request_id = null,
            .data = null,
            .priority = 20, // Lower priority - check after other events
            .created_at = std.time.milliTimestamp(),
        };
    }
};

// ============================================================================
// Transaction Scheduler
// ============================================================================

/// Schedules transaction tasks for execution via event loop
pub const TransactionScheduler = struct {
    /// Pending tasks ordered by priority then creation time
    tasks: std.ArrayListUnmanaged(IDBTask),
    /// Transaction queues by ID
    transaction_queues: std.AutoHashMapUnmanaged(u64, TransactionRequestQueue),
    /// Next task ID
    next_task_id: u64,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .tasks = .{},
            .transaction_queues = .{},
            .next_task_id = 1,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.transaction_queues.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.transaction_queues.deinit(self.allocator);
        self.tasks.deinit(self.allocator);
    }

    /// Register a new transaction
    pub fn registerTransaction(self: *Self, transaction_id: u64) !void {
        try self.transaction_queues.put(self.allocator, transaction_id, TransactionRequestQueue.init(self.allocator, transaction_id));
    }

    /// Unregister a transaction
    pub fn unregisterTransaction(self: *Self, transaction_id: u64) void {
        if (self.transaction_queues.fetchRemove(transaction_id)) |kv| {
            var queue = kv.value;
            queue.deinit();
        }
    }

    /// Queue a request in a transaction
    pub fn queueRequest(self: *Self, transaction_id: u64, request_id: u64, operation: []const u8) !void {
        const queue = self.transaction_queues.getPtr(transaction_id) orelse {
            return error.TransactionNotFound;
        };

        try queue.enqueue(request_id, operation);

        // Schedule processing
        try self.scheduleTask(IDBTask.processRequest(transaction_id, request_id));
    }

    /// Schedule a task
    pub fn scheduleTask(self: *Self, task: IDBTask) !void {
        // Insert in priority order
        var insert_idx: usize = self.tasks.items.len;
        for (self.tasks.items, 0..) |existing, i| {
            if (task.priority < existing.priority or
                (task.priority == existing.priority and task.created_at < existing.created_at))
            {
                insert_idx = i;
                break;
            }
        }

        try self.tasks.insert(self.allocator, insert_idx, task);
    }

    /// Get next task to execute
    pub fn nextTask(self: *Self) ?IDBTask {
        if (self.tasks.items.len == 0) {
            return null;
        }
        return self.tasks.orderedRemove(0);
    }

    /// Peek at next task without removing
    pub fn peekTask(self: Self) ?IDBTask {
        if (self.tasks.items.len == 0) {
            return null;
        }
        return self.tasks.items[0];
    }

    /// Get transaction queue
    pub fn getQueue(self: *Self, transaction_id: u64) ?*TransactionRequestQueue {
        return self.transaction_queues.getPtr(transaction_id);
    }

    /// Check if scheduler has pending tasks
    pub fn hasPendingTasks(self: Self) bool {
        return self.tasks.items.len > 0;
    }

    /// Count pending tasks
    pub fn pendingTaskCount(self: Self) usize {
        return self.tasks.items.len;
    }

    /// Schedule commit check after request processing
    pub fn scheduleCommitCheck(self: *Self, transaction_id: u64) !void {
        try self.scheduleTask(IDBTask.checkCommit(transaction_id));
    }
};

// ============================================================================
// Versionchange Coordinator
// ============================================================================

/// Coordinates versionchange transactions (exclusive access)
pub const VersionchangeCoordinator = struct {
    /// Currently active versionchange transaction (if any)
    active_versionchange: ?u64,
    /// Blocked transactions waiting for versionchange
    blocked_transactions: std.ArrayListUnmanaged(u64),
    /// Connections that need to close for versionchange
    pending_closes: std.ArrayListUnmanaged(u64),
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .active_versionchange = null,
            .blocked_transactions = .{},
            .pending_closes = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.blocked_transactions.deinit(self.allocator);
        self.pending_closes.deinit(self.allocator);
    }

    /// Request versionchange transaction
    pub fn requestVersionchange(self: *Self, transaction_id: u64) !VersionchangeResult {
        if (self.active_versionchange != null) {
            // Another versionchange is active, block this one
            try self.blocked_transactions.append(self.allocator, transaction_id);
            return .blocked;
        }

        self.active_versionchange = transaction_id;
        return .started;
    }

    /// Complete versionchange transaction
    pub fn completeVersionchange(self: *Self, transaction_id: u64) ?u64 {
        if (self.active_versionchange == transaction_id) {
            self.active_versionchange = null;

            // Unblock next waiting transaction
            if (self.blocked_transactions.items.len > 0) {
                const next_txn = self.blocked_transactions.orderedRemove(0);
                self.active_versionchange = next_txn;
                return next_txn;
            }
        }
        return null;
    }

    /// Register connection that needs to close
    pub fn addPendingClose(self: *Self, connection_id: u64) !void {
        try self.pending_closes.append(self.allocator, connection_id);
    }

    /// Connection closed, remove from pending
    pub fn connectionClosed(self: *Self, connection_id: u64) void {
        for (self.pending_closes.items, 0..) |id, i| {
            if (id == connection_id) {
                _ = self.pending_closes.orderedRemove(i);
                break;
            }
        }
    }

    /// Check if all pending closes are done
    pub fn allConnectionsClosed(self: Self) bool {
        return self.pending_closes.items.len == 0;
    }

    /// Check if versionchange can proceed
    pub fn canProceed(self: Self) bool {
        return self.active_versionchange != null and self.allConnectionsClosed();
    }

    pub const VersionchangeResult = enum {
        started,
        blocked,
    };
};

// ============================================================================
// Transaction Ordering Manager
// ============================================================================

/// High-level manager for transaction ordering
pub const TransactionOrderingManager = struct {
    scheduler: TransactionScheduler,
    versionchange_coord: VersionchangeCoordinator,
    /// Next request ID
    next_request_id: u64,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .scheduler = TransactionScheduler.init(allocator),
            .versionchange_coord = VersionchangeCoordinator.init(allocator),
            .next_request_id = 1,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.scheduler.deinit();
        self.versionchange_coord.deinit();
    }

    /// Start a new transaction
    pub fn startTransaction(self: *Self, transaction_id: u64, is_versionchange: bool) !void {
        try self.scheduler.registerTransaction(transaction_id);

        if (is_versionchange) {
            const result = try self.versionchange_coord.requestVersionchange(transaction_id);
            if (result == .blocked) {
                try self.scheduler.scheduleTask(IDBTask.fireBlocked(transaction_id));
            }
        }
    }

    /// Queue a request
    pub fn queueRequest(self: *Self, transaction_id: u64, operation: []const u8) !u64 {
        const request_id = self.next_request_id;
        self.next_request_id += 1;

        try self.scheduler.queueRequest(transaction_id, request_id, operation);
        return request_id;
    }

    /// Complete a request
    pub fn completeRequest(self: *Self, transaction_id: u64, request_id: u64, success: bool) !void {
        if (self.scheduler.getQueue(transaction_id)) |queue| {
            if (queue.getRequest(request_id)) |req| {
                if (success) {
                    req.markDone();
                    try self.scheduler.scheduleTask(IDBTask.fireSuccess(transaction_id, request_id));
                } else {
                    req.markFailed("Operation failed");
                    try self.scheduler.scheduleTask(IDBTask.fireError(transaction_id, request_id));
                }

                // Schedule commit check
                try self.scheduler.scheduleCommitCheck(transaction_id);
            }
        }
    }

    /// End a transaction
    pub fn endTransaction(self: *Self, transaction_id: u64, committed: bool, is_versionchange: bool) !void {
        if (committed) {
            try self.scheduler.scheduleTask(IDBTask.fireComplete(transaction_id));
        } else {
            try self.scheduler.scheduleTask(IDBTask.fireAbort(transaction_id));
        }

        if (is_versionchange) {
            if (self.versionchange_coord.completeVersionchange(transaction_id)) |next_txn| {
                // Unblocked transaction can now proceed
                try self.scheduler.scheduleTask(IDBTask.fireUpgradeneeded(next_txn));
            }
        }

        self.scheduler.unregisterTransaction(transaction_id);
    }

    /// Process next event loop task
    pub fn processNextTask(self: *Self) ?IDBTask {
        return self.scheduler.nextTask();
    }

    /// Check if there are pending tasks
    pub fn hasPendingTasks(self: Self) bool {
        return self.scheduler.hasPendingTasks();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TransactionRequest - state transitions" {
    var req = TransactionRequest.init(1, 100, "put");
    try std.testing.expectEqual(RequestState.pending, req.state);
    try std.testing.expect(!req.isComplete());

    req.markProcessing();
    try std.testing.expectEqual(RequestState.processing, req.state);

    req.markDone();
    try std.testing.expectEqual(RequestState.done, req.state);
    try std.testing.expect(req.isComplete());
}

test "TransactionRequestQueue - ordering" {
    const allocator = std.testing.allocator;

    var queue = TransactionRequestQueue.init(allocator, 100);
    defer queue.deinit();

    // Enqueue requests
    try queue.enqueue(1, "put");
    try queue.enqueue(2, "get");
    try queue.enqueue(3, "delete");

    try std.testing.expectEqual(@as(usize, 3), queue.pendingCount());

    // Get in FIFO order
    const req1 = queue.nextPending().?;
    try std.testing.expectEqual(@as(u64, 1), req1.id);
    req1.markDone();

    const req2 = queue.nextPending().?;
    try std.testing.expectEqual(@as(u64, 2), req2.id);
    req2.markDone();

    const req3 = queue.nextPending().?;
    try std.testing.expectEqual(@as(u64, 3), req3.id);
    req3.markDone();

    try std.testing.expect(queue.allComplete());
}

test "TransactionRequestQueue - inactive rejection" {
    const allocator = std.testing.allocator;

    var queue = TransactionRequestQueue.init(allocator, 100);
    defer queue.deinit();

    queue.deactivate();

    const result = queue.enqueue(1, "put");
    try std.testing.expectError(error.TransactionInactive, result);
}

test "IDBTask - priority ordering" {
    const upgrade = IDBTask.fireUpgradeneeded(1);
    const blocked = IDBTask.fireBlocked(1);
    const complete = IDBTask.fireComplete(1);
    const success = IDBTask.fireSuccess(1, 1);
    const commit_check = IDBTask.checkCommit(1);

    // Lower number = higher priority
    try std.testing.expect(upgrade.priority < blocked.priority);
    try std.testing.expect(blocked.priority < complete.priority);
    try std.testing.expect(complete.priority < success.priority);
    try std.testing.expect(success.priority < commit_check.priority);
}

test "TransactionScheduler - task scheduling" {
    const allocator = std.testing.allocator;

    var scheduler = TransactionScheduler.init(allocator);
    defer scheduler.deinit();

    // Register transaction
    try scheduler.registerTransaction(100);

    // Queue requests
    try scheduler.queueRequest(100, 1, "put");
    try scheduler.queueRequest(100, 2, "get");

    try std.testing.expectEqual(@as(usize, 2), scheduler.pendingTaskCount());

    // Tasks come out in order
    const task1 = scheduler.nextTask().?;
    try std.testing.expectEqual(IDBTaskType.process_request, task1.task_type);
    try std.testing.expectEqual(@as(?u64, 1), task1.request_id);

    const task2 = scheduler.nextTask().?;
    try std.testing.expectEqual(@as(?u64, 2), task2.request_id);
}

test "VersionchangeCoordinator - exclusive access" {
    const allocator = std.testing.allocator;

    var coord = VersionchangeCoordinator.init(allocator);
    defer coord.deinit();

    // First versionchange succeeds
    const result1 = try coord.requestVersionchange(100);
    try std.testing.expectEqual(VersionchangeCoordinator.VersionchangeResult.started, result1);

    // Second versionchange is blocked
    const result2 = try coord.requestVersionchange(101);
    try std.testing.expectEqual(VersionchangeCoordinator.VersionchangeResult.blocked, result2);

    // Complete first, unblocks second
    const next = coord.completeVersionchange(100);
    try std.testing.expectEqual(@as(?u64, 101), next);
}

test "TransactionOrderingManager - full workflow" {
    const allocator = std.testing.allocator;

    var mgr = TransactionOrderingManager.init(allocator);
    defer mgr.deinit();

    // Start transaction
    try mgr.startTransaction(100, false);

    // Queue requests
    const req1 = try mgr.queueRequest(100, "put");
    const req2 = try mgr.queueRequest(100, "get");

    try std.testing.expect(mgr.hasPendingTasks());

    // Process tasks
    _ = mgr.processNextTask(); // process_request for req1
    try mgr.completeRequest(100, req1, true);

    _ = mgr.processNextTask(); // fire_success for req1
    _ = mgr.processNextTask(); // check_commit (no commit yet)
    _ = mgr.processNextTask(); // process_request for req2

    try mgr.completeRequest(100, req2, true);

    // End transaction
    try mgr.endTransaction(100, true, false);

    // Should have fire_complete task
    const complete_task = mgr.processNextTask();
    try std.testing.expect(complete_task != null);
    try std.testing.expectEqual(IDBTaskType.fire_complete, complete_task.?.task_type);
}
