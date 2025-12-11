//! Dedicated Worker
//!
//! Spec: HTML Standard § 10.2.3 Dedicated workers and the Worker interface
//! https://html.spec.whatwg.org/#dedicated-workers-and-the-worker-interface
//!
//! A dedicated worker is owned by a single Document or worker.

const std = @import("std");
const Allocator = std.mem.Allocator;

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

    /// User data for callbacks (e.g., reference to WebIDL Worker instance)
    /// This allows callbacks to access the higher-level Worker object.
    user_data: ?*anyopaque = null,

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
    fn handleOutsidePortMessage(port: *WorkerPort, msg: *QueuedMessage, context: ?*anyopaque) void {
        _ = port;
        const self: *DedicatedWorker = @ptrCast(@alignCast(context));
        if (self.on_message) |handler| {
            handler(self, msg);
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
        _ = port;
        const self: *DedicatedWorker = @ptrCast(@alignCast(context));
        if (self.on_inside_message) |handler| {
            handler(self, msg);
        }
    }

    /// Set up the inside port message handler
    ///
    /// This enables message reception from the main thread. The WebIDL layer
    /// should call this with a handler that creates and dispatches MessageEvents.
    pub fn setInsideMessageHandler(self: *DedicatedWorker, handler: *const fn (*DedicatedWorker, *QueuedMessage) void) void {
        self.on_inside_message = handler;
        // Now set up the inside port callback
        self.port_pair.inside_port.setOnMessage(handleInsidePortMessage, self);
    }

    /// Clean up resources.
    pub fn deinit(self: *DedicatedWorker) void {
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
    /// For now, this creates a minimal serialized value; full V8 integration pending.
    pub fn postMessage(self: *DedicatedWorker, message: *const anyopaque, transfer: *const anyopaque) !void {
        _ = transfer;
        _ = message;

        // Spec step 1: If closing flag is true, return
        if (self.agent.isClosing() or self.agent.isTerminated()) {
            return;
        }

        // TODO: Full V8 integration - convert message to JSValue and serialize
        // For now, create a minimal serialized undefined value (using correct structured clone format)
        const serialized = try self.allocator.create(SerializedValue);
        errdefer self.allocator.destroy(serialized);

        serialized.* = .{
            .type = .primitive,
            .allocator = self.allocator,
            .data = .{ .primitive = .{ .undefined = {} } },
        };

        // Post to the outside port → arrives at entangled inside port (worker side)
        self.port_pair.outside_port.postMessage(serialized, null) catch |err| {
            serialized.deinit();
            self.allocator.destroy(serialized);
            return err;
        };
    }

    /// Post a message to the worker with typed JSValue.
    ///
    /// This is the typed version for internal use and testing.
    pub fn postMessageTyped(self: *DedicatedWorker, message: *const JSValue, transfer: ?[]?*anyopaque) !void {
        // Spec step 1: If closing flag is true, return
        if (self.agent.isClosing() or self.agent.isTerminated()) {
            return;
        }

        // Spec step 2: Let serialized be StructuredSerializeWithTransfer(message, transfer)
        const serialized = try serializeForPostMessage(self.allocator, message);
        errdefer {
            var mutable = @constCast(serialized);
            mutable.deinit();
            self.allocator.destroy(mutable);
        }

        // Spec step 3: If that threw an exception, rethrow the exception and abort
        // (handled by error return above)

        // Spec step 4: Queue a global task on DOM manipulation task source with
        // worker's relevant global object to:
        //   - Let targetPort be the port with which this is entangled
        //   - Let data be StructuredDeserialize(serialized, targetRealm, memory)
        //   - Let event be MessageEvent with data set to data
        //   - Dispatch event at targetPort

        // Post to the outside port → arrives at entangled inside port (worker side)
        self.port_pair.outside_port.postMessage(serialized, transfer) catch |err| {
            // Clean up serialized value on failure
            var mutable = @constCast(serialized);
            mutable.deinit();
            self.allocator.destroy(mutable);
            return err;
        };
    }

    /// Post a message from worker back to owner (called from inside the worker).
    ///
    /// This is the reverse direction: worker → main thread.
    /// Called by WorkerGlobalScope.postMessage().
    pub fn postMessageFromWorker(self: *DedicatedWorker, message: *const JSValue, transfer: ?[]?*anyopaque) !void {
        if (self.agent.isClosing() or self.agent.isTerminated()) {
            return;
        }

        const serialized = try serializeForPostMessage(self.allocator, message);
        errdefer {
            var mutable = @constCast(serialized);
            mutable.deinit();
            self.allocator.destroy(mutable);
        }

        // Post to the inside port → arrives at entangled outside port (owner side)
        self.port_pair.inside_port.postMessage(serialized, transfer) catch |err| {
            var mutable = @constCast(serialized);
            mutable.deinit();
            self.allocator.destroy(mutable);
            return err;
        };
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
