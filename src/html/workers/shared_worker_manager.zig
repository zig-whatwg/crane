//! Shared Worker Manager
//!
//! Spec: HTML Standard § 10.2.4.1
//! https://html.spec.whatwg.org/#shared-workers-and-the-sharedworker-interface
//!
//! The shared worker manager maintains a registry of all SharedWorkerGlobalScope
//! objects and handles matching existing workers to new connection requests.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

const types = @import("types.zig");
const WorkerOptions = types.WorkerOptions;
const RequestCredentials = types.RequestCredentials;

const shared_worker_mod = @import("shared_worker.zig");
const SharedWorker = shared_worker_mod.SharedWorker;

const platform_mod = @import("platform");
const timer_backend = platform_mod.timer_backend;
const TimerBackend = timer_backend.TimerBackend;

/// Shared Worker Manager.
///
/// Spec: HTML Standard § 10.2.4.1
/// "A user agent has an associated shared worker manager which is the result
/// of starting a new parallel queue."
pub const SharedWorkerManager = struct {
    /// Registry of active shared workers
    workers: infra.List(*SharedWorker),

    /// Platform timer backend
    platform: TimerBackend,

    /// Allocator
    allocator: Allocator,

    /// Initialize the shared worker manager.
    pub fn init(allocator: Allocator, platform: TimerBackend) SharedWorkerManager {
        return .{
            .workers = infra.List(*SharedWorker).init(allocator),
            .platform = platform,
            .allocator = allocator,
        };
    }

    /// Clean up all resources.
    pub fn deinit(self: *SharedWorkerManager) void {
        // Terminate and deinit all workers
        for (0..self.workers.len) |i| {
            if (self.workers.get(i)) |worker| {
                worker.deinit();
            }
        }
        self.workers.deinit();
    }

    /// Get or create a shared worker for the given URL and name.
    ///
    /// Spec: HTML Standard § 10.2.4.1 SharedWorker constructor steps 11-18
    pub fn getOrCreate(
        self: *SharedWorkerManager,
        url: []const u8,
        name: []const u8,
        options: WorkerOptions,
        origin: []const u8,
    ) !struct { worker: *SharedWorker, is_new: bool } {
        // Step 14: Look for existing worker
        for (0..self.workers.len) |i| {
            if (self.workers.get(i)) |existing| {
                if (existing.matches(url, name, options.credentials)) {
                    // Step 14: workerGlobalScope is not null
                    // Verify type/credentials match (step 15)
                    if (existing.agent.data.worker_type != options.worker_type) {
                        return error.TypeMismatch;
                    }
                    if (existing.credentials != options.credentials) {
                        return error.CredentialsMismatch;
                    }

                    return .{ .worker = existing, .is_new = false };
                }
            }
        }

        // Step 18: Otherwise, create new worker
        const worker = try SharedWorker.init(
            self.allocator,
            self.platform,
            url,
            options,
            origin,
        );
        errdefer worker.deinit();

        try self.workers.append(worker);

        return .{ .worker = worker, .is_new = true };
    }

    /// Find an existing shared worker by URL and name.
    pub fn find(
        self: *const SharedWorkerManager,
        url: []const u8,
        name: []const u8,
        credentials: RequestCredentials,
    ) ?*SharedWorker {
        for (0..self.workers.len) |i| {
            if (self.workers.get(i)) |worker| {
                if (worker.matches(url, name, credentials)) {
                    return worker;
                }
            }
        }
        return null;
    }

    /// Remove terminated workers from the registry.
    pub fn cleanup(self: *SharedWorkerManager) void {
        var i: usize = 0;
        while (i < self.workers.len) {
            if (self.workers.get(i)) |worker| {
                if (worker.isTerminated()) {
                    worker.deinit();
                    _ = self.workers.remove(i) catch continue;
                    // Don't increment i since we removed an element
                    continue;
                }
            }
            i += 1;
        }
    }

    /// Get count of active workers.
    pub fn getActiveCount(self: *const SharedWorkerManager) usize {
        var count: usize = 0;
        for (0..self.workers.len) |i| {
            if (self.workers.get(i)) |worker| {
                if (!worker.isTerminated()) {
                    count += 1;
                }
            }
        }
        return count;
    }

    /// Terminate all workers.
    pub fn terminateAll(self: *SharedWorkerManager) void {
        for (0..self.workers.len) |i| {
            if (self.workers.get(i)) |worker| {
                worker.close();
            }
        }
    }
};

test "SharedWorkerManager - init and deinit" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.getActiveCount());
}

test "SharedWorkerManager - getOrCreate creates new worker" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    const result = try manager.getOrCreate(
        "https://example.com/shared.js",
        "test",
        .{ .name = "test" },
        "https://example.com",
    );

    try std.testing.expect(result.is_new);
    try std.testing.expectEqual(@as(usize, 1), manager.getActiveCount());
}

test "SharedWorkerManager - getOrCreate returns existing worker" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    // Create first worker
    const result1 = try manager.getOrCreate(
        "https://example.com/shared.js",
        "test",
        .{ .name = "test" },
        "https://example.com",
    );
    try std.testing.expect(result1.is_new);

    // Request same worker
    const result2 = try manager.getOrCreate(
        "https://example.com/shared.js",
        "test",
        .{ .name = "test" },
        "https://example.com",
    );
    try std.testing.expect(!result2.is_new);
    try std.testing.expectEqual(result1.worker, result2.worker);
    try std.testing.expectEqual(@as(usize, 1), manager.getActiveCount());
}

test "SharedWorkerManager - different names create different workers" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    // Create first worker
    _ = try manager.getOrCreate(
        "https://example.com/shared.js",
        "worker1",
        .{ .name = "worker1" },
        "https://example.com",
    );

    // Create second worker with different name
    _ = try manager.getOrCreate(
        "https://example.com/shared.js",
        "worker2",
        .{ .name = "worker2" },
        "https://example.com",
    );

    try std.testing.expectEqual(@as(usize, 2), manager.getActiveCount());
}

test "SharedWorkerManager - find" {
    const allocator = std.testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    // Create worker
    const result = try manager.getOrCreate(
        "https://example.com/shared.js",
        "test",
        .{ .name = "test" },
        "https://example.com",
    );

    // Find it
    const found = manager.find(
        "https://example.com/shared.js",
        "test",
        .same_origin,
    );
    try std.testing.expect(found != null);
    try std.testing.expectEqual(result.worker, found.?);

    // Not found with different name
    const not_found = manager.find(
        "https://example.com/shared.js",
        "other",
        .same_origin,
    );
    try std.testing.expect(not_found == null);
}
