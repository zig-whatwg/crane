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

const platform = @import("platform");
const EventWakeup = platform.EventWakeup;

// Debug logging for worker threading - uses stderr for visibility
// This is enabled for debugging WPT worker test timeouts
const debug = struct {
    pub inline fn print(comptime fmt: []const u8, args: anytype) void {
        const stderr = std.fs.File.stderr();
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "[WORKER_THREAD] " ++ fmt, args) catch "[WORKER_THREAD] (format error)\n";
        stderr.writeAll(msg) catch {};
    }
};

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

    /// Optional wakeup primitive to signal when messages are enqueued
    /// This allows the main thread to be woken up immediately instead of polling
    wakeup: ?*EventWakeup,

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
            .queue = .{},
            .mutex = .{},
            .condition = .{},
            .closed = false,
            .allocator = allocator,
            .wakeup = null,
        };
    }

    /// Set the wakeup primitive for this queue
    /// When a message is enqueued, the wakeup will be signaled
    pub fn setWakeup(self: *Self, wakeup: *EventWakeup) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.wakeup = wakeup;
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Clean up remaining messages
        for (self.queue.items) |msg| {
            msg.deinit();
        }
        self.queue.deinit(self.allocator);
    }

    /// Enqueue a message (thread-safe)
    ///
    /// Returns error if the queue is closed or out of memory.
    pub fn enqueue(self: *Self, message: *SerializedMessage) !void {
        const thread_id = std.Thread.getCurrentId();
        debug.print("enqueue() called, self={*}, thread={d}\n", .{ self, thread_id });
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) {
            debug.print("enqueue() FAILED: queue is closed\n", .{});
            return WorkerError.WorkerClosing;
        }

        try self.queue.append(self.allocator, message);
        debug.print("enqueue() message added, queue.len={d}\n", .{self.queue.items.len});

        // Signal any waiting readers (for blocking dequeue)
        self.condition.signal();

        // Signal the wakeup primitive to wake up the main thread's event loop
        // This enables immediate delivery instead of relying on polling
        if (self.wakeup) |wakeup| {
            debug.print("enqueue() signaling wakeup\n", .{});
            wakeup.signal();
        }
    }

    /// Dequeue a message (thread-safe, non-blocking)
    ///
    /// Returns null if no messages are available.
    pub fn tryDequeue(self: *Self) ?*SerializedMessage {
        self.mutex.lock();
        defer self.mutex.unlock();

        const thread_id = std.Thread.getCurrentId();
        debug.print("tryDequeue() self={*}, queue.items.len={d}, thread={d}\n", .{ self, self.queue.items.len, thread_id });

        if (self.queue.items.len == 0) {
            return null;
        }

        const msg = self.queue.orderedRemove(0);
        debug.print("tryDequeue() returning message, remaining={d}\n", .{self.queue.items.len});
        return msg;
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

    /// Opaque pointer to DedicatedWorker (or other worker type)
    /// Used by callbacks to access worker-specific functionality
    worker_ptr: ?*anyopaque,

    /// EventWakeup for waking up the main thread when messages are posted
    /// This is shared with outbox.wakeup so messages trigger immediate delivery
    wakeup: ?*EventWakeup,

    /// EventWakeup for waking up the worker thread when messages arrive or termination requested
    /// This enables efficient event-driven waiting instead of polling
    worker_wakeup: ?*EventWakeup,

    /// Document origin URL for resolving relative imports in data:/blob: workers
    /// This is the creating document's URL, passed through from Worker constructor
    document_origin: ?[]const u8,

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
            .worker_ptr = null,
            .wakeup = null,
            .worker_wakeup = null,
            .document_origin = null, // Set later via setDocumentOrigin()
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
        if (self.document_origin) |origin| {
            self.allocator.free(origin);
        }
        // Clean up worker wakeup if allocated
        if (self.worker_wakeup) |wakeup| {
            wakeup.deinit();
            self.allocator.destroy(wakeup);
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

    /// Set the document origin for resolving relative imports in data:/blob: workers
    /// This should be called after init() with the creating document's URL
    pub fn setDocumentOrigin(self: *Self, origin: []const u8) !void {
        // Free existing if set
        if (self.document_origin) |old| {
            self.allocator.free(old);
        }
        self.document_origin = try self.allocator.dupe(u8, origin);
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

        // Signal the worker wakeup to immediately wake the worker thread
        // This ensures the worker exits promptly instead of waiting for a timeout
        if (self.worker_wakeup) |wakeup| {
            wakeup.signal();
        }
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

    /// Callback to dispatch a message to the worker's onmessage handler
    /// Signature: fn(*anyopaque, *SerializedMessage) anyerror!void
    dispatch_message_fn: ?DispatchMessageFn,

    /// Callback to run V8 microtask checkpoint
    /// Signature: fn(*anyopaque) void
    /// This is needed because html_core cannot import v8 directly
    microtask_checkpoint_fn: ?MicrotaskCheckpointFn,

    /// Callback to run V8 event loop once to process libuv timers
    /// Signature: fn(*anyopaque) void
    /// This processes setTimeout/setInterval callbacks
    event_loop_run_once_fn: ?EventLoopRunOnceFn,

    /// Callback context for V8 operations
    callback_context: ?*anyopaque,

    const Self = @This();

    /// Callback types for V8 integration
    pub const CreateIsolateFn = *const fn (*WorkerThreadState, Allocator) anyerror!*anyopaque;
    pub const DisposeIsolateFn = *const fn (*anyopaque) void;
    pub const ExecuteScriptFn = *const fn (*anyopaque, []const u8, []const u8) anyerror!void;
    pub const DispatchMessageFn = *const fn (*anyopaque, *ThreadSafeMessageQueue.SerializedMessage) anyerror!void;
    pub const MicrotaskCheckpointFn = *const fn (*anyopaque) void;
    pub const EventLoopRunOnceFn = *const fn (*anyopaque) void;

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
            .dispatch_message_fn = null,
            .microtask_checkpoint_fn = null,
            .event_loop_run_once_fn = null,
            .callback_context = null,
        };
        return runner;
    }

    pub fn deinit(self: *Self) void {
        // Join the thread if still running
        if (self.thread_state.thread) |thread| {
            // Request termination if not already terminated
            self.thread_state.requestTermination();
            thread.join();
            self.thread_state.thread = null;
        }

        // Clean up thread state
        self.thread_state.deinit();

        // Clean up self
        self.allocator.destroy(self);
    }

    /// Set V8 integration callbacks
    pub fn setCallbacks(
        self: *Self,
        create_isolate: CreateIsolateFn,
        dispose_isolate: DisposeIsolateFn,
        execute_script: ExecuteScriptFn,
        dispatch_message: ?DispatchMessageFn,
        microtask_checkpoint: ?MicrotaskCheckpointFn,
        event_loop_run_once: ?EventLoopRunOnceFn,
        context: ?*anyopaque,
    ) void {
        self.create_isolate_fn = create_isolate;
        self.dispose_isolate_fn = dispose_isolate;
        self.execute_script_fn = execute_script;
        self.dispatch_message_fn = dispatch_message;
        self.microtask_checkpoint_fn = microtask_checkpoint;
        self.event_loop_run_once_fn = event_loop_run_once;
        self.callback_context = context;
    }

    /// Spawn the worker thread
    ///
    /// Creates a new OS thread and starts the worker's execution.
    /// Returns immediately; use thread_state to monitor progress.
    pub fn spawn(self: *Self) !void {
        debug.print("spawn() called, script_url={s}\n", .{self.thread_state.script_url});

        // Transition from pending to starting
        if (!self.thread_state.transitionState(
            WorkerThreadState.STATE_PENDING,
            WorkerThreadState.STATE_STARTING,
        )) {
            debug.print("spawn() FAILED: state transition failed (not pending)\n", .{});
            return WorkerError.WorkerNotRunning;
        }
        debug.print("spawn() state transitioned to STARTING\n", .{});

        // Create EventWakeup for efficient worker thread waiting
        // This replaces busy-polling with event-driven waiting
        const wakeup = try self.allocator.create(EventWakeup);
        errdefer self.allocator.destroy(wakeup);
        wakeup.* = EventWakeup.init() catch |err| {
            self.allocator.destroy(wakeup);
            return err;
        };
        self.thread_state.worker_wakeup = wakeup;

        // Set the wakeup on the inbox so message enqueues wake the worker
        self.thread_state.inbox.setWakeup(wakeup);

        // Spawn the worker thread
        debug.print("spawn() about to call Thread.spawn()...\n", .{});
        self.thread_state.thread = try Thread.spawn(
            .{},
            workerThreadMain,
            .{self},
        );
        debug.print("spawn() Thread.spawn() completed, worker thread created\n", .{});
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
        debug.print("[WorkerThread] workerThreadMain starting\n", .{});
        var v8_isolate: ?*anyopaque = null;

        // Import DedicatedWorker for cleanup
        const DedicatedWorker = @import("dedicated_worker.zig").DedicatedWorker;

        defer {
            debug.print("[WorkerThread] workerThreadMain defer cleanup\n", .{});

            // Clean up the DedicatedWorker's port pair message queues
            // This prevents memory leaks from messages queued but never consumed
            if (self.thread_state.worker_ptr) |worker_ptr| {
                const dedicated_worker: *DedicatedWorker = @ptrCast(@alignCast(worker_ptr));

                // IMPORTANT: Only cleanup inside_port messages (worker's incoming queue)
                // DO NOT cleanup outside_port - those messages are for the main thread!
                // The main thread will poll the outbox and dispatch them.
                dedicated_worker.port_pair.cleanupInsidePortMessages();

                debug.print("[WorkerThread] Cleaned up inside port messages (outside port preserved for main thread)\n", .{});
            }

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
        debug.print("[WorkerThread] Creating V8 isolate...\n", .{});
        if (self.create_isolate_fn) |create| {
            v8_isolate = create(self.thread_state, self.allocator) catch |err| {
                self.setError("Failed to create V8 isolate: {s}", .{@errorName(err)});
                self.thread_state.state.store(WorkerThreadState.STATE_ERROR, .release);
                debug.print("[WorkerThread] Failed to create isolate: {s}\n", .{@errorName(err)});
                return;
            };
            debug.print("[WorkerThread] V8 isolate created successfully\n", .{});
        } else {
            debug.print("[WorkerThread] No create_isolate_fn set!\n", .{});
        }

        // Transition to running
        if (!self.thread_state.transitionState(
            WorkerThreadState.STATE_STARTING,
            WorkerThreadState.STATE_RUNNING,
        )) {
            debug.print("[WorkerThread] Failed to transition to RUNNING\n", .{});
            return; // Worker was terminated during startup
        }
        debug.print("[WorkerThread] Transitioned to RUNNING, entering event loop\n", .{});

        // Run the worker event loop
        self.runWorkerLoop(v8_isolate);
        debug.print("[WorkerThread] Event loop exited\n", .{});
    }

    /// Worker event loop - processes messages and runs microtasks
    fn runWorkerLoop(self: *Self, isolate: ?*anyopaque) void {
        // Import DedicatedWorker to check its closing state
        const DedicatedWorker = @import("dedicated_worker.zig").DedicatedWorker;

        var loop_count: u32 = 0;
        while (self.thread_state.isRunning()) {
            loop_count += 1;
            if (loop_count == 1 or loop_count % 1000 == 0) {
                debug.print("[WorkerThread] runWorkerLoop iteration {d}\n", .{loop_count});
            }

            // Check if the DedicatedWorker has been closed (e.g., via done() or close())
            // This bridges the gap between the WorkerAgent state and the thread state
            if (self.thread_state.worker_ptr) |worker_ptr| {
                const dedicated_worker: *DedicatedWorker = @ptrCast(@alignCast(worker_ptr));
                if (dedicated_worker.agent.isClosing() or dedicated_worker.agent.isTerminated()) {
                    debug.print("[WorkerThread] DedicatedWorker is closing/terminated, exiting loop\n", .{});
                    // Worker has been closed, exit the loop
                    self.thread_state.requestTermination();
                    break;
                }
            }

            // Process incoming messages (non-blocking)
            debug.print("[WorkerThread] About to tryDequeue, thread_state={*}, inbox={*}\n", .{ self.thread_state, &self.thread_state.inbox });
            while (self.thread_state.inbox.tryDequeue()) |msg| {
                debug.print("[WorkerThread] Dequeued message, dispatching...\n", .{});
                // Note: handleIncomingMessage takes ownership of the message
                // and is responsible for calling msg.deinit() via the dispatch callback
                self.handleIncomingMessage(isolate, msg);
            }

            // Check again after processing messages (worker script may have called close())
            if (self.thread_state.worker_ptr) |worker_ptr| {
                const dedicated_worker: *DedicatedWorker = @ptrCast(@alignCast(worker_ptr));
                if (dedicated_worker.agent.isClosing() or dedicated_worker.agent.isTerminated()) {
                    debug.print("[WorkerThread] DedicatedWorker closed after message processing, exiting\n", .{});
                    self.thread_state.requestTermination();
                    break;
                }
            }

            // Run V8 microtask checkpoint
            // This is critical for:
            // 1. Promise resolution (microtasks)
            // 2. setTimeout/setInterval execution (event loop timers)
            // 3. Async/await continuations
            //
            // Note: We use a callback because html_core cannot import v8 directly.
            // The callback is provided by worker_v8_context.zig which has V8 access.
            // The callback implementation handles HandleScope creation internally.
            if (self.microtask_checkpoint_fn) |checkpoint_fn| {
                if (isolate) |iso| {
                    checkpoint_fn(iso);
                }
            }

            // Run V8 event loop once to process libuv timers (setTimeout/setInterval)
            // This MUST be called to fire timer callbacks - the V8EventLoop's libuv timers
            // are NOT processed by the HTML event loop spin below.
            if (self.event_loop_run_once_fn) |run_once_fn| {
                if (isolate) |iso| {
                    run_once_fn(iso);
                }
            }

            // Spin the worker's event loop to process timers and tasks
            // This handles setTimeout, setInterval, and queued tasks
            if (self.thread_state.worker_ptr) |worker_ptr| {
                const dedicated_worker: *DedicatedWorker = @ptrCast(@alignCast(worker_ptr));
                dedicated_worker.spin() catch |err| {
                    debug.print("[WorkerThread] event_loop.spin error: {s}\n", .{@errorName(err)});
                };
            }

            // Wait for messages or termination signal using EventWakeup
            // This is efficient - no busy-polling, just event-driven waiting
            // The wakeup is signaled when:
            // - A message is enqueued to the inbox (via inbox.setWakeup)
            // - Termination is requested (via requestTermination signaling worker_wakeup)
            if (self.thread_state.worker_wakeup) |wakeup| {
                // Wait with 100ms timeout as a fallback for edge cases
                // (e.g., worker script calling close() without message)
                _ = wakeup.wait(100) catch {};
            } else {
                // Fallback if no wakeup configured (shouldn't happen in normal use)
                std.Thread.sleep(1_000_000); // 1ms
            }
        }
        debug.print("[WorkerThread] runWorkerLoop exited after {d} iterations\n", .{loop_count});
    }

    /// Handle an incoming message from the main thread
    fn handleIncomingMessage(self: *Self, isolate: ?*anyopaque, msg: *ThreadSafeMessageQueue.SerializedMessage) void {
        debug.print("[WorkerThread] handleIncomingMessage() called, msg.data.type={s}\n", .{@tagName(msg.data.type)});
        // Dispatch message to worker's onmessage handler via V8 callback
        if (self.dispatch_message_fn) |dispatch_fn| {
            if (isolate) |iso| {
                debug.print("[WorkerThread] handleIncomingMessage() dispatching to V8...\n", .{});
                dispatch_fn(iso, msg) catch |err| {
                    // Log error but continue processing other messages
                    std.log.err("Failed to dispatch message to worker: {}", .{err});
                    debug.print("[WorkerThread] handleIncomingMessage() dispatch FAILED: {s}\n", .{@errorName(err)});
                };
                debug.print("[WorkerThread] handleIncomingMessage() dispatch complete\n", .{});
            } else {
                debug.print("[WorkerThread] handleIncomingMessage() no isolate, skipping dispatch\n", .{});
            }
        } else {
            debug.print("[WorkerThread] handleIncomingMessage() no dispatch_fn, skipping\n", .{});
        }
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
    dispatch_message_fn: ?WorkerThreadRunner.DispatchMessageFn,
    microtask_checkpoint_fn: ?WorkerThreadRunner.MicrotaskCheckpointFn,
    event_loop_run_once_fn: ?WorkerThreadRunner.EventLoopRunOnceFn,
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
            .dispatch_message_fn = null,
            .microtask_checkpoint_fn = null,
            .event_loop_run_once_fn = null,
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
        dispatch_message: ?WorkerThreadRunner.DispatchMessageFn,
        microtask_checkpoint: ?WorkerThreadRunner.MicrotaskCheckpointFn,
        event_loop_run_once: ?WorkerThreadRunner.EventLoopRunOnceFn,
        context: ?*anyopaque,
    ) void {
        self.create_isolate_fn = create_isolate;
        self.dispose_isolate_fn = dispose_isolate;
        self.execute_script_fn = execute_script;
        self.dispatch_message_fn = dispatch_message;
        self.microtask_checkpoint_fn = microtask_checkpoint;
        self.event_loop_run_once_fn = event_loop_run_once;
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
                self.dispatch_message_fn,
                self.microtask_checkpoint_fn,
                self.event_loop_run_once_fn,
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
