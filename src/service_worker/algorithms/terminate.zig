//! Terminate Service Worker Algorithm
//!
//! Handles the termination of a service worker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#terminate-service-worker

const std = @import("std");

const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const ServiceWorkerGlobalScope = @import("../global/service_worker_global_scope.zig").ServiceWorkerGlobalScope;
const ServiceWorkerState = @import("../types.zig").ServiceWorkerState;

/// Result of the terminate algorithm.
pub const TerminateResult = enum {
    /// Termination succeeded.
    terminated,
    /// Worker was already terminated.
    already_terminated,
    /// Worker is not running.
    not_running,
};

/// Context for the terminate algorithm.
pub const TerminateContext = struct {
    /// Callback for aborting pending fetches.
    abort_fetches: ?*const fn (worker: *ServiceWorker) void = null,

    /// Callback for clearing timers.
    clear_timers: ?*const fn (worker: *ServiceWorker) void = null,

    /// Callback for detaching global scope.
    detach_global: ?*const fn (worker: *ServiceWorker) void = null,
};

/// Terminate a service worker.
///
/// Spec: https://w3c.github.io/ServiceWorker/#terminate-service-worker
///
/// Algorithm:
/// 1. If worker's state is "redundant", return (already terminated)
/// 2. Abort all pending fetch operations
/// 3. Clear all timers
/// 4. Detach from global scope
/// 5. Run any termination cleanup
/// 6. Set running flag to false
pub fn terminate(
    worker: *ServiceWorker,
    context: TerminateContext,
) TerminateResult {
    // Step 1: Check if already terminated
    if (worker.state == .redundant) {
        return .already_terminated;
    }

    // Check if worker is even running
    // In our implementation, we track this with the running flag
    if (!worker.isRunning()) {
        return .not_running;
    }

    // Step 2: Abort pending fetches
    if (context.abort_fetches) |abort| {
        abort(worker);
    }

    // Step 3: Clear timers
    if (context.clear_timers) |clear| {
        clear(worker);
    }

    // Step 4: Detach global scope
    if (context.detach_global) |detach| {
        detach(worker);
    }

    // Step 5 & 6: Mark as not running
    worker.setRunning(false);

    return .terminated;
}

/// Force terminate a service worker and mark as redundant.
///
/// This is used when the worker needs to be completely removed.
pub fn forceTerminate(worker: *ServiceWorker) void {
    // Stop running
    worker.setRunning(false);

    // Mark as redundant
    worker.setState(.redundant);
}

/// Check if a worker can be terminated.
pub fn canTerminate(worker: *const ServiceWorker) bool {
    // Cannot terminate if already redundant
    if (worker.state == .redundant) {
        return false;
    }

    // Cannot terminate if not running
    if (!worker.isRunning()) {
        return false;
    }

    return true;
}

// =============================================================================
// Tests
// =============================================================================

test "terminate - not running" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    // Worker is not running by default

    const result = terminate(sw, .{});
    try std.testing.expectEqual(TerminateResult.not_running, result);
}

test "terminate - success" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setRunning(true);
    sw.setState(.activated);

    const result = terminate(sw, .{});
    try std.testing.expectEqual(TerminateResult.terminated, result);
    try std.testing.expect(!sw.isRunning());
}

test "terminate - already terminated" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setState(.redundant);
    sw.setRunning(true);

    const result = terminate(sw, .{});
    try std.testing.expectEqual(TerminateResult.already_terminated, result);
}

test "terminate - with callbacks" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setRunning(true);
    sw.setState(.activated);

    const State = struct {
        var abort_called: bool = false;
        var clear_called: bool = false;
        var detach_called: bool = false;
    };

    const ctx = TerminateContext{
        .abort_fetches = struct {
            fn abort(_: *ServiceWorker) void {
                State.abort_called = true;
            }
        }.abort,
        .clear_timers = struct {
            fn clear(_: *ServiceWorker) void {
                State.clear_called = true;
            }
        }.clear,
        .detach_global = struct {
            fn detach(_: *ServiceWorker) void {
                State.detach_called = true;
            }
        }.detach,
    };

    const result = terminate(sw, ctx);
    try std.testing.expectEqual(TerminateResult.terminated, result);
    try std.testing.expect(State.abort_called);
    try std.testing.expect(State.clear_called);
    try std.testing.expect(State.detach_called);
}

test "forceTerminate" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setRunning(true);
    sw.setState(.activated);

    forceTerminate(sw);

    try std.testing.expect(!sw.isRunning());
    try std.testing.expectEqual(ServiceWorkerState.redundant, sw.state);
}

test "canTerminate" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    // Not running = cannot terminate
    try std.testing.expect(!canTerminate(sw));

    sw.setRunning(true);
    sw.setState(.activated);
    try std.testing.expect(canTerminate(sw));

    sw.setState(.redundant);
    try std.testing.expect(!canTerminate(sw));
}
