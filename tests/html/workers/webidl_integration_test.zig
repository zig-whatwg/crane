//! WebIDL Worker Interface Integration Tests
//!
//! Tests for the internal html_core worker implementations that back
//! the WebIDL interfaces:
//! - WorkerLocation (src/html/workers/worker_location.zig)
//! - WorkerNavigator (src/html/workers/worker_navigator.zig)
//!
//! These tests verify the internal implementations work correctly.
//! The WebIDL interface wrappers are tested via full integration tests.
//!
//! Note: These tests replace the deprecated tests/mocks/worker_integration_test.zig
//! which tested mock implementations. The real implementations are now used.

const std = @import("std");
const testing = std.testing;

const html_core = @import("html_core");
const workers = html_core.workers;
const InternalWorkerLocation = workers.WorkerLocation;
const InternalWorkerNavigator = workers.WorkerNavigator;

// ============================================
// WorkerLocation Internal Implementation Tests
// ============================================

test "WorkerLocation internal - URL parsing with all components" {
    const allocator = testing.allocator;

    const location = try InternalWorkerLocation.init(
        allocator,
        "https://example.com:8080/path/to/worker.js?query=value#fragment",
    );
    defer location.deinit();

    // Test all URL components
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

test "WorkerLocation internal - simple URL without port" {
    const allocator = testing.allocator;

    const location = try InternalWorkerLocation.init(
        allocator,
        "https://example.com/worker.js",
    );
    defer location.deinit();

    try testing.expectEqualStrings("https://example.com/worker.js", location.getHref());
    try testing.expectEqualStrings("https:", location.getProtocol());
    try testing.expectEqualStrings("example.com", location.getHost());
    try testing.expectEqualStrings("example.com", location.getHostname());
    try testing.expectEqualStrings("", location.getPort());
    try testing.expectEqualStrings("/worker.js", location.getPathname());
    try testing.expectEqualStrings("", location.getSearch());
    try testing.expectEqualStrings("", location.getHash());
    try testing.expectEqualStrings("https://example.com", location.getOrigin());
}

test "WorkerLocation internal - URL with only search" {
    const allocator = testing.allocator;

    const location = try InternalWorkerLocation.init(
        allocator,
        "https://example.com/sw.js?version=1.0",
    );
    defer location.deinit();

    try testing.expectEqualStrings("?version=1.0", location.getSearch());
    try testing.expectEqualStrings("", location.getHash());
}

test "WorkerLocation internal - URL with only hash" {
    const allocator = testing.allocator;

    const location = try InternalWorkerLocation.init(
        allocator,
        "https://example.com/sw.js#main",
    );
    defer location.deinit();

    try testing.expectEqualStrings("", location.getSearch());
    try testing.expectEqualStrings("#main", location.getHash());
}

test "WorkerLocation internal - file URL" {
    const allocator = testing.allocator;

    const location = try InternalWorkerLocation.init(
        allocator,
        "file:///path/to/worker.js",
    );
    defer location.deinit();

    try testing.expectEqualStrings("file:", location.getProtocol());
    try testing.expectEqualStrings("/path/to/worker.js", location.getPathname());
}

// ============================================
// WorkerNavigator Internal Implementation Tests
// ============================================

test "WorkerNavigator internal - NavigatorID properties" {
    const allocator = testing.allocator;

    const navigator = try InternalWorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Test NavigatorID (spec-required values)
    // Spec: "Must return the string 'Mozilla'."
    try testing.expectEqualStrings("Mozilla", navigator.getAppCodeName());

    // Spec: "Must return the string 'Netscape'."
    try testing.expectEqualStrings("Netscape", navigator.getAppName());

    // Spec: "Must return the string 'Gecko'."
    try testing.expectEqualStrings("Gecko", navigator.getProduct());

    // Must return some version string
    try testing.expect(navigator.getAppVersion().len > 0);

    // User agent should be non-empty
    try testing.expect(navigator.getUserAgent().len > 0);
}

test "WorkerNavigator internal - NavigatorOnLine default" {
    const allocator = testing.allocator;

    const navigator = try InternalWorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Default should be online
    try testing.expect(navigator.isOnLine());
}

test "WorkerNavigator internal - NavigatorOnLine toggle" {
    const allocator = testing.allocator;

    const navigator = try InternalWorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Initially online
    try testing.expect(navigator.isOnLine());

    // Simulate going offline
    navigator.setOnLine(false);
    try testing.expect(!navigator.isOnLine());

    // Simulate going back online
    navigator.setOnLine(true);
    try testing.expect(navigator.isOnLine());
}

test "WorkerNavigator internal - NavigatorConcurrentHardware" {
    const allocator = testing.allocator;

    const navigator = try InternalWorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Should report at least 1 logical processor
    try testing.expect(navigator.getHardwareConcurrency() >= 1);
}

test "WorkerNavigator internal - NavigatorLanguage" {
    const allocator = testing.allocator;

    const navigator = try InternalWorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Should return a valid language tag
    const language = navigator.getLanguage();
    try testing.expect(language.len > 0);

    // Default should be en-US
    try testing.expectEqualStrings("en-US", language);
}

test "WorkerNavigator internal - platform" {
    const allocator = testing.allocator;

    const navigator = try InternalWorkerNavigator.init(allocator);
    defer navigator.deinit();

    // Should return some platform string
    const platform = navigator.getPlatform();
    try testing.expect(platform.len > 0);
}

// ============================================
// Worker Type Tests (from html_core.workers)
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
