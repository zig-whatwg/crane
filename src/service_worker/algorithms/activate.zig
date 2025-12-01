//! Activate Algorithm
//!
//! Handles the activation of a service worker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#activation

const std = @import("std");

const Registration = @import("../registration.zig").Registration;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const ServiceWorkerState = @import("../types.zig").ServiceWorkerState;
const ExtendableEvent = @import("../events/extendable_event.zig").ExtendableEvent;

/// Result of the activate algorithm.
pub const ActivateResult = enum {
    /// Activation succeeded.
    activated,
    /// Activation failed due to event error.
    failed_event_error,
    /// No waiting worker to activate.
    no_worker,
    /// Worker already activating or activated.
    already_active,
};

/// Context for the activate algorithm.
pub const ActivateContext = struct {
    /// Callback for dispatching the activate event.
    /// Returns true if the event was handled successfully.
    dispatch_activate_event: ?*const fn (worker: *ServiceWorker, event: *ExtendableEvent) bool = null,

    /// Callback for waiting for an ExtendableEvent to complete.
    /// Returns true if all promises resolved successfully.
    wait_for_event: ?*const fn (event: *ExtendableEvent) bool = null,

    /// Callback for updating clients' active service worker.
    update_clients: ?*const fn (worker: *ServiceWorker) void = null,
};

/// Run the activate algorithm.
///
/// Spec: https://w3c.github.io/ServiceWorker/#activation
///
/// Algorithm:
/// 1. Let worker be registration's waiting worker
/// 2. If worker is null, return
/// 3. If registration's active worker is not null:
///    a. Set its state to "redundant"
///    b. Clear it
/// 4. Set registration's active worker to worker
/// 5. Clear waiting worker slot
/// 6. Set worker's state to "activating"
/// 7. Fire "statechange" event
/// 8. Fire "activate" event on worker's global scope
/// 9. Wait for event to complete
/// 10. If event has errors, the worker is still activated but errors are reported
/// 11. Set worker's state to "activated"
/// 12. Update all service worker clients that match registration's scope
pub fn activate(
    registration: *Registration,
    context: ActivateContext,
    allocator: std.mem.Allocator,
) !ActivateResult {
    // Step 1 & 2: Get waiting worker
    const worker = registration.waiting_worker orelse {
        return .no_worker;
    };

    // Check if already activating/activated
    if (worker.state == .activating or worker.state == .activated) {
        return .already_active;
    }

    // Step 3: Handle existing active worker
    if (registration.active_worker) |old_active| {
        old_active.setState(.redundant);
        registration.clearActiveWorker();
    }

    // Step 4 & 5: Move waiting to active
    registration.clearWaitingWorker();
    registration.setActiveWorker(worker);

    // Step 6: Set state to activating
    worker.setState(.activating);

    // Step 7 & 8: Fire activate event
    var event = ExtendableEvent.init(allocator, "activate");
    defer event.deinit();

    var event_success = true;
    if (context.dispatch_activate_event) |dispatch| {
        event_success = dispatch(worker, &event);
    }

    // Step 9: Wait for event to complete
    if (context.wait_for_event) |wait| {
        event_success = event_success and wait(&event);
    }

    // Step 10: Even if event has errors, we continue activation
    // but we should log the error. For now, we'll just continue.

    // Step 11: Set state to activated
    worker.setState(.activated);

    // Step 12: Update clients
    if (context.update_clients) |update| {
        update(worker);
    }

    if (!event_success) {
        // Note: Spec says activation continues even on error
        // but we might want to track this for debugging
        return .activated;
    }

    return .activated;
}

/// Run the activate algorithm synchronously (for testing).
///
/// This is a simplified version that doesn't involve event dispatch.
pub fn activateSync(registration: *Registration) ActivateResult {
    const worker = registration.waiting_worker orelse {
        return .no_worker;
    };

    if (worker.state == .activating or worker.state == .activated) {
        return .already_active;
    }

    // Handle existing active worker
    if (registration.active_worker) |old_active| {
        old_active.setState(.redundant);
        registration.clearActiveWorker();
    }

    // Move waiting to active
    registration.clearWaitingWorker();
    registration.setActiveWorker(worker);

    // Set state to activating then activated
    worker.setState(.activating);
    worker.setState(.activated);

    return .activated;
}

// =============================================================================
// Tests
// =============================================================================

test "activate - no worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const result = try activate(reg, .{}, allocator);
    try std.testing.expectEqual(ActivateResult.no_worker, result);
}

test "activateSync - success" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setState(.installed);

    reg.setWaitingWorker(sw);

    const result = activateSync(reg);
    try std.testing.expectEqual(ActivateResult.activated, result);

    // Worker should be in active slot
    try std.testing.expect(reg.waiting_worker == null);
    try std.testing.expectEqual(sw, reg.active_worker.?);
    try std.testing.expectEqual(ServiceWorkerState.activated, sw.state);
}

test "activateSync - replaces old active worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const old_sw = try ServiceWorker.init(allocator, "https://example.com/sw1.js", .classic);
    defer old_sw.deinit();
    old_sw.setState(.activated);

    const new_sw = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer new_sw.deinit();
    new_sw.setState(.installed);

    reg.setActiveWorker(old_sw);
    reg.setWaitingWorker(new_sw);

    const result = activateSync(reg);
    try std.testing.expectEqual(ActivateResult.activated, result);

    // Old worker should be redundant
    try std.testing.expectEqual(ServiceWorkerState.redundant, old_sw.state);

    // New worker should be active
    try std.testing.expectEqual(new_sw, reg.active_worker.?);
    try std.testing.expectEqual(ServiceWorkerState.activated, new_sw.state);
}

test "activate - with context callbacks" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();
    sw.setState(.installed);

    reg.setWaitingWorker(sw);

    // Track if callbacks were called
    const State = struct {
        var dispatch_called: bool = false;
        var wait_called: bool = false;
        var update_called: bool = false;
    };

    const ctx = ActivateContext{
        .dispatch_activate_event = struct {
            fn dispatch(_: *ServiceWorker, _: *ExtendableEvent) bool {
                State.dispatch_called = true;
                return true;
            }
        }.dispatch,
        .wait_for_event = struct {
            fn wait(_: *ExtendableEvent) bool {
                State.wait_called = true;
                return true;
            }
        }.wait,
        .update_clients = struct {
            fn update(_: *ServiceWorker) void {
                State.update_called = true;
            }
        }.update,
    };

    const result = try activate(reg, ctx, allocator);
    try std.testing.expectEqual(ActivateResult.activated, result);
    try std.testing.expect(State.dispatch_called);
    try std.testing.expect(State.wait_called);
    try std.testing.expect(State.update_called);
}
