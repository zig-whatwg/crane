//! Worker Agent
//!
//! Spec: HTML Standard § 10.1.4
//! https://html.spec.whatwg.org/#worker-event-loop
//!
//! Each worker runs in its own agent (conceptually its own thread/isolate).
//! This module provides the agent abstraction for workers.

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const WorkerData = types.WorkerData;
const WorkerState = types.WorkerState;
const WorkerType = types.WorkerType;

// Import event loop
const event_loop_mod = @import("../event_loop/event_loop.zig");
const EventLoop = event_loop_mod.EventLoop;
const EventLoopType = event_loop_mod.EventLoopType;

const platform_mod = @import("platform");
const timer_backend = platform_mod.timer_backend;
const TimerBackend = timer_backend.TimerBackend;

/// Worker Agent - runs a worker's code in isolation.
///
/// Spec: HTML Standard § 10.1.4
/// "A similar-origin window agent, dedicated worker agent, shared worker agent,
/// or service worker agent is an agent"
pub const WorkerAgent = struct {
    /// Worker data
    data: WorkerData,

    /// The worker's event loop
    event_loop: EventLoop,

    /// Whether this is a shared worker
    is_shared: bool,

    /// Allocator
    allocator: Allocator,

    /// Platform timer backend
    platform: TimerBackend,

    /// Initialize a new worker agent.
    pub fn init(allocator: Allocator, platform: TimerBackend, is_shared: bool) !*WorkerAgent {
        const agent = try allocator.create(WorkerAgent);
        errdefer allocator.destroy(agent);

        agent.* = .{
            .data = WorkerData.init(allocator),
            .event_loop = try EventLoop.init(allocator, .worker, platform),
            .is_shared = is_shared,
            .allocator = allocator,
            .platform = platform,
        };

        return agent;
    }

    /// Free all resources.
    pub fn deinit(self: *WorkerAgent) void {
        self.data.deinit();
        self.event_loop.deinit();
        self.allocator.destroy(self);
    }

    /// Set worker URL.
    pub fn setUrl(self: *WorkerAgent, url: []const u8) !void {
        try self.data.setUrl(url);
    }

    /// Set worker name.
    pub fn setName(self: *WorkerAgent, name: []const u8) void {
        self.data.name = name;
    }

    /// Set worker type.
    pub fn setWorkerType(self: *WorkerAgent, worker_type: WorkerType) void {
        self.data.worker_type = worker_type;
    }

    /// Start the worker.
    ///
    /// Spec: HTML Standard § 10.2.5 step 15
    /// "Event loop: Run the responsible event loop specified by inside settings
    /// until it is destroyed."
    pub fn start(self: *WorkerAgent) !void {
        self.data.state = .running;
        self.data.closing = false;
    }

    /// Run a single iteration of the worker event loop.
    pub fn spin(self: *WorkerAgent) !void {
        if (self.data.closing) {
            return;
        }
        try self.event_loop.spin();
    }

    /// Run the worker event loop until stopped.
    pub fn run(self: *WorkerAgent) !void {
        if (self.data.state != .running) {
            return error.WorkerNotRunning;
        }
        try self.event_loop.run();
    }

    /// Close the worker.
    ///
    /// Spec: HTML Standard § 10.2.4.1
    /// "To close a worker, given a WorkerGlobalScope object workerGlobal"
    pub fn close(self: *WorkerAgent) void {
        // Step 1: Discard any tasks that have been added to workerGlobal's
        // relevant agent's event loop's task queues.
        // (Handled by setting closing flag - new tasks won't be processed)

        // Step 2: Set workerGlobal's closing flag to true.
        self.data.closing = true;
        self.data.state = .closing;

        // Stop the event loop
        self.event_loop.stop();
    }

    /// Terminate the worker.
    ///
    /// Spec: HTML Standard § 10.2.5 "terminate a worker"
    pub fn terminate(self: *WorkerAgent) void {
        // Step 1: Set the worker's WorkerGlobalScope object's closing flag to true.
        self.data.closing = true;

        // Step 2: If there are any tasks queued in the WorkerGlobalScope object's
        // relevant agent's event loop's task queues, discard them without processing them.
        // (Handled by event loop when running is false)
        self.event_loop.stop();

        // Step 3: Abort the script currently running in the worker.
        // (Not directly possible - we rely on closing flag checks)

        // Step 4: If the worker's WorkerGlobalScope object is actually a
        // DedicatedWorkerGlobalScope object, empty the port message queue of
        // the port that the worker's implicit port is entangled with.
        // (TODO: Implement port cleanup)

        self.data.state = .terminated;
    }

    /// Check if worker is closing.
    pub fn isClosing(self: *const WorkerAgent) bool {
        return self.data.closing;
    }

    /// Check if worker is terminated.
    pub fn isTerminated(self: *const WorkerAgent) bool {
        return self.data.state == .terminated;
    }

    /// Check if worker is running.
    pub fn isRunning(self: *const WorkerAgent) bool {
        return self.data.state == .running and !self.data.closing;
    }

    /// Check if worker is actively needed.
    ///
    /// Spec: HTML Standard § 10.1.4.4
    /// "A WorkerGlobalScope global is actively needed if..."
    pub fn isActivelyNeeded(self: *const WorkerAgent) bool {
        // For now, simplified check: if we have owners and not closing
        return self.data.owner_set_count > 0 and !self.data.closing;
    }

    /// Check if worker is protected.
    ///
    /// Spec: HTML Standard § 10.1.4.4
    /// "A WorkerGlobalScope global is protected if..."
    pub fn isProtected(self: *const WorkerAgent) bool {
        if (!self.isActivelyNeeded()) return false;
        if (self.is_shared) return true;
        // For dedicated workers, check if there are ports or timers
        return self.event_loop.hasPendingWork();
    }

    /// Check if worker is permissible.
    ///
    /// Spec: HTML Standard § 10.1.4.4
    /// "A WorkerGlobalScope global is permissible if..."
    pub fn isPermissible(self: *const WorkerAgent) bool {
        if (self.data.owner_set_count > 0) return true;
        // Shared workers have a timeout grace period
        if (self.is_shared) {
            // TODO: Implement between-loads shared worker timeout
            return true;
        }
        return false;
    }

    /// Add an owner.
    pub fn addOwner(self: *WorkerAgent) void {
        self.data.owner_set_count += 1;
    }

    /// Remove an owner.
    pub fn removeOwner(self: *WorkerAgent) void {
        if (self.data.owner_set_count > 0) {
            self.data.owner_set_count -= 1;
        }

        // Check if we should close
        if (self.data.owner_set_count == 0 and !self.is_shared) {
            // Dedicated worker with no owners should close
            self.close();
        }
    }
};

test "WorkerAgent - init and deinit" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const agent = try WorkerAgent.init(allocator, mock.backend(), false);
    defer agent.deinit();

    try std.testing.expect(!agent.is_shared);
    try std.testing.expect(!agent.isClosing());
    try std.testing.expectEqual(WorkerState.pending, agent.data.state);
}

test "WorkerAgent - lifecycle" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const agent = try WorkerAgent.init(allocator, mock.backend(), false);
    defer agent.deinit();

    // Start
    try agent.start();
    try std.testing.expect(agent.isRunning());
    try std.testing.expect(!agent.isClosing());

    // Close
    agent.close();
    try std.testing.expect(agent.isClosing());
    try std.testing.expect(!agent.isRunning());

    // Terminate
    agent.terminate();
    try std.testing.expect(agent.isTerminated());
}

test "WorkerAgent - owner management" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const agent = try WorkerAgent.init(allocator, mock.backend(), false);
    defer agent.deinit();

    try std.testing.expectEqual(@as(usize, 0), agent.data.owner_set_count);

    agent.addOwner();
    try std.testing.expectEqual(@as(usize, 1), agent.data.owner_set_count);

    agent.addOwner();
    try std.testing.expectEqual(@as(usize, 2), agent.data.owner_set_count);

    agent.removeOwner();
    try std.testing.expectEqual(@as(usize, 1), agent.data.owner_set_count);
}
