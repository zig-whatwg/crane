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

// MessagePort pair infrastructure
const message_channel = @import("message_channel.zig");
const WorkerPortPair = message_channel.WorkerPortPair;
const WorkerPort = message_channel.WorkerPort;

const platform_mod = @import("platform");
const timer_backend = platform_mod.timer_backend;
const TimerBackend = timer_backend.TimerBackend;

/// Connection to a shared worker.
///
/// Each connection has its own MessagePort pair.
///
/// Spec: HTML Standard § 10.2.4.1 SharedWorker constructor
/// "Let port be a new MessagePort object..."
/// "Entangle port with inside port."
pub const SharedWorkerConnection = struct {
    /// Port pair for this connection (owns both ports)
    port_pair: ?*WorkerPortPair = null,

    /// Whether the connection is active
    active: bool = true,

    /// Get the outside port (exposed to the connecting context)
    /// This is the port returned by sharedWorker.port
    pub fn getOutsidePort(self: *const SharedWorkerConnection) ?*WorkerPort {
        if (self.port_pair) |pair| {
            return pair.outside_port;
        }
        return null;
    }

    /// Get the inside port (for the worker's connect event)
    /// This is the port passed in the connect event's ports array
    pub fn getInsidePort(self: *const SharedWorkerConnection) ?*WorkerPort {
        if (self.port_pair) |pair| {
            return pair.inside_port;
        }
        return null;
    }

    /// Clean up the connection
    pub fn deinit(self: *SharedWorkerConnection, allocator: Allocator) void {
        if (self.port_pair) |pair| {
            pair.deinit();
        }
        _ = allocator; // Port pair handles its own cleanup
    }
};

/// Callback type for connect events
///
/// Called when a new connection is established, allowing the caller
/// to fire the connect event on the SharedWorkerGlobalScope.
pub const ConnectEventCallback = *const fn (*SharedWorker, *SharedWorkerConnection, ?*anyopaque) void;

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

    /// Connect callback (for firing connect events)
    on_connect_callback: ?ConnectEventCallback = null,
    on_connect_context: ?*anyopaque = null,

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
        // Clean up connections and their port pairs
        for (0..self.connections.len) |i| {
            if (self.connections.getPtr(i)) |conn| {
                conn.deinit(self.allocator);
            }
        }
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
    ///
    /// Creates a MessagePort pair:
    /// - outside_port: returned to the connecting context (sharedWorker.port)
    /// - inside_port: passed in the connect event's ports array
    pub fn connect(self: *SharedWorker) !*SharedWorkerConnection {
        // Spec Step: "Let port be a new MessagePort object..."
        // Create MessagePort pair for this connection
        const port_pair = try WorkerPortPair.init(self.allocator);
        errdefer port_pair.deinit();

        // Create connection with the port pair
        const conn = SharedWorkerConnection{
            .port_pair = port_pair,
            .active = true,
        };

        try self.connections.append(conn);

        // Add owner
        self.agent.addOwner();

        // Get the connection we just added
        const index = self.connections.len - 1;
        const connection = self.connections.getPtr(index).?;

        // Queue connect event firing (if callback is set)
        // The actual event dispatch is handled by the caller through
        // the ConnectEventCallback mechanism
        if (self.on_connect_callback) |callback| {
            callback(self, connection, self.on_connect_context);
        }

        return connection;
    }

    /// Set connect event callback
    ///
    /// This callback is invoked when a new connection is made, passing
    /// the inside port so the caller can fire the connect event.
    pub fn setConnectCallback(self: *SharedWorker, callback: ConnectEventCallback, context: ?*anyopaque) void {
        self.on_connect_callback = callback;
        self.on_connect_context = context;
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

test "SharedWorker - connection has MessagePort pair" {
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

    // Connect creates a MessagePort pair
    const conn = try worker.connect();

    // Connection should have both ports
    try std.testing.expect(conn.port_pair != null);

    const outside_port = conn.getOutsidePort();
    const inside_port = conn.getInsidePort();

    try std.testing.expect(outside_port != null);
    try std.testing.expect(inside_port != null);

    // Ports should be entangled
    try std.testing.expect(outside_port.?.entangled == inside_port.?);
    try std.testing.expect(inside_port.?.entangled == outside_port.?);
}

test "SharedWorker - multiple connections have separate ports" {
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

    // Create two connections
    const conn1 = try worker.connect();
    const conn2 = try worker.connect();

    // Each connection should have its own port pair
    try std.testing.expect(conn1.port_pair != conn2.port_pair);

    // Each port pair should have unique ports
    const port1_outside = conn1.getOutsidePort();
    const port2_outside = conn2.getOutsidePort();

    try std.testing.expect(port1_outside != port2_outside);
    try std.testing.expect(port1_outside.?.id != port2_outside.?.id);
}

test "SharedWorker - connect callback fires" {
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

    // Track callback invocations
    const Context = struct {
        var callback_count: usize = 0;
        var last_connection: ?*SharedWorkerConnection = null;
    };
    Context.callback_count = 0;
    Context.last_connection = null;

    // Set up connect callback
    worker.setConnectCallback(struct {
        fn callback(_: *SharedWorker, conn: *SharedWorkerConnection, _: ?*anyopaque) void {
            Context.callback_count += 1;
            Context.last_connection = conn;
        }
    }.callback, null);

    // Connect should trigger callback
    const conn = try worker.connect();
    try std.testing.expectEqual(@as(usize, 1), Context.callback_count);
    try std.testing.expect(Context.last_connection == conn);

    // Second connection should trigger again
    _ = try worker.connect();
    try std.testing.expectEqual(@as(usize, 2), Context.callback_count);
}
