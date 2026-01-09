//! Service Worker Integration Tests
//!
//! Tests for the full service worker system integration.

const std = @import("std");
const testing = std.testing;

const sw = @import("service_worker");
const ServiceWorker = sw.ServiceWorker;
const ServiceWorkerState = sw.ServiceWorkerState;
const Registration = sw.Registration;
const RegistrationMap = sw.RegistrationMap;
const Cache = sw.Cache;
const CacheStorage = sw.CacheStorage;
const HeaderEntry = sw.HeaderEntry;
const Job = sw.Job;
const ScopeToJobQueueMap = sw.ScopeToJobQueueMap;
const algorithms = sw.algorithms;
const integration = sw.integration;

// =============================================================================
// Registration Map Tests
// =============================================================================

test "RegistrationMap - scope matching" {
    const allocator = testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    // Create registrations with different scopes
    const reg_root = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg_root.deinit();

    const reg_app = try Registration.init(allocator, "https://example.com", "https://example.com/app/");
    defer reg_app.deinit();

    const reg_api = try Registration.init(allocator, "https://example.com", "https://example.com/app/api/");
    defer reg_api.deinit();

    try map.set("https://example.com", "https://example.com/", reg_root);
    try map.set("https://example.com", "https://example.com/app/", reg_app);
    try map.set("https://example.com", "https://example.com/app/api/", reg_api);

    // Most specific scope should match
    const match1 = map.matchRegistration("https://example.com", "https://example.com/app/api/users");
    try testing.expectEqual(reg_api, match1.?);

    const match2 = map.matchRegistration("https://example.com", "https://example.com/app/index.html");
    try testing.expectEqual(reg_app, match2.?);

    const match3 = map.matchRegistration("https://example.com", "https://example.com/other");
    try testing.expectEqual(reg_root, match3.?);
}

test "RegistrationMap - getByScope" {
    const allocator = testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    try map.set("https://example.com", "https://example.com/", reg);

    // getByScope should find the registration
    const found = map.getByScope("https://example.com", "/page.html");
    try testing.expect(found != null);
    try testing.expectEqual(reg, found.?);
}

// =============================================================================
// Fetch Interception Tests
// =============================================================================

test "integration - shouldIntercept returns false when no SW" {
    const allocator = testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const should = integration.shouldIntercept(.{
        .url = "https://example.com/api",
    }, &map);

    try testing.expect(!should);
}

test "integration - shouldIntercept returns false for mode none" {
    const allocator = testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const should = integration.shouldIntercept(.{
        .url = "https://example.com/api",
        .service_workers_mode = .none,
    }, &map);

    try testing.expect(!should);
}

test "integration - interceptFetch with no registration" {
    const allocator = testing.allocator;

    var map = RegistrationMap.init(allocator);
    defer map.deinit();

    const result = integration.interceptFetch(.{
        .url = "https://example.com/api",
    }, .{
        .registration_map = &map,
        .allocator = allocator,
    });

    try testing.expectEqual(integration.InterceptionResult.no_interception, result);
}

// =============================================================================
// Job Queue Tests
// =============================================================================

test "job queue - serializes operations" {
    const allocator = testing.allocator;

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer {
        var iter = job_map.map.iterator();
        while (iter.next()) |entry| {
            while (entry.value_ptr.*.dequeue()) |job| {
                job.deinit();
            }
        }
        job_map.deinit();
    }

    // Create jobs for same scope
    const job1 = try Job.createRegisterJob(
        allocator,
        "https://example.com",
        "https://example.com/",
        "https://example.com/sw.js",
        .classic,
        .imports,
    );

    const job2 = try Job.createUpdateJob(
        allocator,
        "https://example.com",
        "https://example.com/",
        false,
    );

    // Schedule both
    try algorithms.scheduleJob(&job_map, job1);
    try algorithms.scheduleJob(&job_map, job2);

    // Second job should be added to first's equivalent list
    const queue = job_map.getQueue("https://example.com/").?;
    try testing.expectEqual(@as(usize, 1), queue.count());
    try testing.expectEqual(@as(usize, 1), job1.equivalent_jobs.items.len);
}

// =============================================================================
// Full Flow Tests
// =============================================================================

test "full flow - register and update" {
    const allocator = testing.allocator;

    // Set up registration map and job queue
    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer {
        var iter = job_map.map.iterator();
        while (iter.next()) |entry| {
            while (entry.value_ptr.*.dequeue()) |job| {
                job.deinit();
            }
        }
        job_map.deinit();
    }

    // Register
    const result = try algorithms.register(
        "https://example.com",
        "https://example.com/sw.js",
        .{},
        .{
            .registration_map = &reg_map,
            .job_queue_map = &job_map,
            .allocator = allocator,
        },
    );

    // Should have scheduled an update job
    switch (result) {
        .update_scheduled => |reg| {
            try testing.expectEqualStrings("https://example.com/", reg.scope_url);
        },
        else => try testing.expect(false),
    }

    // Verify job was created
    const queue = job_map.getQueue("https://example.com/").?;
    try testing.expectEqual(@as(usize, 1), queue.count());
}

// =============================================================================
// Cache + Fetch Integration Tests
// =============================================================================

test "cache-first strategy simulation" {
    const allocator = testing.allocator;

    // Set up cache
    const storage = try CacheStorage.init(allocator);
    defer storage.deinit();

    const cache = (try storage.open("v1")).value.?;

    // Pre-populate cache
    _ = try cache.put(
        "https://example.com/api/data",
        "GET",
        &[_]HeaderEntry{},
        200,
        "OK",
        &[_]HeaderEntry{.{ .name = "Content-Type", .value = "application/json" }},
        "{\"cached\": true}",
        .basic,
    );

    // Simulate cache-first: check cache first
    const cache_result = try cache.match(
        "https://example.com/api/data",
        "GET",
        &[_]HeaderEntry{},
        .{},
    );

    try testing.expect(cache_result.value.? != null);
    const cached_response = cache_result.value.?.?;
    try testing.expectEqual(@as(u16, 200), cached_response.status);
    try testing.expectEqualStrings("{\"cached\": true}", cached_response.body.?);
}

// =============================================================================
// Timing Tests
// =============================================================================

test "ServiceWorkerTiming tracking" {
    var timing = integration.ServiceWorkerTiming{};

    // Initially not involved
    try testing.expect(!timing.wasServiceWorkerInvolved());

    // Mark worker start
    timing.markWorkerStart();
    try testing.expect(timing.wasServiceWorkerInvolved());
    try testing.expect(timing.worker_start > 0);

    // Set router info
    timing.setMatchedRouterSource("cache");
    timing.setFinalRouterSource("network");

    try testing.expectEqualStrings("cache", timing.worker_matched_router_source);
    try testing.expectEqualStrings("network", timing.worker_final_router_source);
}

// =============================================================================
// Edge Cases
// =============================================================================

test "edge case - registration with same URL doesn't create new job" {
    const allocator = testing.allocator;

    var reg_map = RegistrationMap.init(allocator);
    defer reg_map.deinit();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer {
        var iter = job_map.map.iterator();
        while (iter.next()) |entry| {
            while (entry.value_ptr.*.dequeue()) |job| {
                job.deinit();
            }
        }
        job_map.deinit();
    }

    // Create registration with active worker
    const reg = try reg_map.getOrCreate("https://example.com", "https://example.com/");

    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();
    worker.setState(.activated);
    reg.setActiveWorker(worker);

    // Register with same script URL
    const result = try algorithms.register(
        "https://example.com",
        "https://example.com/sw.js",
        .{},
        .{
            .registration_map = &reg_map,
            .job_queue_map = &job_map,
            .allocator = allocator,
        },
    );

    // Should return already_registered
    switch (result) {
        .already_registered => {},
        else => try testing.expect(false),
    }
}

test "edge case - soft update when not stale" {
    const allocator = testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer worker.deinit();
    reg.setActiveWorker(worker);

    // Mark as recently checked
    reg.markChecked();

    var job_map = ScopeToJobQueueMap.init(allocator);
    defer job_map.deinit();

    const result = try algorithms.softUpdate(reg, &job_map);
    try testing.expectEqual(algorithms.SoftUpdateResult.not_stale, result);
}

test "edge case - try activate blocked by clients" {
    const allocator = testing.allocator;

    const reg = try Registration.init(allocator, "https://example.com", "https://example.com/");
    defer reg.deinit();

    const active = try ServiceWorker.init(allocator, "https://example.com/sw1.js", .classic);
    defer active.deinit();
    active.setState(.activated);
    reg.setActiveWorker(active);

    const waiting = try ServiceWorker.init(allocator, "https://example.com/sw2.js", .classic);
    defer waiting.deinit();
    waiting.setState(.installed);
    reg.setWaitingWorker(waiting);

    // Active has clients, waiting doesn't have skipWaiting
    const result = algorithms.tryActivate(reg, .{ .active_worker_client_count = 3 });
    try testing.expectEqual(algorithms.TryActivateResult.active_has_clients, result);
}

// =============================================================================
// Memory Safety
// =============================================================================

test "no leaks - full integration cycle" {
    const allocator = testing.allocator;

    // Run multiple full cycles
    for (0..5) |_| {
        var reg_map = RegistrationMap.init(allocator);
        var job_map = ScopeToJobQueueMap.init(allocator);
        const storage = try CacheStorage.init(allocator);

        // Create registration
        const reg = try reg_map.getOrCreate("https://example.com", "https://example.com/");

        // Create worker and go through lifecycle
        const worker = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);

        reg.setInstallingWorker(worker);
        _ = algorithms.installSync(reg);
        _ = algorithms.activateSync(reg);

        // Add cache entries
        const cache = (try storage.open("v1")).value.?;
        _ = try cache.put("https://example.com/", "GET", &[_]HeaderEntry{}, 200, "OK", &[_]HeaderEntry{}, "data", .basic);

        // Clean up jobs
        var iter = job_map.map.iterator();
        while (iter.next()) |entry| {
            while (entry.value_ptr.*.dequeue()) |job| {
                job.deinit();
            }
        }

        // Clean up
        worker.deinit();
        storage.deinit();
        job_map.deinit();
        reg_map.deinit();
    }
}
