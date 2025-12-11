//! IndexedDB Async Operations and Promise Integration
//!
//! Implements asynchronous operation handling for IndexedDB per W3C spec.
//! https://w3c.github.io/IndexedDB/
//!
//! ## Overview
//!
//! IndexedDB operations are asynchronous and return IDBRequest objects.
//! This module provides:
//! 1. Async operation queue management
//! 2. Event loop integration for processing requests
//! 3. Promise-based wrappers for modern async/await usage
//!
//! ## Architecture
//!
//! ```
//! IDBRequest (event-based)
//!     ↓
//! AsyncOperation (internal)
//!     ↓
//! Event Loop Queue
//!     ↓
//! Process & Fire Events
//! ```
//!
//! ## Promise Integration
//!
//! While IDBRequest uses events (onsuccess, onerror), we provide Promise
//! wrappers for cleaner async/await usage:
//!
//! ```javascript
//! // Event-based (traditional)
//! const request = store.get(key);
//! request.onsuccess = () => console.log(request.result);
//!
//! // Promise-based (this module)
//! const result = await store.getAsync(key);
//! ```
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#async-execute

const std = @import("std");
const IDBRequest = @import("request.zig").IDBRequest;
const IDBOpenDBRequest = @import("request.zig").IDBOpenDBRequest;
const IDBTransaction = @import("transaction.zig").IDBTransaction;
const IDBTransactionState = @import("transaction.zig").IDBTransactionState;
const IDBError = @import("errors.zig").IDBError;
const events = @import("events.zig");

/// Type of async operation
pub const OperationType = enum {
    /// Get a value by key
    get,
    /// Get a key
    get_key,
    /// Put a value
    put,
    /// Add a value
    add,
    /// Delete a value
    delete,
    /// Clear all records
    clear,
    /// Count records
    count,
    /// Open cursor
    open_cursor,
    /// Open key cursor
    open_key_cursor,
    /// Get all values
    get_all,
    /// Get all keys
    get_all_keys,
    /// Open database
    open_database,
    /// Delete database
    delete_database,
};

/// An async operation waiting to be processed
pub const AsyncOperation = struct {
    const Self = @This();

    /// The request this operation belongs to
    request: *IDBRequest,

    /// Type of operation
    op_type: OperationType,

    /// Callback to execute the operation
    execute: *const fn (*Self) void,

    /// Optional context for the callback
    /// KEEP: anyopaque is intentional - async operations can carry arbitrary
    /// user-defined context data. This is a generic callback pattern where
    /// the executor function knows the concrete type via comptime dispatch.
    context: ?*anyopaque,

    /// Priority (lower = higher priority)
    priority: u32,

    /// Whether this operation has been processed
    processed: bool,
};

/// Queue for managing async operations
pub const AsyncOperationQueue = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Pending operations
    operations: std.ArrayListUnmanaged(AsyncOperation),

    /// Whether the queue is currently being processed
    processing: bool,

    /// Initialize queue
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .operations = .{},
            .processing = false,
        };
    }

    /// Clean up
    pub fn deinit(self: *Self) void {
        self.operations.deinit(self.allocator);
    }

    /// Add an operation to the queue
    pub fn enqueue(self: *Self, op: AsyncOperation) !void {
        try self.operations.append(self.allocator, op);
    }

    /// Process all pending operations
    /// This simulates the event loop processing IDB operations
    pub fn processAll(self: *Self) void {
        if (self.processing) return; // Prevent re-entry
        self.processing = true;
        defer self.processing = false;

        // Process in order (FIFO)
        for (self.operations.items) |*op| {
            if (!op.processed) {
                op.execute(op);
                op.processed = true;
                op.request.processed_flag = true;
            }
        }

        // Clear processed operations
        self.operations.clearRetainingCapacity();
    }

    /// Process a single operation (for step-by-step execution)
    pub fn processOne(self: *Self) bool {
        for (self.operations.items) |*op| {
            if (!op.processed) {
                op.execute(op);
                op.processed = true;
                op.request.processed_flag = true;
                return true;
            }
        }
        return false;
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const Self) bool {
        for (self.operations.items) |op| {
            if (!op.processed) return false;
        }
        return true;
    }

    /// Get count of pending operations
    pub fn pendingCount(self: *const Self) usize {
        var count: usize = 0;
        for (self.operations.items) |op| {
            if (!op.processed) count += 1;
        }
        return count;
    }
};

// ============================================================================
// Promise Wrappers
// ============================================================================

/// Promise-like wrapper for IDBRequest
/// Provides then/catch interface for async/await style code
pub const IDBPromise = struct {
    const Self = @This();

    /// The underlying request
    request: *IDBRequest,

    /// Fulfillment callback
    on_fulfilled: ?*const fn (*IDBRequest) void,

    /// Rejection callback
    on_rejected: ?*const fn (*IDBRequest, IDBError) void,

    /// Create promise from request
    pub fn fromRequest(request: *IDBRequest) Self {
        return Self{
            .request = request,
            .on_fulfilled = null,
            .on_rejected = null,
        };
    }

    /// Attach fulfillment handler
    pub fn then(self: *Self, handler: *const fn (*IDBRequest) void) *Self {
        self.on_fulfilled = handler;

        // If already done, call immediately (simulating microtask)
        if (self.request.done_flag and self.request.err == null) {
            handler(self.request);
        }

        return self;
    }

    /// Attach rejection handler
    pub fn catch_(self: *Self, handler: *const fn (*IDBRequest, IDBError) void) *Self {
        self.on_rejected = handler;

        // If already done with error, call immediately
        if (self.request.done_flag) {
            if (self.request.err) |err| {
                handler(self.request, err);
            }
        }

        return self;
    }

    /// Check if settled
    pub fn isSettled(self: *const Self) bool {
        return self.request.done_flag;
    }

    /// Check if fulfilled
    pub fn isFulfilled(self: *const Self) bool {
        return self.request.done_flag and self.request.err == null;
    }

    /// Check if rejected
    pub fn isRejected(self: *const Self) bool {
        return self.request.done_flag and self.request.err != null;
    }
};

// ============================================================================
// Request Processing Helpers
// ============================================================================

/// Process a request with success result
pub fn resolveRequest(request: *IDBRequest, result: @import("request.zig").RequestResult) void {
    request.setResult(result);
    _ = events.fireSuccessEvent(request);
}

/// Process a request with error
pub fn rejectRequest(request: *IDBRequest, err: IDBError) void {
    request.setError(err);
    _ = events.fireErrorEvent(request);
}

/// Create operation executor for get
/// KEEP: anyopaque in get_fn parameter is intentional - this is a generic
/// executor factory that creates type-erased operation handlers. The actual
/// type is known at comptime when the function is instantiated.
pub fn createGetExecutor(comptime get_fn: fn (*anyopaque) IDBError!@import("request.zig").RequestResult) *const fn (*AsyncOperation) void {
    return struct {
        fn execute(op: *AsyncOperation) void {
            const ctx = op.context orelse {
                rejectRequest(op.request, IDBError.InvalidStateError);
                return;
            };

            if (get_fn(ctx)) |result| {
                resolveRequest(op.request, result);
            } else |err| {
                rejectRequest(op.request, err);
            }
        }
    }.execute;
}

// ============================================================================
// Database Task Queue (per-spec)
// ============================================================================

/// A database task to be queued
pub const DatabaseTask = struct {
    const Self = @This();

    /// Task callback
    callback: *const fn (*Self) void,

    /// Context
    /// KEEP: anyopaque is intentional - database tasks can carry arbitrary
    /// user-defined context data for async task processing.
    context: ?*anyopaque,

    /// Associated database (if any)
    database_id: ?u64,
};

/// Queue database tasks per spec
/// "queue a database task" algorithm
pub const DatabaseTaskQueue = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    tasks: std.ArrayListUnmanaged(DatabaseTask),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .tasks = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.tasks.deinit(self.allocator);
    }

    /// Queue a database task
    pub fn queueTask(self: *Self, task: DatabaseTask) !void {
        try self.tasks.append(self.allocator, task);
    }

    /// Process next task
    pub fn processNext(self: *Self) bool {
        if (self.tasks.items.len == 0) return false;

        var task = self.tasks.orderedRemove(0);
        task.callback(&task);
        return true;
    }

    /// Process all tasks
    pub fn processAll(self: *Self) void {
        while (self.processNext()) {}
    }
};

// ============================================================================
// Tests
// ============================================================================

test "AsyncOperationQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = AsyncOperationQueue.init(allocator);
    defer queue.deinit();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.pendingCount());
}

test "AsyncOperationQueue - enqueue and process" {
    const allocator = std.testing.allocator;

    var queue = AsyncOperationQueue.init(allocator);
    defer queue.deinit();

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    var executed = false;
    const Executor = struct {
        var done: *bool = undefined;
        fn execute(_: *AsyncOperation) void {
            done.* = true;
        }
    };
    Executor.done = &executed;

    try queue.enqueue(.{
        .request = &request,
        .op_type = .get,
        .execute = Executor.execute,
        .context = null,
        .priority = 0,
        .processed = false,
    });

    try std.testing.expect(!queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), queue.pendingCount());

    queue.processAll();

    try std.testing.expect(executed);
    try std.testing.expect(request.processed_flag);
}

test "IDBPromise - basic usage" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    var promise = IDBPromise.fromRequest(&request);

    try std.testing.expect(!promise.isSettled());

    // Simulate settling
    request.setResult(.{ .count = 42 });

    try std.testing.expect(promise.isSettled());
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(!promise.isRejected());
}

test "IDBPromise - rejection" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    var promise = IDBPromise.fromRequest(&request);

    request.setError(IDBError.NotFoundError);

    try std.testing.expect(promise.isSettled());
    try std.testing.expect(!promise.isFulfilled());
    try std.testing.expect(promise.isRejected());
}

test "IDBPromise - then handler on fulfilled" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    // Pre-settle
    request.setResult(.{ .count = 42 });

    var handler_called = false;
    const Handler = struct {
        var called: *bool = undefined;
        fn handle(_: *IDBRequest) void {
            called.* = true;
        }
    };
    Handler.called = &handler_called;

    var promise = IDBPromise.fromRequest(&request);
    _ = promise.then(Handler.handle);

    try std.testing.expect(handler_called);
}

test "IDBPromise - catch handler on rejected" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    // Pre-reject
    request.setError(IDBError.NotFoundError);

    var handler_called = false;
    var captured_error: ?IDBError = null;
    const Handler = struct {
        var called: *bool = undefined;
        var err: *?IDBError = undefined;
        fn handle(_: *IDBRequest, e: IDBError) void {
            called.* = true;
            err.* = e;
        }
    };
    Handler.called = &handler_called;
    Handler.err = &captured_error;

    var promise = IDBPromise.fromRequest(&request);
    _ = promise.catch_(Handler.handle);

    try std.testing.expect(handler_called);
    try std.testing.expectEqual(IDBError.NotFoundError, captured_error.?);
}

test "DatabaseTaskQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = DatabaseTaskQueue.init(allocator);
    defer queue.deinit();

    var executed = false;
    const Task = struct {
        var done: *bool = undefined;
        fn callback(_: *DatabaseTask) void {
            done.* = true;
        }
    };
    Task.done = &executed;

    try queue.queueTask(.{
        .callback = Task.callback,
        .context = null,
        .database_id = null,
    });

    try std.testing.expect(!executed);

    _ = queue.processNext();

    try std.testing.expect(executed);
}

test "resolveRequest fires success event" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    var handler_called = false;
    const Handler = struct {
        var called: *bool = undefined;
        fn handle(_: *IDBRequest) void {
            called.* = true;
        }
    };
    Handler.called = &handler_called;
    request.onsuccess = Handler.handle;

    resolveRequest(&request, .{ .count = 42 });

    try std.testing.expect(request.done_flag);
    try std.testing.expect(handler_called);
}

test "rejectRequest fires error event" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    var handler_called = false;
    const Handler = struct {
        var called: *bool = undefined;
        fn handle(_: *IDBRequest) void {
            called.* = true;
        }
    };
    Handler.called = &handler_called;
    request.onerror = Handler.handle;

    rejectRequest(&request, IDBError.NotFoundError);

    try std.testing.expect(request.done_flag);
    try std.testing.expectEqual(IDBError.NotFoundError, request.err.?);
    try std.testing.expect(handler_called);
}
