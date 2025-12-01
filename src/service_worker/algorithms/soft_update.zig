//! Soft Update Algorithm
//!
//! Schedules an update without user interaction when registration is stale.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#soft-update

const std = @import("std");

const Registration = @import("../registration.zig").Registration;
const Job = @import("../job.zig").Job;
const ScopeToJobQueueMap = @import("../job.zig").ScopeToJobQueueMap;

/// Result of the soft update algorithm.
pub const SoftUpdateResult = enum {
    /// Update job was scheduled.
    scheduled,
    /// Registration is not stale, no update needed.
    not_stale,
    /// Registration has no workers to update.
    no_workers,
};

/// Perform a soft update check.
///
/// A soft update is scheduled when:
/// 1. The registration has a newest worker
/// 2. The registration is stale (last check > 24 hours ago)
///
/// Spec: https://w3c.github.io/ServiceWorker/#soft-update
///
/// Algorithm:
/// 1. Let newestWorker be the result of running Get Newest Worker
/// 2. If newestWorker is null, return
/// 3. If registration is not stale, return
/// 4. Schedule Job with job type "update"
pub fn softUpdate(
    registration: *Registration,
    job_queue_map: *ScopeToJobQueueMap,
) !SoftUpdateResult {
    // Step 1 & 2: Check for newest worker
    if (registration.getNewestWorker() == null) {
        return .no_workers;
    }

    // Step 3: Check if stale
    if (!registration.isStale()) {
        return .not_stale;
    }

    // Step 4: Schedule update job (don't force bypass cache)
    const job = try Job.createUpdateJob(
        job_queue_map.allocator,
        registration.storage_key,
        registration.scope_url,
        false, // Don't force bypass cache for soft updates
    );

    const queue = try job_queue_map.getOrCreateQueue(registration.scope_url);
    try queue.enqueue(job);

    return .scheduled;
}

/// Check if a soft update would be scheduled without actually scheduling.
pub fn shouldSoftUpdate(registration: *const Registration) bool {
    if (registration.getNewestWorker() == null) {
        return false;
    }
    return registration.isStale();
}

// =============================================================================
// Tests
// =============================================================================

test "softUpdate - not stale" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try @import("../service_worker.zig").ServiceWorker.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer sw.deinit();
    reg.setActiveWorker(sw);

    // Mark as recently checked
    reg.markChecked();

    var job_queue_map = ScopeToJobQueueMap.init(allocator);
    defer job_queue_map.deinit();

    const result = try softUpdate(reg, &job_queue_map);
    try std.testing.expectEqual(SoftUpdateResult.not_stale, result);
}

test "softUpdate - no workers" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    var job_queue_map = ScopeToJobQueueMap.init(allocator);
    defer job_queue_map.deinit();

    const result = try softUpdate(reg, &job_queue_map);
    try std.testing.expectEqual(SoftUpdateResult.no_workers, result);
}

test "softUpdate - schedules when stale" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const sw = try @import("../service_worker.zig").ServiceWorker.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer sw.deinit();
    reg.setActiveWorker(sw);

    // Make it stale
    reg.last_update_check_time = std.time.timestamp() - (Registration.STALE_THRESHOLD_SECONDS + 1);

    var job_queue_map = ScopeToJobQueueMap.init(allocator);
    defer {
        // Clean up the job that was created
        if (job_queue_map.getQueue("https://example.com/")) |queue| {
            while (queue.dequeue()) |job| {
                job.deinit();
            }
        }
        job_queue_map.deinit();
    }

    const result = try softUpdate(reg, &job_queue_map);
    try std.testing.expectEqual(SoftUpdateResult.scheduled, result);

    // Verify job was enqueued
    const queue = job_queue_map.getQueue("https://example.com/").?;
    try std.testing.expectEqual(@as(usize, 1), queue.count());
}

test "shouldSoftUpdate" {
    const allocator = std.testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    // No workers = no update
    try std.testing.expect(!shouldSoftUpdate(reg));

    const sw = try @import("../service_worker.zig").ServiceWorker.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer sw.deinit();
    reg.setActiveWorker(sw);

    // Not stale = no update
    reg.markChecked();
    try std.testing.expect(!shouldSoftUpdate(reg));

    // Stale = should update
    reg.last_update_check_time = std.time.timestamp() - (Registration.STALE_THRESHOLD_SECONDS + 1);
    try std.testing.expect(shouldSoftUpdate(reg));
}
