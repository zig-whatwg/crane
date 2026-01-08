//! Service Worker Lifecycle Tests
//!
//! Tests for the service worker state machine and lifecycle transitions.

const std = @import("std");
const testing = std.testing;

const sw = @import("service_worker");
const ServiceWorker = sw.ServiceWorker;
const ServiceWorkerState = sw.ServiceWorkerState;
const Registration = sw.Registration;
const algorithms = sw.algorithms;

// =============================================================================
// State Transition Tests
// =============================================================================

test "ServiceWorkerState - valid transitions" {
    // parsed -> installing
    try testing.expect(ServiceWorkerState.parsed.canTransitionTo(.installing));

    // installing -> installed | redundant
    try testing.expect(ServiceWorkerState.installing.canTransitionTo(.installed));
    try testing.expect(ServiceWorkerState.installing.canTransitionTo(.redundant));

    // installed -> activating | redundant
    try testing.expect(ServiceWorkerState.installed.canTransitionTo(.activating));
    try testing.expect(ServiceWorkerState.installed.canTransitionTo(.redundant));

    // activating -> activated | redundant
    try testing.expect(ServiceWorkerState.activating.canTransitionTo(.activated));
    try testing.expect(ServiceWorkerState.activating.canTransitionTo(.redundant));

    // activated -> redundant
    try testing.expect(ServiceWorkerState.activated.canTransitionTo(.redundant));
}

test "ServiceWorkerState - invalid transitions" {
    // Cannot skip states
    try testing.expect(!ServiceWorkerState.parsed.canTransitionTo(.activated));
    try testing.expect(!ServiceWorkerState.parsed.canTransitionTo(.installed));

    // Cannot go backwards
    try testing.expect(!ServiceWorkerState.activated.canTransitionTo(.installing));
    try testing.expect(!ServiceWorkerState.installed.canTransitionTo(.parsed));

    // Redundant is terminal
    try testing.expect(!ServiceWorkerState.redundant.canTransitionTo(.parsed));
    try testing.expect(!ServiceWorkerState.redundant.canTransitionTo(.installing));
}

// =============================================================================
// ServiceWorker Lifecycle Tests
// =============================================================================

test "ServiceWorker - initial state is parsed" {
    const allocator = testing.allocator;

    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    try testing.expectEqual(ServiceWorkerState.parsed, worker.state);
}

test "ServiceWorker - setState bypasses validation" {
    const allocator = testing.allocator;

    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    // setState allows any state change
    worker.setState(.activated);
    try testing.expectEqual(ServiceWorkerState.activated, worker.state);

    worker.setState(.redundant);
    try testing.expectEqual(ServiceWorkerState.redundant, worker.state);
}

test "ServiceWorker - transitionTo validates transitions" {
    const allocator = testing.allocator;

    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    // Valid transition
    try worker.transitionTo(.installing);
    try testing.expectEqual(ServiceWorkerState.installing, worker.state);

    // Invalid transition should fail
    const result = worker.transitionTo(.activated);
    try testing.expectError(error.InvalidStateTransition, result);
}

// =============================================================================
// Install Algorithm Tests
// =============================================================================

test "install - moves worker from installing to waiting" {
    const allocator = testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();

    reg.setInstallingWorker(worker);

    const result = algorithms.installSync(reg);
    try testing.expectEqual(algorithms.InstallResult.installed, result);

    // Worker should be in waiting slot now
    try testing.expect(reg.installing_worker == null);
    try testing.expectEqual(worker, reg.waiting_worker.?);
    try testing.expectEqual(ServiceWorkerState.installed, worker.state);
}

test "install - no worker returns no_worker" {
    const allocator = testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const result = algorithms.installSync(reg);
    try testing.expectEqual(algorithms.InstallResult.no_worker, result);
}

// =============================================================================
// Activate Algorithm Tests
// =============================================================================

test "activate - moves worker from waiting to active" {
    const allocator = testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();
    worker.setState(.installed);

    reg.setWaitingWorker(worker);

    const result = algorithms.activateSync(reg);
    try testing.expectEqual(algorithms.ActivateResult.activated, result);

    // Worker should be in active slot now
    try testing.expect(reg.waiting_worker == null);
    try testing.expectEqual(worker, reg.active_worker.?);
    try testing.expectEqual(ServiceWorkerState.activated, worker.state);
}

test "activate - replaces old active worker" {
    const allocator = testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const old_worker = try ServiceWorker.init(allocator, "https://example.com/sw-old.js", .classic);
    defer old_worker.deinit();
    old_worker.setState(.activated);
    reg.setActiveWorker(old_worker);

    const new_worker = try ServiceWorker.init(allocator, "https://example.com/sw-new.js", .classic);
    defer new_worker.deinit();
    new_worker.setState(.installed);
    reg.setWaitingWorker(new_worker);

    const result = algorithms.activateSync(reg);
    try testing.expectEqual(algorithms.ActivateResult.activated, result);

    // Old worker should be redundant
    try testing.expectEqual(ServiceWorkerState.redundant, old_worker.state);

    // New worker should be active
    try testing.expectEqual(new_worker, reg.active_worker.?);
    try testing.expectEqual(ServiceWorkerState.activated, new_worker.state);
}

// =============================================================================
// Full Lifecycle Tests
// =============================================================================

test "full lifecycle - register -> install -> activate" {
    const allocator = testing.allocator;

    // Step 1: Create registration
    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // Step 2: Create worker in parsed state
    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();
    try testing.expectEqual(ServiceWorkerState.parsed, worker.state);

    // Step 3: Set as installing worker
    reg.setInstallingWorker(worker);
    try testing.expectEqual(worker, reg.installing_worker.?);

    // Step 4: Run install
    const install_result = algorithms.installSync(reg);
    try testing.expectEqual(algorithms.InstallResult.installed, install_result);
    try testing.expectEqual(ServiceWorkerState.installed, worker.state);
    try testing.expectEqual(worker, reg.waiting_worker.?);

    // Step 5: Run activate
    const activate_result = algorithms.activateSync(reg);
    try testing.expectEqual(algorithms.ActivateResult.activated, activate_result);
    try testing.expectEqual(ServiceWorkerState.activated, worker.state);
    try testing.expectEqual(worker, reg.active_worker.?);
}

// =============================================================================
// Skip Waiting Tests
// =============================================================================

test "skipWaiting allows immediate activation" {
    const allocator = testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // Create an active worker (simulating existing SW)
    const active = try ServiceWorker.init(allocator, "https://example.com/sw1.js", .classic);
    defer active.deinit();
    active.setState(.activated);
    reg.setActiveWorker(active);

    // Create a waiting worker with skipWaiting
    const waiting = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer waiting.deinit();
    waiting.setState(.installed);
    waiting.setSkipWaiting();
    reg.setWaitingWorker(waiting);

    // tryActivate should succeed even though active has "clients"
    const ctx = algorithms.ActivationContext{
        .active_worker_client_count = 5, // Has clients
    };

    const result = algorithms.tryActivate(reg, ctx);
    try testing.expectEqual(algorithms.TryActivateResult.activated, result);
}

// =============================================================================
// Memory Safety Tests
// =============================================================================

test "lifecycle - no memory leaks" {
    const allocator = testing.allocator;

    // Create many workers and registrations
    for (0..10) |_| {
        const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");

        const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);

        reg.setInstallingWorker(worker);
        _ = algorithms.installSync(reg);
        _ = algorithms.activateSync(reg);

        worker.deinit();
        reg.deinit();
    }

    // If we get here without leaks detected, test passes
}
