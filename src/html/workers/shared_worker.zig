//! Shared Worker
//!
//! Spec: HTML Standard § 10.2.4 Shared workers and the SharedWorker interface
//! https://html.spec.whatwg.org/#shared-workers-and-the-sharedworker-interface
//!
//! A shared worker can be accessed from multiple Documents or workers.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

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

/// Connection to a shared worker.
///
/// Each connection has its own MessagePort pair.
pub const SharedWorkerConnection = struct {
    /// Port exposed to the connecting context
    outside_port: ?*anyopaque = null,
    /// Port inside the worker for this connection
    inside_port: ?*anyopaque = null,
    /// Whether the connection is active
    active: bool = true,
};

/// Shared Worker implementation.
///
/// Spec: HTML Standard § 10.2.4
/// "A shared worker is a worker that can be shared between multiple browsing
/// contexts or other workers within the same origin."
pub const SharedWorker = struct {
    /// Worker agent (handles event loop and state)
    agent: *WorkerAgent,

    /// Script URL (constructor URL)
    script_url: []const u8,

    /// Worker name
    name: []const u8,

    /// Constructor origin
    constructor_origin: []const u8,

    /// Credentials mode
    credentials: RequestCredentials,

    /// Active connections
    connections: infra.List(SharedWorkerConnection),

    /// Allocator
    allocator: Allocator,

    /// Create a new shared worker.
    ///
    /// Spec: HTML Standard § 10.2.4.1 SharedWorker constructor
    pub fn init(
        allocator: Allocator,
        platform: TimerBackend,
        script_url: []const u8,
        options: WorkerOptions,
        origin: []const u8,
    ) !*SharedWorker {
        const worker = try allocator.create(SharedWorker);
        errdefer allocator.destroy(worker);

        // Create worker agent (shared = true)
        const agent = try WorkerAgent.init(allocator, platform, true);
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

        // Copy origin
        const origin_copy = try allocator.dupe(u8, origin);
        errdefer allocator.free(origin_copy);

        // Configure agent
        try agent.setUrl(script_url);
        agent.setName(name_copy);
        agent.setWorkerType(options.worker_type);

        worker.* = .{
            .agent = agent,
            .script_url = url_copy,
            .name = name_copy,
            .constructor_origin = origin_copy,
            .credentials = options.credentials,
            .connections = infra.List(SharedWorkerConnection).init(allocator),
            .allocator = allocator,
        };

        return worker;
    }

    /// Clean up resources.
    pub fn deinit(self: *SharedWorker) void {
        // Clean up connections
        self.connections.deinit();

        self.agent.deinit();
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        self.allocator.free(self.constructor_origin);
        self.allocator.destroy(self);
    }

    /// Start the worker.
    pub fn start(self: *SharedWorker) !void {
        try self.agent.start();
    }

    /// Connect a new client to this shared worker.
    ///
    /// Spec: HTML Standard § 10.2.4.1 SharedWorker constructor step 17
    /// "If workerGlobalScope is not null, then:
    ///  ...queue a global task on the DOM manipulation task source given
    ///  workerGlobalScope to fire an event named connect..."
    pub fn connect(self: *SharedWorker) !*SharedWorkerConnection {
        // Create connection
        const conn = SharedWorkerConnection{};

        // TODO: Create MessagePort pair
        // - outside_port goes to the connecting context
        // - inside_port fires in the worker's connect event

        try self.connections.append(conn);

        // Add owner
        self.agent.addOwner();

        // Get the connection we just added
        const index = self.connections.len - 1;
        return self.connections.getPtr(index).?;
    }

    /// Disconnect a client.
    pub fn disconnect(self: *SharedWorker, index: usize) void {
        if (self.connections.getPtr(index)) |conn| {
            conn.active = false;
            self.agent.removeOwner();
        }
    }

    /// Close the worker from inside.
    ///
    /// Spec: HTML Standard § 10.2.4.2
    /// "SharedWorkerGlobalScope.close()"
    pub fn close(self: *SharedWorker) void {
        self.agent.close();
    }

    /// Get worker name.
    pub fn getName(self: *const SharedWorker) []const u8 {
        return self.name;
    }

    /// Get worker URL.
    pub fn getUrl(self: *const SharedWorker) []const u8 {
        return self.script_url;
    }

    /// Get constructor origin.
    pub fn getConstructorOrigin(self: *const SharedWorker) []const u8 {
        return self.constructor_origin;
    }

    /// Get number of active connections.
    pub fn getConnectionCount(self: *const SharedWorker) usize {
        var count: usize = 0;
        for (0..self.connections.len) |i| {
            if (self.connections.get(i)) |conn| {
                if (conn.active) count += 1;
            }
        }
        return count;
    }

    /// Check if worker is running.
    pub fn isRunning(self: *const SharedWorker) bool {
        return self.agent.isRunning();
    }

    /// Check if worker is terminated.
    pub fn isTerminated(self: *const SharedWorker) bool {
        return self.agent.isTerminated();
    }

    /// Run a single iteration of the worker's event loop.
    pub fn spin(self: *SharedWorker) !void {
        try self.agent.spin();
    }

    /// Run the worker's event loop until stopped.
    pub fn run(self: *SharedWorker) !void {
        try self.agent.run();
    }

    /// Check if this worker matches the given URL, name, and credentials.
    ///
    /// Used by the shared worker manager to find existing workers.
    pub fn matches(
        self: *const SharedWorker,
        url: []const u8,
        name: []const u8,
        credentials: RequestCredentials,
    ) bool {
        // Must match URL
        if (!std.mem.eql(u8, self.script_url, url)) return false;

        // Must match name
        if (!std.mem.eql(u8, self.name, name)) return false;

        // Must match credentials
        if (self.credentials != credentials) return false;

        // Must not be closing
        if (self.agent.isClosing()) return false;

        return true;
    }
};

test "SharedWorker - init and deinit" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try SharedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/shared.js",
        .{ .name = "shared-test" },
        "https://example.com",
    );
    defer worker.deinit();

    try std.testing.expectEqualStrings("https://example.com/shared.js", worker.script_url);
    try std.testing.expectEqualStrings("shared-test", worker.name);
    try std.testing.expectEqualStrings("https://example.com", worker.constructor_origin);
    try std.testing.expect(!worker.isRunning());
}

test "SharedWorker - lifecycle" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try SharedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/shared.js",
        .{},
        "https://example.com",
    );
    defer worker.deinit();

    // Start
    try worker.start();
    try std.testing.expect(worker.isRunning());

    // Close
    worker.close();
    try std.testing.expect(!worker.isRunning());
}

test "SharedWorker - connections" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try SharedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/shared.js",
        .{},
        "https://example.com",
    );
    defer worker.deinit();

    try worker.start();

    // Add connections
    _ = try worker.connect();
    _ = try worker.connect();
    try std.testing.expectEqual(@as(usize, 2), worker.getConnectionCount());

    // Disconnect one
    worker.disconnect(0);
    try std.testing.expectEqual(@as(usize, 1), worker.getConnectionCount());
}

test "SharedWorker - matches" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try SharedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/shared.js",
        .{ .name = "test", .credentials = .same_origin },
        "https://example.com",
    );
    defer worker.deinit();

    // Exact match
    try std.testing.expect(worker.matches(
        "https://example.com/shared.js",
        "test",
        .same_origin,
    ));

    // Wrong URL
    try std.testing.expect(!worker.matches(
        "https://example.com/other.js",
        "test",
        .same_origin,
    ));

    // Wrong name
    try std.testing.expect(!worker.matches(
        "https://example.com/shared.js",
        "other",
        .same_origin,
    ));

    // Wrong credentials
    try std.testing.expect(!worker.matches(
        "https://example.com/shared.js",
        "test",
        .include,
    ));
}
