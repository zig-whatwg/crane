//! Install Algorithm
//!
//! Handles the installation of a service worker.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#installation

const std = @import("std");

const Registration = @import("../registration.zig").Registration;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;
const ServiceWorkerState = @import("../types.zig").ServiceWorkerState;
const ExtendableEvent = @import("../events/extendable_event.zig").ExtendableEvent;

/// Result of the install algorithm.
pub const InstallResult = enum {
    /// Installation succeeded.
    installed,
    /// Installation failed due to event error.
    failed_event_error,
    /// Installation failed due to timeout.
    failed_timeout,
    /// Worker was aborted during installation.
    aborted,
    /// No installing worker to install.
    no_worker,
};

/// Context for the install algorithm.
pub const InstallContext = struct {
    /// Callback for dispatching the install event.
    /// Returns true if the event was handled successfully.
    dispatch_install_event: ?*const fn (worker: *ServiceWorker, event: *ExtendableEvent) bool = null,

    /// Callback for waiting for an ExtendableEvent to complete.
    /// Returns true if all promises resolved successfully.
    wait_for_event: ?*const fn (event: *ExtendableEvent) bool = null,
};

/// Run the install algorithm.
///
/// Spec: https://w3c.github.io/ServiceWorker/#installation
///
/// Algorithm:
/// 1. Let worker be registration's installing worker
/// 2. If worker is null, return
/// 3. Set worker's state to "installing"
/// 4. Fire "statechange" event on worker (via spec's update-state algorithm)
/// 5. Fire "install" event on worker's global scope
/// 6. Wait for event to complete
/// 7. If event has errors:
///    a. Set worker's state to "redundant"
///    b. Clear installing worker
///    c. Try to clear registration
///    d. Return failure
/// 8. Set worker's state to "installed"
/// 9. Move worker to waiting slot
/// 10. Fire "statechange" event
/// 11. Try to activate
pub fn install(
    registration: *Registration,
    context: InstallContext,
    allocator: std.mem.Allocator,
) !InstallResult {
    // Step 1 & 2: Get installing worker
    const worker = registration.installing_worker orelse {
        return .no_worker;
    };

    // Step 3: Set state to installing
    worker.setState(.installing);

    // Step 4 & 5: Fire install event
    var event = ExtendableEvent.init(allocator, "install");
    defer event.deinit();

    var event_success = true;
    if (context.dispatch_install_event) |dispatch| {
        event_success = dispatch(worker, &event);
    }

    // Step 6: Wait for event to complete
    if (context.wait_for_event) |wait| {
        event_success = event_success and wait(&event);
    }

    // Also check the event's error state
    event_success = event_success and !event.has_error;

    // Step 7: Handle failure
    if (!event_success) {
        worker.setState(.redundant);
        registration.clearInstallingWorker();
        return .failed_event_error;
    }

    // Step 8: Set state to installed
    worker.setState(.installed);

    // Step 9: Move to waiting slot
    registration.clearInstallingWorker();
    registration.setWaitingWorker(worker);

    return .installed;
}

/// Run the install algorithm synchronously (for testing).
///
/// This is a simplified version that doesn't involve event dispatch.
pub fn installSync(registration: *Registration) InstallResult {
    const worker = registration.installing_worker orelse {
        return .no_worker;
    };

    // Set state to installing
    worker.setState(.installing);

    // Set state to installed
    worker.setState(.installed);

    // Move to waiting slot
    registration.clearInstallingWorker();
    registration.setWaitingWorker(worker);

    return .installed;
}

// =============================================================================
// Tests
// =============================================================================

test "install - no worker" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const result = try install(reg, .{}, allocator);
    try std.testing.expectEqual(InstallResult.no_worker, result);
}

test "installSync - success" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    reg.setInstallingWorker(sw);

    const result = installSync(reg);
    try std.testing.expectEqual(InstallResult.installed, result);

    // Worker should be in waiting slot
    try std.testing.expect(reg.installing_worker == null);
    try std.testing.expectEqual(sw, reg.waiting_worker.?);
    try std.testing.expectEqual(ServiceWorkerState.installed, sw.state);
}

test "install - with context callbacks" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    reg.setInstallingWorker(sw);

    // Create context with success callbacks
    const ctx = InstallContext{
        .dispatch_install_event = struct {
            fn dispatch(_: *ServiceWorker, _: *ExtendableEvent) bool {
                return true;
            }
        }.dispatch,
        .wait_for_event = struct {
            fn wait(_: *ExtendableEvent) bool {
                return true;
            }
        }.wait,
    };

    const result = try install(reg, ctx, allocator);
    try std.testing.expectEqual(InstallResult.installed, result);
    try std.testing.expectEqual(ServiceWorkerState.installed, sw.state);
}

test "install - fails on event error" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    reg.setInstallingWorker(sw);

    // Create context with failing callbacks
    const ctx = InstallContext{
        .dispatch_install_event = struct {
            fn dispatch(_: *ServiceWorker, _: *ExtendableEvent) bool {
                return false; // Fail!
            }
        }.dispatch,
    };

    const result = try install(reg, ctx, allocator);
    try std.testing.expectEqual(InstallResult.failed_event_error, result);
    try std.testing.expectEqual(ServiceWorkerState.redundant, sw.state);
    try std.testing.expect(reg.installing_worker == null);
}
