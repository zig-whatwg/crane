//! Try Activate Algorithm
//!
//! Checks if a waiting worker can be activated and activates it.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#try-activate

const std = @import("std");

const Registration = @import("../registration.zig").Registration;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const ServiceWorkerState = @import("../types.zig").ServiceWorkerState;

/// Result of the try activate algorithm.
pub const TryActivateResult = enum {
    /// Activation was successful.
    activated,
    /// No waiting worker to activate.
    no_waiting_worker,
    /// Active worker still has controlled clients.
    active_has_clients,
    /// skipWaiting was not called and conditions not met.
    conditions_not_met,
};

/// Context for activation decision.
pub const ActivationContext = struct {
    /// Number of clients controlled by the active worker.
    active_worker_client_count: usize = 0,
};

/// Try to activate the waiting worker.
///
/// A waiting worker can be activated when:
/// 1. There is no active worker, OR
/// 2. The active worker has no controlled clients, OR
/// 3. The waiting worker's skipWaiting flag is set
///
/// Spec: https://w3c.github.io/ServiceWorker/#try-activate
///
/// Algorithm:
/// 1. If registration's waiting worker is null, return
/// 2. If registration's active worker is not null AND
///    registration's active worker's state is "activating", return
/// 3. If registration's active worker is not null AND
///    the number of service worker clients controlled by it is > 0 AND
///    waiting worker's skip waiting flag is not set, return
/// 4. Run Activate Worker algorithm
pub fn tryActivate(
    registration: *Registration,
    context: ActivationContext,
) TryActivateResult {
    // Step 1: Check for waiting worker
    const waiting = registration.waiting_worker orelse {
        return .no_waiting_worker;
    };

    // Step 2 & 3: Check active worker conditions
    if (registration.active_worker) |active| {
        // If active worker is still activating, cannot proceed
        if (active.state == .activating) {
            return .conditions_not_met;
        }

        // If active worker has clients and skipWaiting not set
        if (context.active_worker_client_count > 0 and !waiting.skip_waiting_flag) {
            return .active_has_clients;
        }
    }

    // Step 4: Activate the waiting worker
    activateWorker(registration);
    return .activated;
}

/// Activate the waiting worker.
///
/// This moves the waiting worker to the active position.
fn activateWorker(registration: *Registration) void {
    const waiting = registration.waiting_worker orelse return;

    // Move waiting to active
    // The old active worker (if any) will be marked redundant by caller

    // Clear waiting slot
    registration.waiting_worker = null;

    // Set as active
    registration.active_worker = waiting;

    // Update worker state to activating
    waiting.setState(.activating);
}

/// Check if a waiting worker can be activated without actually activating.
pub fn canActivate(
    registration: *const Registration,
    context: ActivationContext,
) bool {
    const waiting = registration.waiting_worker orelse return false;

    if (registration.active_worker) |active| {
        if (active.state == .activating) {
            return false;
        }
        if (context.active_worker_client_count > 0 and !waiting.skip_waiting_flag) {
            return false;
        }
    }

    return true;
}

// =============================================================================
// Tests
// =============================================================================

test "tryActivate - no waiting worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const result = tryActivate(reg, .{});
    try std.testing.expectEqual(TryActivateResult.no_waiting_worker, result);
}

test "tryActivate - activates when no active worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setState(.installed);

    reg.setWaitingWorker(sw);

    const result = tryActivate(reg, .{});
    try std.testing.expectEqual(TryActivateResult.activated, result);
    try std.testing.expectEqual(sw, reg.active_worker.?);
    try std.testing.expect(reg.waiting_worker == null);
    try std.testing.expectEqual(ServiceWorkerState.activating, sw.state);
}

test "tryActivate - blocked by active with clients" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const active = try ServiceWorker.init(allocator, "https://example.com/sw1.js", .classic);
    defer active.deinit();
    active.setState(.activated);

    const waiting = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer waiting.deinit();
    waiting.setState(.installed);

    reg.setActiveWorker(active);
    reg.setWaitingWorker(waiting);

    // Active has clients, waiting doesn't have skipWaiting
    const result = tryActivate(reg, .{ .active_worker_client_count = 1 });
    try std.testing.expectEqual(TryActivateResult.active_has_clients, result);
}

test "tryActivate - activates with skipWaiting despite clients" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const active = try ServiceWorker.init(allocator, "https://example.com/sw1.js", .classic);
    defer active.deinit();
    active.setState(.activated);

    const waiting = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer waiting.deinit();
    waiting.setState(.installed);
    waiting.skip_waiting_flag = true; // Skip waiting!

    reg.setActiveWorker(active);
    reg.setWaitingWorker(waiting);

    // Active has clients, but waiting has skipWaiting
    const result = tryActivate(reg, .{ .active_worker_client_count = 1 });
    try std.testing.expectEqual(TryActivateResult.activated, result);
}

test "canActivate" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // No waiting = cannot activate
    try std.testing.expect(!canActivate(reg, .{}));

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    reg.setWaitingWorker(sw);

    // Has waiting, no active = can activate
    try std.testing.expect(canActivate(reg, .{}));
}
