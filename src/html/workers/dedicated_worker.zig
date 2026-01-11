//! Dedicated Worker
//!
//! Spec: HTML Standard § 10.2.3 Dedicated workers and the Worker interface
//! https://html.spec.whatwg.org/#dedicated-workers-and-the-worker-interface
//!
//! A dedicated worker is owned by a single Document or worker.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Debug logging for worker messaging - uses stderr for visibility
const dwdebug = struct {
    pub inline fn print(comptime fmt: []const u8, args: anytype) void {
        const stderr = std.fs.File.stderr();
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "[DEDICATED_WORKER] " ++ fmt, args) catch "[DEDICATED_WORKER] (format error)\n";
        stderr.writeAll(msg) catch {};
    }
};

const types = @import("types.zig");
const WorkerData = types.WorkerData;
const WorkerState = types.WorkerState;
const WorkerType = types.WorkerType;
const WorkerOptions = types.WorkerOptions;
const WorkerError = types.WorkerError;
const RequestCredentials = types.RequestCredentials;

const worker_agent = @import("worker_agent.zig");
const WorkerAgent = worker_agent.WorkerAgent;

const worker_error = @import("worker_error.zig");
const WorkerErrorHandler = worker_error.WorkerErrorHandler;
const WorkerErrorEvent = worker_error.WorkerErrorEvent;
const TerminationState = worker_error.TerminationState;

const platform_mod = @import("platform");
const timer_backend = platform_mod.timer_backend;
const TimerBackend = timer_backend.TimerBackend;

// Script fetching for worker scripts
const script_fetch = @import("script_fetch.zig");
const WorkerScriptFetchOptions = script_fetch.WorkerScriptFetchOptions;
const FetchedScript = script_fetch.FetchedScript;
const WorkerScriptError = script_fetch.WorkerScriptError;

// Import threading infrastructure for cross-thread message passing
const worker_threading = @import("worker_threading.zig");
const WorkerThreadState = worker_threading.WorkerThreadState;

// Message channel for postMessage communication
const message_channel = @import("message_channel.zig");
const WorkerPortPair = message_channel.WorkerPortPair;
const WorkerPort = message_channel.WorkerPort;
const WorkerMessageError = message_channel.WorkerMessageError;
const QueuedMessage = message_channel.QueuedMessage;
const SerializedValue = message_channel.SerializedValue;
const JSValue = message_channel.JSValue;

// Structured clone algorithm for message serialization
// Note: message_channel.zig has its own serialize/deserialize wrappers
const serializeForPostMessage = message_channel.serializeForPostMessage;
const deserializeFromPostMessage = message_channel.deserializeFromPostMessage;

// ============================================================================
// Global Threaded Worker Registry
// ============================================================================
// This registry tracks workers running on separate OS threads. The main thread
// polls this registry to receive messages from worker threads via their
// thread-safe outbox queues.

/// Global registry of threaded workers that need message polling
pub const ThreadedWorkerRegistry = struct {
    pub const EventWakeup = platform_mod.EventWakeup;

    var workers: std.AutoHashMapUnmanaged(usize, *DedicatedWorker) = .{};
    var mutex: std.Thread.Mutex = .{};
    var registry_allocator: ?Allocator = null;
    var next_id: usize = 1;

    /// Global wakeup shared by all workers - signals when any worker posts a message
    /// This allows the main thread to wait efficiently instead of polling
    pub var global_wakeup: ?*EventWakeup = null;

    /// Initialize the registry with an allocator
    pub fn init(allocator: Allocator) void {
        mutex.lock();
        defer mutex.unlock();
        if (registry_allocator == null) {
            registry_allocator = allocator;
        }
    }

    /// Get or create the global wakeup primitive
    /// All worker outboxes share this wakeup so any message wakes the main thread
    pub fn getOrCreateGlobalWakeup(allocator: Allocator) !*EventWakeup {
        mutex.lock();
        defer mutex.unlock();

        if (global_wakeup) |w| return w;

        const w = try allocator.create(EventWakeup);
        errdefer allocator.destroy(w);
        w.* = try EventWakeup.init();
        global_wakeup = w;
        return w;
    }

    /// Register a worker with a thread state for message polling
    pub fn register(worker: *DedicatedWorker) void {
        mutex.lock();
        defer mutex.unlock();
        // Use the worker's allocator if registry not initialized
        const alloc = registry_allocator orelse blk: {
            registry_allocator = worker.allocator;
            break :blk worker.allocator;
        };
        const id = next_id;
        next_id += 1;
        workers.put(alloc, id, worker) catch {
            return;
        };

        // Wire up the global wakeup to this worker's outbox if available
        // This ensures any message from any worker wakes the main thread
        if (worker.thread_state) |ts| {
            if (global_wakeup) |w| {
                ts.outbox.setWakeup(w);
                ts.wakeup = w;
            }
        }
    }

    /// Unregister a worker (called when worker is terminated/destroyed)
    pub fn unregister(worker: *DedicatedWorker) void {
        mutex.lock();
        defer mutex.unlock();

        // Find and remove the worker by value
        var to_remove: ?usize = null;
        var iter = workers.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* == worker) {
                to_remove = entry.key_ptr.*;
                break;
            }
        }
        if (to_remove) |id| {
            _ = workers.remove(id);
        } else {}
    }

    /// Poll all registered workers' outboxes and dispatch messages to their outside ports.
    /// This is called from the main thread's event loop.
    /// Returns true if any messages were dispatched.
    ///
    /// IMPORTANT: This function collects messages under the lock, then releases the lock
    /// before dispatching to avoid deadlock. If a handler creates a new Worker, it would
    /// deadlock if we held the mutex during dispatch.
    pub fn pollAndDispatch() bool {
        // Temporary storage for collected messages
        // We collect under lock, then dispatch without lock to avoid deadlock
        const MessageToDispatch = struct {
            worker: *DedicatedWorker,
            queued_msg: *message_channel.QueuedMessage,
        };

        // Temporary storage for collected errors
        const ErrorToDispatch = struct {
            worker: *DedicatedWorker,
            error_event: *const worker_error.WorkerErrorEvent,
        };

        var messages_to_dispatch: [256]MessageToDispatch = undefined;
        var message_count: usize = 0;

        var errors_to_dispatch: [16]ErrorToDispatch = undefined;
        var error_count: usize = 0;

        // Phase 1: Collect messages and errors under lock
        {
            mutex.lock();
            defer mutex.unlock();

            dwdebug.print("pollAndDispatch() iterating {d} registered workers\n", .{workers.count()});
            var iter = workers.valueIterator();
            while (iter.next()) |worker_ptr| {
                const worker = worker_ptr.*;
                const ts_ptr: usize = if (worker.thread_state) |ts| @intFromPtr(ts) else 0;
                dwdebug.print("pollAndDispatch() checking worker, thread_state={x}\n", .{ts_ptr});
                if (worker.thread_state) |ts| {
                    dwdebug.print("pollAndDispatch() worker has thread_state, outbox ptr={*}\n", .{&ts.outbox});
                    // Poll the thread-safe outbox for messages from the worker thread
                    while (ts.outbox.tryDequeue()) |msg| {
                        if (message_count >= messages_to_dispatch.len) {
                            dwdebug.print("pollAndDispatch() WARNING: message buffer full, dropping message\n", .{});
                            msg.deinit();
                            continue;
                        }

                        dwdebug.print("pollAndDispatch() dequeued message #{d} from worker\n", .{message_count + 1});

                        // Create a QueuedMessage to pass to the handler
                        const serialized = worker.allocator.create(SerializedValue) catch {
                            dwdebug.print("pollAndDispatch() FAILED to allocate SerializedValue\n", .{});
                            msg.deinit();
                            continue;
                        };
                        serialized.* = msg.data;

                        const queued_msg = message_channel.QueuedMessage.init(
                            worker.allocator,
                            serialized,
                            null,
                        ) catch {
                            dwdebug.print("pollAndDispatch() FAILED to create QueuedMessage\n", .{});
                            worker.allocator.destroy(serialized);
                            msg.allocator.destroy(msg);
                            continue;
                        };

                        // Free the SerializedMessage wrapper (data ownership transferred to queued_msg)
                        msg.allocator.destroy(msg);

                        // Store for dispatch after releasing lock
                        messages_to_dispatch[message_count] = .{
                            .worker = worker,
                            .queued_msg = queued_msg,
                        };
                        message_count += 1;
                    }

                    // Also check for pending errors from the worker thread
                    if (ts.takePendingError()) |error_event| {
                        dwdebug.print("pollAndDispatch() found pending error from worker: {s}\n", .{error_event.message});
                        if (error_count < errors_to_dispatch.len) {
                            errors_to_dispatch[error_count] = .{
                                .worker = worker,
                                .error_event = error_event,
                            };
                            error_count += 1;
                        } else {
                            // Buffer full, clean up
                            @constCast(error_event).deinit();
                        }
                    }
                }
            }
        }
        // Lock is now released

        // Phase 2: Dispatch messages without holding lock (prevents deadlock)
        for (messages_to_dispatch[0..message_count]) |item| {
            dwdebug.print("pollAndDispatch() dispatching message via DedicatedWorker.on_message\n", .{});
            if (item.worker.on_message) |handler| {
                handler(item.worker, item.queued_msg);
                dwdebug.print("pollAndDispatch() handler called successfully\n", .{});
            } else {
                dwdebug.print("pollAndDispatch() WARNING: no on_message handler set!\n", .{});
                // Clean up if no handler
                item.queued_msg.deinit();
            }
            dwdebug.print("pollAndDispatch() dispatch complete\n", .{});
        }

        // Phase 3: Dispatch errors to main thread via worker's error handler
        for (errors_to_dispatch[0..error_count]) |item| {
            dwdebug.print("pollAndDispatch() dispatching error to worker.handleError\n", .{});
            // Call the worker's error handler (fires ErrorEvent to worker.onerror)
            item.worker.handleError(@constCast(item.error_event));
            // Clean up the error event (we own it now)
            @constCast(item.error_event).deinit();
            dwdebug.print("pollAndDispatch() error dispatch complete\n", .{});
        }

        if (message_count > 0) {
            dwdebug.print("pollAndDispatch() processed {d} messages total\n", .{message_count});
        }
        if (error_count > 0) {
            dwdebug.print("pollAndDispatch() processed {d} errors total\n", .{error_count});
        }

        return message_count > 0 or error_count > 0;
    }

    /// Terminate all workers without destroying the registry.
    /// Called during navigation to clean up workers from the previous context.
    /// Workers will be unregistered as they terminate.
    ///
    /// CRITICAL: This function MUST join all worker threads before returning.
    /// Otherwise, worker threads may still be running when the context is destroyed,
    /// leading to use-after-free crashes (Bus error at address 0x3a0048448).
    pub fn terminateAllWorkers() void {

        // First pass: collect thread handles and request termination
        // We need to do this outside the mutex to avoid deadlock when joining
        var threads_to_join: [32]?std.Thread = [_]?std.Thread{null} ** 32;
        var thread_count: usize = 0;
        var worker_count: usize = 0;

        {
            mutex.lock();
            defer mutex.unlock();

            var iter = workers.valueIterator();
            while (iter.next()) |worker_ptr| {
                worker_count += 1;
                const worker = worker_ptr.*;

                // Terminate the worker agent (stops event loop, closes ports)
                worker.agent.terminate();

                // Request termination on the thread state (signals thread to exit)
                if (worker.thread_state) |ts| {
                    ts.requestTermination();

                    // Collect thread handle for joining
                    if (ts.thread) |thread| {
                        if (thread_count < threads_to_join.len) {
                            threads_to_join[thread_count] = thread;
                            thread_count += 1;
                        }
                        // Clear the thread handle to prevent double-join
                        ts.thread = null;
                    } else {}
                } else {}
            }
        }

        // Second pass: join all worker threads (outside mutex to avoid deadlock)
        // This ensures all worker threads have fully exited before we return
        for (threads_to_join[0..thread_count]) |maybe_thread| {
            if (maybe_thread) |thread| {
                thread.join();
            }
        }

        // Final pass: clear the workers map
        {
            mutex.lock();
            defer mutex.unlock();
            workers.clearRetainingCapacity();
        }
    }

    /// Cleanup the registry
    pub fn deinit() void {
        mutex.lock();
        defer mutex.unlock();
        if (registry_allocator) |alloc| {
            workers.deinit(alloc);
            workers = .{};

            // Clean up global wakeup
            if (global_wakeup) |w| {
                w.deinit();
                alloc.destroy(w);
                global_wakeup = null;
            }

            registry_allocator = null;
        }
    }
};

/// Dedicated Worker implementation.
///
/// Spec: HTML Standard § 10.2.3
/// "A dedicated worker is a worker which can only be accessed from the script
/// that created it."
pub const DedicatedWorker = struct {
    /// Worker agent (handles event loop and state)
    agent: *WorkerAgent,

    /// Port pair for bidirectional communication
    ///
    /// Spec: HTML Standard § 10.2.3
    /// "Each Worker object has an associated outside port and inside port."
    /// The ports are entangled: messages sent to one arrive at the other.
    port_pair: *WorkerPortPair,

    /// Script URL
    script_url: []const u8,

    /// Worker name (for debugging)
    name: []const u8,

    /// Allocator
    allocator: Allocator,

    /// Message handler callback for incoming messages on the outside port
    /// Called when the worker sends a message back to the main thread
    on_message: ?*const fn (*DedicatedWorker, *QueuedMessage) void = null,

    /// Message handler callback for incoming messages on the inside port
    /// Called when the main thread sends a message to the worker
    /// This is set by the WebIDL layer to dispatch MessageEvents
    on_inside_message: ?*const fn (*DedicatedWorker, *QueuedMessage) void = null,

    /// User data for the INSIDE (worker thread) message handler.
    /// Used by DedicatedWorkerGlobalScope.setupMessageHandlerDirect() to store
    /// callback data for handling messages inside the worker.
    user_data: ?*anyopaque = null,

    /// User data for the OUTSIDE (main thread) message handler.
    /// Used by Worker.call_constructor() to store InternalState* for handling
    /// messages that the worker sends back to the main thread.
    outside_user_data: ?*anyopaque = null,

    /// Cleanup function for outside_user_data. Called during deinit() to properly
    /// destroy the user_data. This avoids circular module dependencies by
    /// letting the caller provide the cleanup logic.
    outside_user_data_cleanup_fn: ?*const fn (*anyopaque) void = null,

    /// Thread state for cross-thread message passing (set when running on separate thread)
    /// When a worker runs on a separate OS thread, this points to the shared WorkerThreadState
    /// which contains thread-safe inbox/outbox queues for message passing.
    thread_state: ?*WorkerThreadState = null,

    /// Pending messages to be sent to the worker thread once thread_state is set.
    /// This buffers messages that are posted via postMessage() before the worker thread
    /// has been spawned (during the async script fetch period).
    /// Uses page_allocator since these messages will be transferred to a thread-safe queue.
    pending_inbox_messages: std.ArrayListUnmanaged(*worker_threading.ThreadSafeMessageQueue.SerializedMessage) = .{},

    /// Create a new dedicated worker.
    ///
    /// Spec: HTML Standard § 10.2.3.1 Constructor
    /// "new Worker(scriptURL, options)"
    ///
    /// This creates entangled MessagePort pair for communication:
    /// - `outside_port`: Used by the owner (main thread) to send/receive messages
    /// - `inside_port`: Used by the worker to send/receive messages
    pub fn init(
        allocator: Allocator,
        platform: TimerBackend,
        script_url: []const u8,
        options: WorkerOptions,
    ) !*DedicatedWorker {
        const worker = try allocator.create(DedicatedWorker);
        errdefer allocator.destroy(worker);

        // Create worker agent
        const agent = try WorkerAgent.init(allocator, platform, false);
        errdefer agent.deinit();

        // Create entangled port pair for message passing
        // Spec: § 10.2.3 "Let inside port be a new MessagePort in inside settings."
        // Spec: § 10.2.3 "Associate the worker with outside port."
        const port_pair = try WorkerPortPair.init(allocator);
        errdefer port_pair.deinit();

        // Copy URL
        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        // Copy name
        const name_copy = if (options.name.len > 0)
            try allocator.dupe(u8, options.name)
        else
            "";
        errdefer if (name_copy.len > 0) allocator.free(name_copy);

        // Configure agent
        try agent.setUrl(script_url);
        agent.setName(name_copy);
        agent.setWorkerType(options.worker_type);

        worker.* = .{
            .agent = agent,
            .port_pair = port_pair,
            .script_url = url_copy,
            .name = name_copy,
            .allocator = allocator,
        };

        // Set up message handler on outside port to forward to worker's on_message callback
        port_pair.outside_port.setOnMessage(handleOutsidePortMessage, worker);

        return worker;
    }

    /// Internal handler for messages arriving on the outside port (from worker)
    ///
    /// Spec: HTML Standard § 10.2.3
    /// "When a message is received on the outside port, the user agent must
    /// queue a global task on the messaging task source to fire a message
    /// event at the Worker object."
    fn handleOutsidePortMessage(port: *WorkerPort, msg: *QueuedMessage, context: ?*anyopaque) void {
        std.log.info("[DedicatedWorker] handleOutsidePortMessage() CALLED", .{});
        std.log.info("[DedicatedWorker]   port: {*}", .{port});
        std.log.info("[DedicatedWorker]   msg: {*}", .{msg});
        std.log.info("[DedicatedWorker]   context: {?*}", .{context});
        const self: *DedicatedWorker = @ptrCast(@alignCast(context));
        std.log.info("[DedicatedWorker]   self (DedicatedWorker): {*}", .{self});
        if (self.on_message) |handler| {
            std.log.info("[DedicatedWorker]   Invoking on_message handler...", .{});
            handler(self, msg);
            std.log.info("[DedicatedWorker]   on_message handler complete", .{});
        } else {
            std.log.warn("[DedicatedWorker]   NO on_message handler set!", .{});
        }
    }

    /// Internal handler for messages arriving on the inside port (from main thread)
    ///
    /// Spec: HTML Standard § 10.2.3
    /// "When a message is received on the inside port, the user agent must
    /// queue a global task on the messaging task source to:
    /// 1. Let messageEvent be a new MessageEvent.
    /// 2. Set messageEvent's data attribute to the message's data.
    /// 3. Set messageEvent's origin attribute to the serialized origin.
    /// 4. Fire messageEvent at the DedicatedWorkerGlobalScope."
    ///
    /// Note: The actual MessageEvent creation and dispatch is done by the
    /// on_inside_message callback, which is set by the WebIDL layer.
    fn handleInsidePortMessage(port: *WorkerPort, msg: *QueuedMessage, context: ?*anyopaque) void {
        std.log.info("[DedicatedWorker] handleInsidePortMessage() CALLED", .{});
        std.log.info("[DedicatedWorker]   port: {*}", .{port});
        std.log.info("[DedicatedWorker]   msg: {*}", .{msg});
        std.log.info("[DedicatedWorker]   context: {?*}", .{context});
        const self: *DedicatedWorker = @ptrCast(@alignCast(context));
        std.log.info("[DedicatedWorker]   self (DedicatedWorker): {*}", .{self});
        if (self.on_inside_message) |handler| {
            std.log.info("[DedicatedWorker]   Invoking on_inside_message handler...", .{});
            handler(self, msg);
            std.log.info("[DedicatedWorker]   on_inside_message handler complete", .{});
        } else {
            std.log.warn("[DedicatedWorker]   NO on_inside_message handler set!", .{});
        }
    }

    /// Set up the inside port message handler
    ///
    /// This enables message reception from the main thread. The WebIDL layer
    /// should call this with a handler that creates and dispatches MessageEvents.
    pub fn setInsideMessageHandler(self: *DedicatedWorker, handler: *const fn (*DedicatedWorker, *QueuedMessage) void) void {
        std.log.info("[DedicatedWorker] setInsideMessageHandler() called", .{});
        std.log.info("[DedicatedWorker]   self: {*}", .{self});
        std.log.info("[DedicatedWorker]   handler: {*}", .{handler});
        self.on_inside_message = handler;
        // Now set up the inside port callback
        std.log.info("[DedicatedWorker]   Setting inside_port.setOnMessage...", .{});
        self.port_pair.inside_port.setOnMessage(handleInsidePortMessage, self);
        std.log.info("[DedicatedWorker]   inside_port callback set", .{});
    }

    /// Clean up resources.
    pub fn deinit(self: *DedicatedWorker) void {
        // Unregister from the threaded worker registry if we were registered
        if (self.thread_state != null) {
            ThreadedWorkerRegistry.unregister(self);
        }

        // Clean up any pending inbox messages that were never flushed
        // (edge case: worker destroyed before thread started)
        for (self.pending_inbox_messages.items) |msg| {
            msg.deinit();
            std.heap.page_allocator.destroy(msg);
        }
        self.pending_inbox_messages.deinit(std.heap.page_allocator);

        // Clean up outside_user_data using the registered cleanup function (if any).
        // This is used by Worker.InternalState to clean up when the DedicatedWorker
        // is destroyed. We use a callback to avoid circular module dependencies.
        if (self.outside_user_data_cleanup_fn) |cleanup_fn| {
            if (self.outside_user_data) |user_data_ptr| {
                cleanup_fn(user_data_ptr);
                self.outside_user_data = null;
            }
        }

        // Clean up port pair (handles disentangling)
        self.port_pair.deinit();

        self.agent.deinit();
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        self.allocator.destroy(self);
    }

    /// Get the outside port for communication from owner (main thread)
    ///
    /// Use this to send messages TO the worker and receive messages FROM the worker.
    pub fn getOutsidePort(self: *DedicatedWorker) *WorkerPort {
        return self.port_pair.outside_port;
    }

    /// Get the inside port for communication from within worker
    ///
    /// This is exposed as the implicit MessagePort on WorkerGlobalScope.
    pub fn getInsidePort(self: *DedicatedWorker) *WorkerPort {
        return self.port_pair.inside_port;
    }

    /// Start the worker.
    ///
    /// This initiates the "run a worker" algorithm without fetching the script.
    /// Use `startAndFetch()` to fetch and execute the script automatically.
    pub fn start(self: *DedicatedWorker) !void {
        try self.agent.start();

        // Add initial owner
        self.agent.addOwner();
    }

    /// Start the worker, fetch, and execute the script.
    ///
    /// This is the complete "run a worker" algorithm per HTML Standard § 10.2.5:
    /// 1. Create worker agent
    /// 2. Fetch the worker script
    /// 3. Execute the script in the worker context
    ///
    /// For classic workers, this executes as a script.
    /// For module workers, this compiles and executes as an ES module.
    pub fn startAndFetch(self: *DedicatedWorker, origin: ?[]const u8) !void {
        try self.agent.start();
        self.agent.addOwner();

        // Fetch the worker script
        var fetched_script = try self.fetchScript(origin);
        defer fetched_script.deinit();

        // Execute the fetched script
        try self.executeScript(fetched_script.source);
    }

    /// Start with V8 context, fetch, and execute the script.
    ///
    /// Creates an isolated V8 context for the worker, fetches the script,
    /// and executes it. This is the preferred way to start workers with V8.
    pub fn startWithContextAndFetch(self: *DedicatedWorker, origin: ?[]const u8) !void {
        try self.agent.startWithContext(
            self.script_url,
            self.agent.data.worker_type,
            self.name,
        );
        self.agent.addOwner();

        // Fetch the worker script
        var fetched_script = try self.fetchScript(origin);
        defer fetched_script.deinit();

        // Execute based on worker type
        if (self.agent.data.worker_type == .module) {
            try self.executeModule(fetched_script.source);
        } else {
            try self.executeScript(fetched_script.source);
        }
    }

    /// Fetch the worker script from the script_url.
    ///
    /// HTML Standard § 10.2.5 step 9:
    /// "Let script be the result of fetching a classic worker script given url..."
    fn fetchScript(self: *DedicatedWorker, origin: ?[]const u8) !FetchedScript {
        return script_fetch.fetchWorkerScript(self.allocator, self.script_url, .{
            .worker_type = self.agent.data.worker_type,
            .origin = origin,
            .credentials = .same_origin,
            .is_import_scripts = false,
        });
    }

    /// Start the worker with V8 context isolation.
    ///
    /// Creates an isolated V8 context for the worker. This is the preferred
    /// way to start workers when V8 is available.
    ///
    /// Spec: HTML Standard § 10.2.5 step 12
    /// "Let realm be a new Realm Record."
    pub fn startWithContext(self: *DedicatedWorker) !void {
        try self.agent.startWithContext(
            self.script_url,
            self.agent.data.worker_type,
            self.name,
        );

        // Add initial owner
        self.agent.addOwner();
    }

    /// Execute a script in the worker's isolated context.
    ///
    /// The script runs in the worker's V8 context, isolated from main thread.
    ///
    /// Spec: HTML Standard § 10.2.5 step 24
    /// "Run the classic script scriptOrModule."
    pub fn executeScript(self: *DedicatedWorker, source: []const u8) !void {
        try self.agent.executeScript(source);
    }

    /// Execute a module in the worker's isolated context.
    ///
    /// Compiles, instantiates, and evaluates an ES module.
    ///
    /// Spec: HTML Standard § 10.2.5 step 24 (for type: "module")
    pub fn executeModule(self: *DedicatedWorker, source: []const u8) !void {
        try self.agent.executeModule(source);
    }

    /// Check if worker has V8 context isolation.
    pub fn hasContext(self: *const DedicatedWorker) bool {
        return self.agent.hasContext();
    }

    /// Terminate the worker (forced shutdown).
    ///
    /// Spec: HTML Standard § 10.2.3.1 terminate()
    /// "The terminate() method, when invoked, must cause the terminate a worker
    /// algorithm to be run on the worker with which the object is associated."
    ///
    /// This immediately aborts execution and cleans up resources.
    pub fn terminate(self: *DedicatedWorker) void {
        self.agent.terminate();
    }

    /// Get the termination state
    pub fn getTerminationState(self: *const DedicatedWorker) TerminationState {
        return self.agent.termination_state;
    }

    /// Register a resource for cleanup on termination
    pub fn registerForCleanup(
        self: *DedicatedWorker,
        resource: *anyopaque,
        cleanup_fn: worker_error.CleanupFn,
    ) !void {
        try self.agent.registerForCleanup(resource, cleanup_fn);
    }

    /// Set the error handler for propagating errors to main thread
    pub fn setErrorHandler(self: *DedicatedWorker, handler: WorkerErrorHandler) void {
        self.agent.setErrorHandler(handler);
    }

    /// Handle an error from the worker script
    pub fn handleError(self: *DedicatedWorker, event: *WorkerErrorEvent) void {
        self.agent.handleError(event);
    }

    /// Post a message to the worker (from the owner/main thread).
    ///
    /// Spec: HTML Standard § 10.2.3.1 postMessage()
    /// "The postMessage(message, transfer) and postMessage(message, options)
    /// methods on Worker objects..."
    ///
    /// The message is serialized using the structured clone algorithm and
    /// queued to the worker's inside port. When the worker's event loop
    /// processes the message, a MessageEvent is dispatched to the worker.
    ///
    /// ## Message Flow
    ///
    /// ```
    /// Main Thread                          Worker Thread
    /// ─────────────                        ─────────────
    /// worker.postMessage(data)
    ///   → structuredSerialize(data)
    ///   → queue to outside_port
    ///                                      inside_port receives
    ///                                        → structuredDeserialize(data)
    ///                                        → create MessageEvent
    ///                                        → dispatch to WorkerGlobalScope
    /// ```
    ///
    /// Note: This overload accepts opaque pointers for compatibility with WebIDL.
    /// The `message` parameter should be a V8 value handle that will be serialized.
    pub fn postMessage(self: *DedicatedWorker, message: ?*anyopaque, transfer: ?*anyopaque) !void {
        _ = transfer; // TODO: Handle transferables

        // Spec step 1: If closing flag is true, return
        if (self.agent.isClosing() or self.agent.isTerminated()) {
            return;
        }

        // Note: This method receives a raw V8 value pointer. The caller (Worker.call_postMessage)
        // is responsible for serializing it to JSValue before calling postMessageTyped.
        // This method is kept for API compatibility but should not be called directly
        // with raw V8 values - use postMessageTyped instead.
        _ = message;
        _ = transfer;

        // For now, post undefined - callers should use postMessageTyped with proper JSValue
        const js_value = JSValue{ .undefined = {} };
        try self.postMessageTyped(&js_value, null);
    }

    /// Post a message to the worker with typed JSValue.
    ///
    /// This is the typed version for internal use and testing.
    pub fn postMessageTyped(self: *DedicatedWorker, message: *const JSValue, transfer: ?[]?*anyopaque) !void {
        // TODO: Handle transfers for threaded workers
        _ = transfer;

        // Spec step 1: If closing flag is true, return
        if (self.agent.isClosing() or self.agent.isTerminated()) {
            return;
        }

        // For threaded workers, use thread-safe inbox instead of port-based messaging.
        // The worker thread reads from thread_state.inbox, not from inside_port.message_queue.
        if (self.thread_state) |thread_state| {
            // Use page_allocator for cross-thread messaging - it's inherently thread-safe.
            // The worker thread will free the message via msg.deinit().
            const cross_thread_allocator = std.heap.page_allocator;

            // Spec step 2: Serialize the message using structured clone
            const serialized = message_channel.structuredSerialize(cross_thread_allocator, message) catch {
                return error.OutOfMemory;
            };

            // Create a SerializedMessage for the thread-safe queue
            const msg = cross_thread_allocator.create(worker_threading.ThreadSafeMessageQueue.SerializedMessage) catch {
                var mutable = @constCast(serialized);
                mutable.deinit();
                cross_thread_allocator.destroy(mutable);
                return error.OutOfMemory;
            };
            msg.* = .{
                .data = serialized.*,
                .transfers = null, // TODO: Handle transfers for threaded workers
                .allocator = cross_thread_allocator,
            };

            // Free the SerializedValue struct (its contents are now owned by msg.data)
            cross_thread_allocator.destroy(serialized);

            // Enqueue to the thread-safe inbox
            dwdebug.print("postMessageTyped: enqueueing to thread_state.inbox for threaded worker\n", .{});
            thread_state.inbox.enqueue(msg) catch {
                dwdebug.print("postMessageTyped: FAILED to enqueue message\n", .{});
                msg.deinit();
                return error.OutOfMemory;
            };
            dwdebug.print("postMessageTyped: message enqueued successfully\n", .{});
            return;
        }

        // Thread state is not yet set - the worker thread hasn't been spawned yet.
        // Queue the message to pending_inbox_messages; it will be flushed to
        // thread_state.inbox when setThreadState() is called.
        dwdebug.print("postMessageTyped: thread_state is null, queueing to pending_inbox_messages\n", .{});

        // Use page_allocator for cross-thread messaging - it's inherently thread-safe.
        const cross_thread_allocator = std.heap.page_allocator;

        // Serialize the message using structured clone
        const serialized = message_channel.structuredSerialize(cross_thread_allocator, message) catch {
            return error.OutOfMemory;
        };

        // Create a SerializedMessage for the pending queue
        const msg = cross_thread_allocator.create(worker_threading.ThreadSafeMessageQueue.SerializedMessage) catch {
            var mutable = @constCast(serialized);
            mutable.deinit();
            cross_thread_allocator.destroy(mutable);
            return error.OutOfMemory;
        };
        msg.* = .{
            .data = serialized.*,
            .transfers = null, // TODO: Handle transfers
            .allocator = cross_thread_allocator,
        };

        // Free the SerializedValue struct (its contents are now owned by msg.data)
        cross_thread_allocator.destroy(serialized);

        // Queue for later delivery when thread_state is set
        self.pending_inbox_messages.append(cross_thread_allocator, msg) catch {
            msg.deinit();
            cross_thread_allocator.destroy(msg);
            return error.OutOfMemory;
        };
        dwdebug.print("postMessageTyped: queued message to pending_inbox_messages (count={})\n", .{self.pending_inbox_messages.items.len});
    }

    // Thread-local storage for pending messages
    // This is a workaround for the V8 HandleScope crash that occurs when modifying
    // outside_port.message_queue while inside a worker V8 callback.
    const PendingMessage = struct {
        port: *message_channel.WorkerPort,
        msg: *message_channel.QueuedMessage,
    };
    threadlocal var pending_messages: std.ArrayListUnmanaged(PendingMessage) = .{};

    /// Post a message from worker back to owner (called from inside the worker).
    ///
    /// This is the reverse direction: worker → main thread.
    /// Called by WorkerGlobalScope.postMessage().
    ///
    /// When running on a separate OS thread (thread_state is set), this uses the
    /// thread-safe outbox queue for cross-thread message passing. The main thread
    /// polls this queue via flushPendingWorkerMessages().
    ///
    /// When running same-thread (tests, single-threaded mode), this uses the
    /// thread-local pending_messages queue as a workaround for V8 HandleScope issues.
    pub fn postMessageFromWorker(self: *DedicatedWorker, message: *const JSValue, transfer: ?[]?*anyopaque) !void {
        dwdebug.print("postMessageFromWorker() called\n", .{});
        _ = transfer;
        if (self.agent.isClosing() or self.agent.isTerminated()) {
            dwdebug.print("postMessageFromWorker() skipped - worker closing/terminated\n", .{});
            return;
        }

        // CRITICAL: For cross-thread messaging, we MUST use a thread-safe allocator.
        // The worker's allocator (self.allocator) may not be safe to use from the main thread.
        // The page allocator is inherently thread-safe (it just maps/unmaps memory pages).
        // Using it ensures that when the main thread calls deinit() on the serialized data,
        // the memory can be safely freed without cross-thread allocator issues.
        const cross_thread_allocator = if (self.thread_state != null)
            std.heap.page_allocator
        else
            self.allocator; // Same-thread mode can use the worker's allocator

        const serialized = try serializeForPostMessage(cross_thread_allocator, message);

        // If we have a thread state, use the thread-safe outbox for cross-thread messaging.
        // This is the correct path when running on a separate OS thread.
        if (self.thread_state) |ts| {
            dwdebug.print("postMessageFromWorker() using thread-safe outbox\n", .{});
            // Create a SerializedMessage for the thread-safe queue
            // Use page_allocator for the wrapper too, ensuring consistency
            const thread_msg = std.heap.page_allocator.create(worker_threading.ThreadSafeMessageQueue.SerializedMessage) catch {
                // Clean up serialized on allocation failure
                var mutable = @constCast(serialized);
                mutable.deinit();
                std.heap.page_allocator.destroy(mutable);
                return error.OutOfMemory;
            };

            // Copy the serialized value into thread_msg (shallow copy - internal pointers shared)
            // Note: serialized.allocator is already page_allocator from serializeForPostMessage above
            thread_msg.* = .{
                .data = serialized.*,
                .transfers = null,
                .allocator = std.heap.page_allocator, // Use page_allocator for thread-safety
            };

            // Free ONLY the original serialized pointer container (not the internal data).
            // The internal data is now owned by thread_msg.data via the shallow copy above.
            // DO NOT call serialized.deinit() - that would free the internal data that
            // thread_msg now references.
            std.heap.page_allocator.destroy(serialized);

            // Enqueue to the thread-safe outbox - main thread will poll this
            // The outbox has a wakeup that will signal the main thread immediately
            dwdebug.print("postMessageFromWorker() enqueuing to outbox at {*}\n", .{&ts.outbox});
            ts.outbox.enqueue(thread_msg) catch |err| {
                dwdebug.print("postMessageFromWorker() FAILED to enqueue: {s}\n", .{@errorName(err)});
                // thread_msg.deinit() frees both the internal data AND the thread_msg struct
                thread_msg.deinit();
                return switch (err) {
                    error.WorkerClosing => error.OutOfMemory, // Map to existing error type
                    else => error.OutOfMemory,
                };
            };
            dwdebug.print("postMessageFromWorker() message enqueued to outbox successfully\n", .{});
            return;
        }

        // Fallback: same-thread mode (tests, single-threaded execution)
        // Use thread-local pending_messages as workaround for V8 HandleScope crash
        // QueuedMessage.init takes ownership of the serialized pointer
        const msg = message_channel.QueuedMessage.init(self.allocator, serialized, null) catch {
            // Clean up serialized on allocation failure
            var mutable = @constCast(serialized);
            mutable.deinit();
            self.allocator.destroy(mutable);
            return error.OutOfMemory;
        };

        pending_messages.append(std.heap.page_allocator, .{
            .port = self.port_pair.outside_port,
            .msg = msg,
        }) catch {
            // msg.deinit() handles freeing both msg and its internal serialized data
            msg.deinit();
            return error.OutOfMemory;
        };
    }

    /// Append a message to the pending queue (public for testing from callback).
    /// This is used to isolate which step of postMessageFromWorker causes the crash.
    pub fn appendPendingMessage(port: *message_channel.WorkerPort, msg: *message_channel.QueuedMessage) !void {
        try pending_messages.append(std.heap.page_allocator, .{
            .port = port,
            .msg = msg,
        });
    }

    /// Flush pending messages to their target ports and dispatch them.
    /// This should be called AFTER exiting the worker isolate.
    ///
    /// Messages are queued during worker script execution via appendPendingMessage()
    /// because appending directly to the port's message_queue while inside a V8
    /// callback causes HandleScope issues. This function appends the queued messages
    /// to their target ports and dispatches them to fire message events.
    pub fn flushPendingMessages() void {
        // First, collect all ports that will receive messages
        var ports_to_dispatch: [16]*message_channel.WorkerPort = undefined;
        var port_count: usize = 0;

        for (pending_messages.items) |pending| {
            // Append message to the port's message queue
            // This is safe now because we're back in the main isolate's context
            pending.port.message_queue.append(pending.port.allocator, pending.msg) catch {
                // Clean up message if append fails
                pending.msg.deinit();
                continue;
            };

            // Track this port for dispatch (avoid duplicates)
            var already_tracked = false;
            for (ports_to_dispatch[0..port_count]) |p| {
                if (p == pending.port) {
                    already_tracked = true;
                    break;
                }
            }
            if (!already_tracked and port_count < ports_to_dispatch.len) {
                ports_to_dispatch[port_count] = pending.port;
                port_count += 1;
            }
        }
        pending_messages.clearRetainingCapacity();

        // Now dispatch messages on all ports that received messages
        for (ports_to_dispatch[0..port_count]) |port| {
            port.dispatchMessages();
        }
    }

    /// Transfer pending messages to port queues without dispatching.
    /// This is safe to call from the worker thread - it only queues messages.
    /// The main thread's event loop will dispatch them later.
    pub fn transferPendingMessagesToQueues() void {
        for (pending_messages.items) |pending| {
            // Append message to the port's message queue
            // The main thread will dispatch these when it runs the event loop
            pending.port.message_queue.append(pending.port.allocator, pending.msg) catch {
                // Clean up message if append fails
                pending.msg.deinit();
                continue;
            };
        }
        pending_messages.clearRetainingCapacity();
    }

    /// Clear all pending messages without flushing them.
    /// This should be called when a worker terminates to prevent memory leaks.
    /// Messages that were queued but not yet flushed will be cleaned up.
    pub fn clearPendingMessages() void {
        for (pending_messages.items) |pending| {
            pending.msg.deinit();
        }
        pending_messages.clearRetainingCapacity();
    }

    /// Set the message handler for messages received from the worker.
    ///
    /// This is called when the worker sends a message via postMessage().
    pub fn setOnMessage(self: *DedicatedWorker, handler: ?*const fn (*DedicatedWorker, *QueuedMessage) void) void {
        self.on_message = handler;
    }

    /// Set user data for callbacks.
    ///
    /// This allows storing a reference to the WebIDL Worker instance
    /// so that callbacks can access it.
    pub fn setUserData(self: *DedicatedWorker, data: ?*anyopaque) void {
        self.user_data = data;
    }

    /// Get user data for callbacks.
    pub fn getUserData(self: *DedicatedWorker) ?*anyopaque {
        return self.user_data;
    }

    /// Set the thread state for cross-thread message passing.
    ///
    /// This should be called when the worker is spawned on a separate OS thread.
    /// The thread state contains thread-safe message queues for communication
    /// between the worker thread and main thread.
    pub fn setThreadState(self: *DedicatedWorker, state: *WorkerThreadState) void {
        dwdebug.print("setThreadState() self={*}, state={*}, state.outbox={*}\n", .{ self, state, &state.outbox });
        self.thread_state = state;
        // Also set the reverse pointer so the thread can access the worker
        state.worker_ptr = self;
        // Register with the global registry so main thread can poll our outbox
        ThreadedWorkerRegistry.register(self);

        // NOTE: We do NOT flush pending messages here!
        // The caller (spawnWorkerThread) must enqueue the script FIRST,
        // then call flushPendingInboxMessages() to flush pending messages.
        // This ensures the worker receives: [script, ...pending messages]
    }

    /// Flush pending inbox messages to the thread_state inbox.
    ///
    /// This MUST be called AFTER the worker script has been enqueued,
    /// so that the worker thread receives messages in correct order:
    /// [script, postMessage1, postMessage2, ...]
    pub fn flushPendingInboxMessages(self: *DedicatedWorker) void {
        const pending_count = self.pending_inbox_messages.items.len;
        if (pending_count == 0) return;

        const thread_state = self.thread_state orelse return;

        dwdebug.print("flushPendingInboxMessages: flushing {} pending messages to thread_state.inbox\n", .{pending_count});
        for (self.pending_inbox_messages.items) |msg| {
            thread_state.inbox.enqueue(msg) catch |err| {
                dwdebug.print("flushPendingInboxMessages: FAILED to enqueue pending message: {}\n", .{err});
                msg.deinit();
                std.heap.page_allocator.destroy(msg);
                continue;
            };
        }
        // Clear the pending queue (messages are now owned by thread_state.inbox)
        self.pending_inbox_messages.clearRetainingCapacity();
        dwdebug.print("flushPendingInboxMessages: pending messages flushed successfully\n", .{});
    }

    /// Get the thread state (if running on a separate thread).
    pub fn getThreadState(self: *DedicatedWorker) ?*WorkerThreadState {
        return self.thread_state;
    }

    /// Enable message dispatch on the outside port.
    ///
    /// Spec: HTML Standard § 9.3.2 start()
    /// Messages are queued until start() is called.
    pub fn startMessageQueue(self: *DedicatedWorker) void {
        self.port_pair.outside_port.start();
    }

    /// Enable message dispatch on the inside port (worker side).
    ///
    /// Called when the worker is ready to receive messages.
    pub fn startWorkerMessageQueue(self: *DedicatedWorker) void {
        self.port_pair.inside_port.start();
    }

    /// Process queued messages on the outside port (worker → main thread).
    ///
    /// This should be called from the main thread context after the worker
    /// has finished executing scripts. Messages are queued during worker
    /// execution but cannot be dispatched immediately because the worker
    /// and main thread use different V8 isolates. Dispatching must happen
    /// on the main isolate.
    ///
    /// Spec: HTML Standard § 10.2.3
    /// "When a message is received on the outside port, the user agent must
    /// queue a global task..."
    pub fn processQueuedMessages(self: *DedicatedWorker) void {
        // Dispatch all messages queued on the outside port
        // The DedicatedWorker.on_message handler will invoke the Worker's onmessage
        const outside_port = self.port_pair.outside_port;

        while (outside_port.message_queue.items.len > 0) {
            const msg = outside_port.message_queue.orderedRemove(0);

            // Use DedicatedWorker.on_message (set via setOnMessage), not WorkerPort.on_message
            // The Worker.zig sets this via dedicated_worker.setOnMessage(handleMessageFromWorkerCallback)
            if (self.on_message) |handler| {
                handler(self, msg);
            }
            // Clean up message after handler returns
            msg.deinit();
        }
    }

    /// Close the worker from inside.
    ///
    /// Spec: HTML Standard § 10.2.4.1
    /// "DedicatedWorkerGlobalScope.close()"
    pub fn close(self: *DedicatedWorker) void {
        self.agent.close();
    }

    /// Get worker name.
    pub fn getName(self: *const DedicatedWorker) []const u8 {
        return self.name;
    }

    /// Get worker URL.
    pub fn getUrl(self: *const DedicatedWorker) []const u8 {
        return self.script_url;
    }

    /// Check if worker is running.
    pub fn isRunning(self: *const DedicatedWorker) bool {
        return self.agent.isRunning();
    }

    /// Check if worker is terminated.
    pub fn isTerminated(self: *const DedicatedWorker) bool {
        return self.agent.isTerminated();
    }

    /// Run a single iteration of the worker's event loop.
    pub fn spin(self: *DedicatedWorker) !void {
        try self.agent.spin();
    }

    /// Run the worker's event loop until stopped.
    pub fn run(self: *DedicatedWorker) !void {
        try self.agent.run();
    }
};

test "DedicatedWorker - init and deinit" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{ .name = "test-worker" },
    );
    defer worker.deinit();

    try std.testing.expectEqualStrings("https://example.com/worker.js", worker.script_url);
    try std.testing.expectEqualStrings("test-worker", worker.name);
    try std.testing.expect(!worker.isRunning());
}

test "DedicatedWorker - lifecycle" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    // Start
    try worker.start();
    try std.testing.expect(worker.isRunning());

    // Terminate
    worker.terminate();
    try std.testing.expect(worker.isTerminated());
}

test "DedicatedWorker - close from inside" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    try worker.start();
    try std.testing.expect(worker.isRunning());

    worker.close();
    try std.testing.expect(!worker.isRunning());
    try std.testing.expect(worker.agent.isClosing());
}

test "DedicatedWorker - startAndFetch with data URL" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    // Use a data URL which can be fetched without network
    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "data:text/javascript,var x = 1;",
        .{},
    );
    defer worker.deinit();

    // startAndFetch should succeed for data URLs
    // Note: It will fetch but script execution requires V8 context
    // So we just test that fetching works, execution will return NoWorkerContext
    worker.startAndFetch(null) catch |err| {
        // Expected: NoWorkerContext because we didn't use startWithContextAndFetch
        try std.testing.expect(err == error.NoWorkerContext);
        return;
    };
    // If we get here, execution succeeded (unlikely without V8)
}

test "DedicatedWorker - port pair is entangled" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    // Verify port pair is created and entangled
    const outside_port = worker.getOutsidePort();
    const inside_port = worker.getInsidePort();

    try std.testing.expect(outside_port.entangled == inside_port);
    try std.testing.expect(inside_port.entangled == outside_port);
}

test "DedicatedWorker - postMessageTyped queues to inside port" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    try worker.start();

    // Create a test message
    var message = JSValue{
        .value_type = .string,
        .data = .{ .string = "hello worker" },
    };

    // Post message to worker (don't start the queue yet)
    try worker.postMessageTyped(&message, null);

    // Message should be queued on inside port
    try std.testing.expect(worker.getInsidePort().message_queue.items.len == 1);
}

test "DedicatedWorker - postMessage fails when terminated" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    try worker.start();
    worker.terminate();

    // Use the opaque pointer version - should silently return without error
    var dummy: u32 = 0;
    try worker.postMessage(&dummy, &dummy);

    // No message should be queued
    try std.testing.expect(worker.getInsidePort().message_queue.items.len == 0);
}

test "DedicatedWorker - bidirectional messaging" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    try worker.start();

    // Main thread → Worker (using typed version)
    var msg1 = JSValue{
        .value_type = .string,
        .data = .{ .string = "to worker" },
    };
    try worker.postMessageTyped(&msg1, null);
    try std.testing.expect(worker.getInsidePort().message_queue.items.len == 1);

    // Worker → Main thread
    var msg2 = JSValue{
        .value_type = .string,
        .data = .{ .string = "from worker" },
    };
    try worker.postMessageFromWorker(&msg2, null);
    try std.testing.expect(worker.getOutsidePort().message_queue.items.len == 1);
}
