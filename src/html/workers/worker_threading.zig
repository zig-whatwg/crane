//! Worker Threading Infrastructure
//!
//! Spec: HTML Standard § 10.2 Workers
//! https://html.spec.whatwg.org/#workers
//!
//! This module provides true multi-threaded worker execution:
//! - Each worker runs on a separate OS thread
//! - Each worker has its own V8 Isolate for complete isolation
//! - Thread-safe message passing between workers and main thread
//! - Proper cleanup on worker termination
//!
//! ## Architecture
//!
//! ```
//! Main Thread                      Worker Thread
//! ─────────────                    ─────────────
//! ┌───────────────┐                ┌───────────────┐
//! │ Main V8       │                │ Worker V8     │
//! │ Isolate       │                │ Isolate       │
//! │               │                │               │
//! │  Context A    │                │  Context W    │
//! │  (Document)   │◄──Message──────│  (Worker)     │
//! │               │   Queue        │               │
//! └───────────────┘                └───────────────┘
//! ```
//!
//! ## Thread Safety
//!
//! - Messages are serialized using structured clone before crossing threads
//! - Message queues are protected by mutexes
//! - Worker state transitions are atomic
//! - V8 Isolates are never shared between threads

const std = @import("std");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;

const types = @import("types.zig");
const WorkerType = types.WorkerType;
const WorkerState = types.WorkerState;
const WorkerError = types.WorkerError;
const WorkerOptions = types.WorkerOptions;

// Message channel types for serialized messages
const message_channel = @import("message_channel.zig");
const SerializedValue = message_channel.SerializedValue;
const JSValue = message_channel.JSValue;

/// Thread-safe message queue for cross-thread communication
///
/// Messages are serialized using structured clone and safely passed
/// between the main thread and worker thread.
pub const ThreadSafeMessageQueue = struct {
    /// Queue of serialized messages
    queue: std.ArrayList(*SerializedMessage),

    /// Mutex protecting the queue
    mutex: Mutex,

    /// Condition variable for blocking reads
    condition: Condition,

    /// Whether the queue is closed (no more messages will be accepted)
    closed: bool,

    /// Allocator for internal allocations
    allocator: Allocator,

    const Self = @This();

    /// A serialized message ready for cross-thread transfer
    pub const SerializedMessage = struct {
        /// Serialized message data (structured clone output)
        data: SerializedValue,

        /// Transfer list (ArrayBuffers, MessagePorts, etc.)
        transfers: ?[]TransferItem,

        /// Allocator used
        allocator: Allocator,

        pub fn deinit(self: *SerializedMessage) void {
            self.data.deinit();
            if (self.transfers) |transfers| {
                self.allocator.free(transfers);
            }
            self.allocator.destroy(self);
        }
    };

    /// Items that can be transferred (not copied) between threads
    pub const TransferItem = struct {
        /// Type of transferable
        item_type: TransferType,
        /// Opaque pointer to the transferable data
        data: *anyopaque,
    };

    pub const TransferType = enum {
        array_buffer,
        message_port,
        readable_stream,
        writable_stream,
        transform_stream,
    };

    pub fn init(allocator: Allocator) Self {
        return .{
            .queue = std.ArrayList(*SerializedMessage).init(allocator),
            .mutex = .{},
            .condition = .{},
            .closed = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Clean up remaining messages
        for (self.queue.items) |msg| {
            msg.deinit();
        }
        self.queue.deinit();
    }

    /// Enqueue a message (thread-safe)
    ///
    /// Returns error if the queue is closed or out of memory.
    pub fn enqueue(self: *Self, message: *SerializedMessage) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) {
            return WorkerError.WorkerClosing;
        }

        try self.queue.append(message);

        // Signal any waiting readers
        self.condition.signal();
    }

    /// Dequeue a message (thread-safe, non-blocking)
    ///
    /// Returns null if no messages are available.
    pub fn tryDequeue(self: *Self) ?*SerializedMessage {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.queue.items.len == 0) {
            return null;
        }

        return self.queue.orderedRemove(0);
    }

    /// Dequeue a message (thread-safe, blocking)
    ///
    /// Blocks until a message is available or the queue is closed.
    /// Returns null if the queue is closed with no remaining messages.
    pub fn dequeue(self: *Self) ?*SerializedMessage {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.queue.items.len == 0 and !self.closed) {
            self.condition.wait(&self.mutex);
        }

        if (self.queue.items.len == 0) {
            return null; // Queue closed with no messages
        }

        return self.queue.orderedRemove(0);
    }

    /// Close the queue (no more messages will be accepted)
    pub fn close(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.closed = true;

        // Wake up all waiting readers
        self.condition.broadcast();
    }

    /// Check if the queue has pending messages
    pub fn hasPending(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.queue.items.len > 0;
    }
};

/// Worker Thread State
///
/// Represents the state of a worker running on a separate thread.
/// Thread-safe with atomic state transitions.
pub const WorkerThreadState = struct {
    /// Current worker state (atomic for thread-safe reads)
    state: std.atomic.Value(u8),

    /// Message queue from main thread to worker
    inbox: ThreadSafeMessageQueue,

    /// Message queue from worker to main thread
    outbox: ThreadSafeMessageQueue,

    /// Worker script URL
    script_url: []const u8,

    /// Worker type (classic/module)
    worker_type: WorkerType,

    /// Worker name
    name: []const u8,

    /// Thread handle (set when spawned)
    thread: ?Thread,

    /// Error message if worker failed to start
    error_message: ?[]const u8,

    /// Allocator
    allocator: Allocator,

    const Self = @This();

    /// State values for atomic operations
    const STATE_PENDING: u8 = 0;
    const STATE_STARTING: u8 = 1;
    const STATE_RUNNING: u8 = 2;
    const STATE_CLOSING: u8 = 3;
    const STATE_TERMINATED: u8 = 4;
    const STATE_ERROR: u8 = 5;

    pub fn init(
        allocator: Allocator,
        script_url: []const u8,
        options: WorkerOptions,
    ) !*Self {
        const state = try allocator.create(Self);
        errdefer allocator.destroy(state);

        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        const name_copy = if (options.name.len > 0)
            try allocator.dupe(u8, options.name)
        else
            "";
        errdefer if (name_copy.len > 0) allocator.free(name_copy);

        state.* = .{
            .state = std.atomic.Value(u8).init(STATE_PENDING),
            .inbox = ThreadSafeMessageQueue.init(allocator),
            .outbox = ThreadSafeMessageQueue.init(allocator),
            .script_url = url_copy,
            .worker_type = options.worker_type,
            .name = name_copy,
            .thread = null,
            .error_message = null,
            .allocator = allocator,
        };

        return state;
    }

    pub fn deinit(self: *Self) void {
        self.inbox.deinit();
        self.outbox.deinit();
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        if (self.error_message) |msg| {
            self.allocator.free(msg);
        }
        self.allocator.destroy(self);
    }

    /// Get current state as WorkerState enum
    pub fn getState(self: *const Self) WorkerState {
        return switch (self.state.load(.acquire)) {
            STATE_PENDING => .pending,
            STATE_STARTING => .fetching,
            STATE_RUNNING => .running,
            STATE_CLOSING => .closing,
            STATE_TERMINATED, STATE_ERROR => .terminated,
            else => .terminated,
        };
    }

    /// Atomically transition state
    pub fn transitionState(self: *Self, expected: u8, new: u8) bool {
        return self.state.cmpxchgStrong(expected, new, .acq_rel, .acquire) == null;
    }

    /// Check if worker is running
    pub fn isRunning(self: *const Self) bool {
        return self.state.load(.acquire) == STATE_RUNNING;
    }

    /// Check if worker is terminated
    pub fn isTerminated(self: *const Self) bool {
        const s = self.state.load(.acquire);
        return s == STATE_TERMINATED or s == STATE_ERROR;
    }

    /// Request worker termination
    pub fn requestTermination(self: *Self) void {
        // Atomically set to closing if currently running
        _ = self.state.cmpxchgStrong(STATE_RUNNING, STATE_CLOSING, .acq_rel, .acquire);

        // Close message queues to unblock any waiting threads
        self.inbox.close();
    }
};

/// Worker Thread Runner
///
/// Manages spawning and running worker threads with V8 isolates.
pub const WorkerThreadRunner = struct {
    /// The worker's thread state (shared between threads)
    thread_state: *WorkerThreadState,

    /// Allocator for the runner itself
    allocator: Allocator,

    /// Callback to create V8 isolate and context
    /// Signature: fn(*WorkerThreadState, Allocator) anyerror!*anyopaque
    create_isolate_fn: ?CreateIsolateFn,

    /// Callback to dispose V8 isolate
    /// Signature: fn(*anyopaque) void
    dispose_isolate_fn: ?DisposeIsolateFn,

    /// Callback to execute script in isolate
    /// Signature: fn(*anyopaque, []const u8, []const u8) anyerror!void
    execute_script_fn: ?ExecuteScriptFn,

    /// Callback context for V8 operations
    callback_context: ?*anyopaque,

    const Self = @This();

    /// Callback types for V8 integration
    pub const CreateIsolateFn = *const fn (*WorkerThreadState, Allocator) anyerror!*anyopaque;
    pub const DisposeIsolateFn = *const fn (*anyopaque) void;
    pub const ExecuteScriptFn = *const fn (*anyopaque, []const u8, []const u8) anyerror!void;

    pub fn init(
        allocator: Allocator,
        thread_state: *WorkerThreadState,
    ) !*Self {
        const runner = try allocator.create(Self);
        runner.* = .{
            .thread_state = thread_state,
            .allocator = allocator,
            .create_isolate_fn = null,
            .dispose_isolate_fn = null,
            .execute_script_fn = null,
            .callback_context = null,
        };
        return runner;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Set V8 integration callbacks
    pub fn setCallbacks(
        self: *Self,
        create_isolate: CreateIsolateFn,
        dispose_isolate: DisposeIsolateFn,
        execute_script: ExecuteScriptFn,
        context: ?*anyopaque,
    ) void {
        self.create_isolate_fn = create_isolate;
        self.dispose_isolate_fn = dispose_isolate;
        self.execute_script_fn = execute_script;
        self.callback_context = context;
    }

    /// Spawn the worker thread
    ///
    /// Creates a new OS thread and starts the worker's execution.
    /// Returns immediately; use thread_state to monitor progress.
    pub fn spawn(self: *Self) !void {
        // Transition from pending to starting
        if (!self.thread_state.transitionState(
            WorkerThreadState.STATE_PENDING,
            WorkerThreadState.STATE_STARTING,
        )) {
            return WorkerError.WorkerNotRunning;
        }

        // Spawn the worker thread
        self.thread_state.thread = try Thread.spawn(
            .{},
            workerThreadMain,
            .{self},
        );
    }

    /// Wait for the worker thread to finish
    pub fn join(self: *Self) void {
        if (self.thread_state.thread) |thread| {
            thread.join();
            self.thread_state.thread = null;
        }
    }

    /// The main function that runs on the worker thread
    fn workerThreadMain(self: *Self) void {
        var v8_isolate: ?*anyopaque = null;

        defer {
            // Clean up V8 isolate if created
            if (v8_isolate) |isolate| {
                if (self.dispose_isolate_fn) |dispose| {
                    dispose(isolate);
                }
            }

            // Mark as terminated
            self.thread_state.state.store(WorkerThreadState.STATE_TERMINATED, .release);
        }

        // Create V8 isolate for this worker thread
        if (self.create_isolate_fn) |create| {
            v8_isolate = create(self.thread_state, self.allocator) catch |err| {
                self.setError("Failed to create V8 isolate: {s}", .{@errorName(err)});
                self.thread_state.state.store(WorkerThreadState.STATE_ERROR, .release);
                return;
            };
        }

        // Transition to running
        if (!self.thread_state.transitionState(
            WorkerThreadState.STATE_STARTING,
            WorkerThreadState.STATE_RUNNING,
        )) {
            return; // Worker was terminated during startup
        }

        // Run the worker event loop
        self.runWorkerLoop(v8_isolate);
    }

    /// Worker event loop - processes messages and runs microtasks
    fn runWorkerLoop(self: *Self, isolate: ?*anyopaque) void {
        while (self.thread_state.isRunning()) {
            // Process incoming messages (non-blocking)
            while (self.thread_state.inbox.tryDequeue()) |msg| {
                defer msg.deinit();

                // Process the message
                self.handleIncomingMessage(isolate, msg);
            }

            // Run V8 microtasks here (if V8 integration available)
            // TODO: Add microtask checkpoint callback

            // Small sleep to avoid busy-waiting
            // In a production system, this would use proper event notification
            std.time.sleep(1_000_000); // 1ms
        }
    }

    /// Handle an incoming message from the main thread
    fn handleIncomingMessage(self: *Self, isolate: ?*anyopaque, msg: *ThreadSafeMessageQueue.SerializedMessage) void {
        _ = self;
        _ = isolate;
        _ = msg;
        // TODO: Dispatch message event to WorkerGlobalScope
        // 1. Deserialize the message
        // 2. Create MessageEvent
        // 3. Dispatch to 'onmessage' handler
    }

    /// Set error message (thread-safe via mutex)
    fn setError(self: *Self, comptime fmt: []const u8, args: anytype) void {
        _ = fmt;
        _ = args;
        // In a real implementation, format and store the error message
        // For now, errors are detected via state transition
        self.thread_state.state.store(WorkerThreadState.STATE_ERROR, .release);
    }
};

/// Threaded Worker Manager
///
/// High-level API for creating and managing threaded workers.
pub const ThreadedWorkerManager = struct {
    /// Active workers indexed by ID
    workers: std.StringHashMap(*WorkerThreadRunner),

    /// Next worker ID
    next_id: u64,

    /// Allocator
    allocator: Allocator,

    /// V8 integration callbacks (shared by all workers)
    create_isolate_fn: ?WorkerThreadRunner.CreateIsolateFn,
    dispose_isolate_fn: ?WorkerThreadRunner.DisposeIsolateFn,
    execute_script_fn: ?WorkerThreadRunner.ExecuteScriptFn,
    callback_context: ?*anyopaque,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .workers = std.StringHashMap(*WorkerThreadRunner).init(allocator),
            .next_id = 0,
            .allocator = allocator,
            .create_isolate_fn = null,
            .dispose_isolate_fn = null,
            .execute_script_fn = null,
            .callback_context = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Terminate all workers
        var iter = self.workers.iterator();
        while (iter.next()) |entry| {
            const runner = entry.value_ptr.*;
            runner.thread_state.requestTermination();
            runner.join();
            runner.thread_state.deinit();
            runner.deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.workers.deinit();
    }

    /// Set V8 integration callbacks (called once on initialization)
    pub fn setV8Callbacks(
        self: *Self,
        create_isolate: WorkerThreadRunner.CreateIsolateFn,
        dispose_isolate: WorkerThreadRunner.DisposeIsolateFn,
        execute_script: WorkerThreadRunner.ExecuteScriptFn,
        context: ?*anyopaque,
    ) void {
        self.create_isolate_fn = create_isolate;
        self.dispose_isolate_fn = dispose_isolate;
        self.execute_script_fn = execute_script;
        self.callback_context = context;
    }

    /// Create a new threaded worker
    pub fn createWorker(
        self: *Self,
        script_url: []const u8,
        options: WorkerOptions,
    ) !*WorkerThreadRunner {
        // Generate worker ID
        const id = self.next_id;
        self.next_id += 1;

        // Create ID string for storage
        var id_buf: [32]u8 = undefined;
        const id_str = std.fmt.bufPrint(&id_buf, "worker-{d}", .{id}) catch "worker-unknown";
        const id_copy = try self.allocator.dupe(u8, id_str);
        errdefer self.allocator.free(id_copy);

        // Create thread state
        const thread_state = try WorkerThreadState.init(self.allocator, script_url, options);
        errdefer thread_state.deinit();

        // Create runner
        const runner = try WorkerThreadRunner.init(self.allocator, thread_state);
        errdefer runner.deinit();

        // Set V8 callbacks if configured
        if (self.create_isolate_fn) |create| {
            runner.setCallbacks(
                create,
                self.dispose_isolate_fn.?,
                self.execute_script_fn.?,
                self.callback_context,
            );
        }

        // Store in map
        try self.workers.put(id_copy, runner);

        return runner;
    }

    /// Terminate a worker by ID
    pub fn terminateWorker(self: *Self, worker_id: []const u8) void {
        if (self.workers.get(worker_id)) |runner| {
            runner.thread_state.requestTermination();
        }
    }

    /// Get worker count
    pub fn getWorkerCount(self: *const Self) usize {
        return self.workers.count();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ThreadSafeMessageQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = ThreadSafeMessageQueue.init(allocator);
    defer queue.deinit();

    // Create a test message
    const msg = try allocator.create(ThreadSafeMessageQueue.SerializedMessage);
    msg.* = .{
        .data = .{
            .type = .primitive,
            .allocator = allocator,
            .data = .{ .primitive = .{ .undefined = {} } },
        },
        .transfers = null,
        .allocator = allocator,
    };

    // Enqueue
    try queue.enqueue(msg);
    try std.testing.expect(queue.hasPending());

    // Dequeue
    const dequeued = queue.tryDequeue();
    try std.testing.expect(dequeued != null);
    try std.testing.expect(!queue.hasPending());

    dequeued.?.deinit();
}

test "ThreadSafeMessageQueue - close prevents new messages" {
    const allocator = std.testing.allocator;

    var queue = ThreadSafeMessageQueue.init(allocator);
    defer queue.deinit();

    queue.close();

    // Create a test message
    const msg = try allocator.create(ThreadSafeMessageQueue.SerializedMessage);
    msg.* = .{
        .data = .{
            .type = .primitive,
            .allocator = allocator,
            .data = .{ .primitive = .{ .undefined = {} } },
        },
        .transfers = null,
        .allocator = allocator,
    };
    defer msg.deinit();

    // Enqueue should fail when closed
    try std.testing.expectError(WorkerError.WorkerClosing, queue.enqueue(msg));
}

test "WorkerThreadState - state transitions" {
    const allocator = std.testing.allocator;

    const state = try WorkerThreadState.init(allocator, "https://example.com/worker.js", .{
        .name = "test-worker",
    });
    defer state.deinit();

    // Initial state is pending
    try std.testing.expectEqual(WorkerState.pending, state.getState());

    // Transition to starting
    try std.testing.expect(state.transitionState(
        WorkerThreadState.STATE_PENDING,
        WorkerThreadState.STATE_STARTING,
    ));
    try std.testing.expectEqual(WorkerState.fetching, state.getState());

    // Transition to running
    try std.testing.expect(state.transitionState(
        WorkerThreadState.STATE_STARTING,
        WorkerThreadState.STATE_RUNNING,
    ));
    try std.testing.expect(state.isRunning());
}

test "ThreadedWorkerManager - create worker" {
    const allocator = std.testing.allocator;

    var manager = ThreadedWorkerManager.init(allocator);
    defer manager.deinit();

    const runner = try manager.createWorker(
        "https://example.com/worker.js",
        .{ .name = "test" },
    );

    try std.testing.expectEqual(@as(usize, 1), manager.getWorkerCount());
    try std.testing.expectEqual(WorkerState.pending, runner.thread_state.getState());
}
