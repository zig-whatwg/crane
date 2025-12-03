//! Workers Module Tests
//!
//! Tests for the Web Workers implementation (HTML Standard § 10).

const std = @import("std");
const testing = std.testing;

const html_core = @import("html_core");
const workers = html_core.workers;
const platform = @import("platform");
const timer_backend = platform.timer_backend;

// ============================================
// WorkerType Tests
// ============================================

test "WorkerType - fromString" {
    try testing.expectEqual(workers.WorkerType.classic, workers.WorkerType.fromString("classic").?);
    try testing.expectEqual(workers.WorkerType.module, workers.WorkerType.fromString("module").?);
    try testing.expect(workers.WorkerType.fromString("invalid") == null);
}

test "WorkerType - toString" {
    try testing.expectEqualStrings("classic", workers.WorkerType.classic.toString());
    try testing.expectEqualStrings("module", workers.WorkerType.module.toString());
}

// ============================================
// WorkerOptions Tests
// ============================================

test "WorkerOptions - defaults" {
    const opts = workers.WorkerOptions{};
    try testing.expectEqual(workers.WorkerType.classic, opts.worker_type);
    try testing.expectEqual(workers.types.RequestCredentials.same_origin, opts.credentials);
    try testing.expectEqualStrings("", opts.name);
}

// ============================================
// DedicatedWorker Tests
// ============================================

test "DedicatedWorker - init and deinit" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try workers.DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{ .name = "test-worker" },
    );
    defer worker.deinit();

    try testing.expectEqualStrings("https://example.com/worker.js", worker.getUrl());
    try testing.expectEqualStrings("test-worker", worker.getName());
    try testing.expect(!worker.isRunning());
    try testing.expect(!worker.isTerminated());
}

test "DedicatedWorker - lifecycle start and terminate" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try workers.DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    // Initially not running
    try testing.expect(!worker.isRunning());

    // Start
    try worker.start();
    try testing.expect(worker.isRunning());

    // Terminate
    worker.terminate();
    try testing.expect(worker.isTerminated());
    try testing.expect(!worker.isRunning());
}

test "DedicatedWorker - close from inside" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try workers.DedicatedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/worker.js",
        .{},
    );
    defer worker.deinit();

    try worker.start();
    try testing.expect(worker.isRunning());

    // Close (from inside the worker)
    worker.close();
    try testing.expect(!worker.isRunning());
    try testing.expect(worker.agent.isClosing());
}

// ============================================
// SharedWorker Tests
// ============================================

test "SharedWorker - init and deinit" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try workers.SharedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/shared.js",
        .{ .name = "shared-test" },
        "https://example.com",
    );
    defer worker.deinit();

    try testing.expectEqualStrings("https://example.com/shared.js", worker.getUrl());
    try testing.expectEqualStrings("shared-test", worker.getName());
    try testing.expectEqualStrings("https://example.com", worker.getConstructorOrigin());
    try testing.expect(!worker.isRunning());
}

test "SharedWorker - lifecycle" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try workers.SharedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/shared.js",
        .{},
        "https://example.com",
    );
    defer worker.deinit();

    // Start
    try worker.start();
    try testing.expect(worker.isRunning());

    // Close
    worker.close();
    try testing.expect(!worker.isRunning());
}

test "SharedWorker - connections" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try workers.SharedWorker.init(
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
    try testing.expectEqual(@as(usize, 2), worker.getConnectionCount());

    // Disconnect one
    worker.disconnect(0);
    try testing.expectEqual(@as(usize, 1), worker.getConnectionCount());
}

test "SharedWorker - matches" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const worker = try workers.SharedWorker.init(
        allocator,
        mock.backend(),
        "https://example.com/shared.js",
        .{ .name = "test", .credentials = .same_origin },
        "https://example.com",
    );
    defer worker.deinit();

    // Exact match
    try testing.expect(worker.matches(
        "https://example.com/shared.js",
        "test",
        .same_origin,
    ));

    // Wrong URL
    try testing.expect(!worker.matches(
        "https://example.com/other.js",
        "test",
        .same_origin,
    ));

    // Wrong name
    try testing.expect(!worker.matches(
        "https://example.com/shared.js",
        "other",
        .same_origin,
    ));

    // Wrong credentials
    try testing.expect(!worker.matches(
        "https://example.com/shared.js",
        "test",
        .include,
    ));
}

// ============================================
// SharedWorkerManager Tests
// ============================================

test "SharedWorkerManager - init and deinit" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = workers.SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    try testing.expectEqual(@as(usize, 0), manager.getActiveCount());
}

test "SharedWorkerManager - getOrCreate creates new worker" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = workers.SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    const result = try manager.getOrCreate(
        "https://example.com/shared.js",
        "test",
        .{ .name = "test" },
        "https://example.com",
    );

    try testing.expect(result.is_new);
    try testing.expectEqual(@as(usize, 1), manager.getActiveCount());
}

test "SharedWorkerManager - getOrCreate returns existing worker" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = workers.SharedWorkerManager.init(allocator, mock.backend());
    defer manager.deinit();

    // Create first worker
    const result1 = try manager.getOrCreate(
        "https://example.com/shared.js",
        "test",
        .{ .name = "test" },
        "https://example.com",
    );
    try testing.expect(result1.is_new);

    // Request same worker
    const result2 = try manager.getOrCreate(
        "https://example.com/shared.js",
        "test",
        .{ .name = "test" },
        "https://example.com",
    );
    try testing.expect(!result2.is_new);
    try testing.expectEqual(result1.worker, result2.worker);
    try testing.expectEqual(@as(usize, 1), manager.getActiveCount());
}

test "SharedWorkerManager - different names create different workers" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    var manager = workers.SharedWorkerManager.init(allocator, mock.backend());
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

    try testing.expectEqual(@as(usize, 2), manager.getActiveCount());
}

// ============================================
// WorkerLocation Tests
// ============================================

test "WorkerLocation - basic URL parsing" {
    const allocator = testing.allocator;

    const location = try workers.WorkerLocation.init(
        allocator,
        "https://example.com:8080/path/to/worker.js?query=value#fragment",
    );
    defer location.deinit();

    try testing.expectEqualStrings(
        "https://example.com:8080/path/to/worker.js?query=value#fragment",
        location.getHref(),
    );
    try testing.expectEqualStrings("https:", location.getProtocol());
    try testing.expectEqualStrings("example.com:8080", location.getHost());
    try testing.expectEqualStrings("example.com", location.getHostname());
    try testing.expectEqualStrings("8080", location.getPort());
    try testing.expectEqualStrings("/path/to/worker.js", location.getPathname());
    try testing.expectEqualStrings("?query=value", location.getSearch());
    try testing.expectEqualStrings("#fragment", location.getHash());
    try testing.expectEqualStrings("https://example.com:8080", location.getOrigin());
}

test "WorkerLocation - simple URL" {
    const allocator = testing.allocator;

    const location = try workers.WorkerLocation.init(
        allocator,
        "https://example.com/worker.js",
    );
    defer location.deinit();

    try testing.expectEqualStrings("https://example.com/worker.js", location.getHref());
    try testing.expectEqualStrings("https:", location.getProtocol());
    try testing.expectEqualStrings("example.com", location.getHost());
    try testing.expectEqualStrings("", location.getPort());
}

// ============================================
// WorkerNavigator Tests
// ============================================

test "WorkerNavigator - init and deinit" {
    const allocator = testing.allocator;

    const navigator = try workers.WorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Check NavigatorID
    try testing.expectEqualStrings("Mozilla", navigator.getAppCodeName());
    try testing.expectEqualStrings("Netscape", navigator.getAppName());
    try testing.expectEqualStrings("Gecko", navigator.getProduct());

    // Check NavigatorLanguage
    try testing.expectEqualStrings("en-US", navigator.getLanguage());

    // Check NavigatorOnLine
    try testing.expect(navigator.isOnLine());

    // Check NavigatorConcurrentHardware
    try testing.expect(navigator.getHardwareConcurrency() >= 1);
}

test "WorkerNavigator - online status toggle" {
    const allocator = testing.allocator;

    const navigator = try workers.WorkerNavigator.init(allocator);
    defer navigator.deinit();

    try testing.expect(navigator.isOnLine());

    navigator.setOnLine(false);
    try testing.expect(!navigator.isOnLine());

    navigator.setOnLine(true);
    try testing.expect(navigator.isOnLine());
}

// ============================================
// WorkerAgent Tests
// ============================================

test "WorkerAgent - init and deinit" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const agent = try workers.WorkerAgent.init(allocator, mock.backend(), false);
    defer agent.deinit();

    try testing.expect(!agent.is_shared);
    try testing.expect(!agent.isClosing());
    try testing.expect(!agent.isTerminated());
    try testing.expectEqual(workers.WorkerState.pending, agent.data.state);
}

test "WorkerAgent - lifecycle" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const agent = try workers.WorkerAgent.init(allocator, mock.backend(), false);
    defer agent.deinit();

    // Start
    try agent.start();
    try testing.expect(agent.isRunning());
    try testing.expect(!agent.isClosing());

    // Close
    agent.close();
    try testing.expect(agent.isClosing());
    try testing.expect(!agent.isRunning());

    // Terminate
    agent.terminate();
    try testing.expect(agent.isTerminated());
}

test "WorkerAgent - owner management" {
    const allocator = testing.allocator;
    const mock = try timer_backend.MockTimerBackend.init(allocator);
    defer mock.allocator.destroy(mock);

    const agent = try workers.WorkerAgent.init(allocator, mock.backend(), false);
    defer agent.deinit();

    try testing.expectEqual(@as(usize, 0), agent.data.owner_set_count);

    agent.addOwner();
    try testing.expectEqual(@as(usize, 1), agent.data.owner_set_count);

    agent.addOwner();
    try testing.expectEqual(@as(usize, 2), agent.data.owner_set_count);

    agent.removeOwner();
    try testing.expectEqual(@as(usize, 1), agent.data.owner_set_count);
}
