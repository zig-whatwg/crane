//! Get Newest Worker Algorithm
//!
//! Returns the most recent worker from a registration.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#get-newest-worker

const std = @import("std");

const Registration = @import("../registration.zig").Registration;
const ServiceWorker = @import("../service_worker.zig").ServiceWorker;

/// Get the newest worker from a registration.
///
/// Returns installing > waiting > active, in that order.
///
/// Spec: https://w3c.github.io/ServiceWorker/#get-newest-worker
///
/// Algorithm:
/// 1. If registration's installing worker is not null, return it
/// 2. If registration's waiting worker is not null, return it
/// 3. If registration's active worker is not null, return it
/// 4. Return null
pub fn getNewestWorker(registration: *const Registration) ?*ServiceWorker {
    if (registration.installing_worker) |w| return w;
    if (registration.waiting_worker) |w| return w;
    if (registration.active_worker) |w| return w;
    return null;
}

// =============================================================================
// Tests
// =============================================================================

test "getNewestWorker - no workers" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try std.testing.expect(getNewestWorker(reg) == null);
}

test "getNewestWorker - prefers installing" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw1 = try ServiceWorker.init(allocator, "https://example.com/sw1.js", .classic);
    defer sw1.deinit();
    const sw2 = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer sw2.deinit();
    const sw3 = try ServiceWorker.init(allocator, "https://example.com/sw3.js", .classic);
    defer sw3.deinit();

    reg.setActiveWorker(sw1);
    reg.setWaitingWorker(sw2);
    reg.setInstallingWorker(sw3);

    try std.testing.expectEqual(sw3, getNewestWorker(reg).?);
}

test "getNewestWorker - waiting over active" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw1 = try ServiceWorker.init(allocator, "https://example.com/sw1.js", .classic);
    defer sw1.deinit();
    const sw2 = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer sw2.deinit();

    reg.setActiveWorker(sw1);
    reg.setWaitingWorker(sw2);

    try std.testing.expectEqual(sw2, getNewestWorker(reg).?);
}
