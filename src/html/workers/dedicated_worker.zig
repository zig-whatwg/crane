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

const platform_mod = @import("platform");
const timer_backend = platform_mod.timer_backend;
const TimerBackend = timer_backend.TimerBackend;

// Note: MessagePort communication is handled through the WebIDL interfaces module.
// The ports (outside_port, inside_port) will be set up when wiring this to the
// WebIDL Worker interface implementation.

/// Dedicated Worker implementation.
///
/// Spec: HTML Standard § 10.2.3
/// "A dedicated worker is a worker which can only be accessed from the script
/// that created it."
pub const DedicatedWorker = struct {
    /// Worker agent (handles event loop and state)
    agent: *WorkerAgent,

    /// Outside port (for communicating with owner)
    /// Spec: "Each Worker object has an associated outside port"
    outside_port: ?*anyopaque = null,

    /// Inside port (for communicating from within worker)
    /// This is the port exposed as the implicit MessagePort
    inside_port: ?*anyopaque = null,

    /// Script URL
    script_url: []const u8,

    /// Worker name (for debugging)
    name: []const u8,

    /// Allocator
    allocator: Allocator,

    /// Create a new dedicated worker.
    ///
    /// Spec: HTML Standard § 10.2.3.1 Constructor
    /// "new Worker(scriptURL, options)"
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
            .script_url = url_copy,
            .name = name_copy,
            .allocator = allocator,
        };

        return worker;
    }

    /// Clean up resources.
    pub fn deinit(self: *DedicatedWorker) void {
        // Clean up ports
        // TODO: Properly disentangle and close ports

        self.agent.deinit();
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        self.allocator.destroy(self);
    }

    /// Start the worker.
    ///
    /// This initiates the "run a worker" algorithm.
    pub fn start(self: *DedicatedWorker) !void {
        try self.agent.start();

        // Add initial owner
        self.agent.addOwner();
    }

    /// Terminate the worker.
    ///
    /// Spec: HTML Standard § 10.2.3.1 terminate()
    /// "The terminate() method, when invoked, must cause the terminate a worker
    /// algorithm to be run on the worker with which the object is associated."
    pub fn terminate(self: *DedicatedWorker) void {
        self.agent.terminate();
    }

    /// Post a message to the worker.
    ///
    /// Spec: HTML Standard § 10.2.3.1 postMessage()
    /// "The postMessage(message, transfer) and postMessage(message, options)
    /// methods on Worker objects..."
    pub fn postMessage(self: *DedicatedWorker, message: *const anyopaque, transfer: ?*const anyopaque) !void {
        _ = transfer;
        _ = message;

        if (self.agent.isClosing() or self.agent.isTerminated()) {
            return;
        }

        // TODO: Use the outside_port to post message
        // This requires:
        // 1. StructuredSerialize the message
        // 2. Post to the entangled inside_port
        // 3. Queue a task on the worker's event loop to dispatch message event
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
