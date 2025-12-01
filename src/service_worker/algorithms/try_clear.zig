//! Try Clear Registration Algorithm
//!
//! Attempts to clear a registration that is no longer needed.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#try-clear-registration

const std = @import("std");

const Registration = @import("../registration.zig").Registration;
const RegistrationMap = @import("../registration_map.zig").RegistrationMap;

/// Result of the try clear algorithm.
pub const TryClearResult = enum {
    /// Registration was cleared successfully.
    cleared,
    /// Registration still has workers and cannot be cleared.
    has_workers,
    /// Registration not found in map.
    not_found,
};

/// Try to clear a registration.
///
/// A registration can be cleared when it has no workers (installing, waiting, or active).
///
/// Spec: https://w3c.github.io/ServiceWorker/#try-clear-registration
///
/// Algorithm:
/// 1. If registration's installing worker is not null, return false
/// 2. If registration's waiting worker is not null, return false
/// 3. If registration's active worker is not null, return false
/// 4. Remove registration from scope to registration map
/// 5. Return true
pub fn tryClearRegistration(
    registration_map: *RegistrationMap,
    registration: *Registration,
) TryClearResult {
    // Check if registration has any workers
    if (registration.installing_worker != null or
        registration.waiting_worker != null or
        registration.active_worker != null)
    {
        return .has_workers;
    }

    // Try to remove from the map
    const removed = registration_map.remove(registration.storage_key, registration.scope_url);
    if (removed) {
        return .cleared;
    } else {
        return .not_found;
    }
}

/// Check if a registration can be cleared without actually clearing it.
///
/// This is useful for checking activation conditions.
pub fn canClearRegistration(registration: *const Registration) bool {
    return registration.installing_worker == null and
        registration.waiting_worker == null and
        registration.active_worker == null;
}

// =============================================================================
// Tests
// =============================================================================

test "tryClearRegistration - clears empty registration" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg = try map.getOrCreate("https://example.com", "https://example.com/");

    // Empty registration should be clearable
    const result = tryClearRegistration(&map, reg);
    try std.testing.expectEqual(TryClearResult.cleared, result);
}

test "tryClearRegistration - fails with active worker" {
    const allocator = std.testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg = try map.getOrCreate("https://example.com", "https://example.com/");

    const sw = try @import("../service_worker.zig").ServiceWorker.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer sw.deinit();

    reg.setActiveWorker(sw);

    const result = tryClearRegistration(&map, reg);
    try std.testing.expectEqual(TryClearResult.has_workers, result);
}

test "canClearRegistration" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // Empty = can clear
    try std.testing.expect(canClearRegistration(reg));

    // With worker = cannot clear
    const sw = try @import("../service_worker.zig").ServiceWorker.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer sw.deinit();

    reg.setInstallingWorker(sw);
    try std.testing.expect(!canClearRegistration(reg));
}
