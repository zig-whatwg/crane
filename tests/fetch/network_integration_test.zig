//! Network Integration Tests with Real HTTP Endpoints
//!
//! Tests the LibcurlBackend with actual network requests to httpbin.org
//! and other test endpoints. These tests require network connectivity.
//!
//! Note: These tests are skipped in CI environments without network access.
//! Run with `zig build test -Dnetwork-tests=true` to enable.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const network = fetch.network;
const LibcurlBackend = network.LibcurlBackend;
const ConnectionPool = network.ConnectionPool;
const NetworkRequest = network.NetworkRequest;
const NetworkError = network.NetworkError;
const globalInit = network.globalInit;
const globalCleanup = network.globalCleanup;

/// Check if a response indicates a server error (5xx) that should cause test skip
/// This handles cases where httpbin.org or other test endpoints are having issues
fn isServerError(status: u16) bool {
    return status >= 500 and status <= 599;
}

/// Skip test if response indicates server-side issues with test endpoint
fn skipOnServerError(response_status: u16) error{SkipZigTest}!void {
    if (isServerError(response_status)) {
        std.debug.print("Skipping network test: test endpoint returned server error {d}\n", .{response_status});
        return error.SkipZigTest;
    }
}

/// Check if we can reach the test endpoint
fn canReachTestEndpoint(allocator: std.mem.Allocator) bool {
    // Try to make a simple request to detect network availability
    const backend = LibcurlBackend.init(allocator) catch return false;
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/status/200",
        .method = "HEAD",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
        .connect_timeout_ms = 3000,
    };

    var response = backend.getBackend().send(allocator, &request) catch return false;
    response.deinit();
    return true;
}

// =============================================================================
// Basic HTTP Method Tests
// =============================================================================

test "LibcurlBackend - GET request to httpbin.org" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    // Skip if no network
    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/get",
        .method = "GET",
        .headers = &.{
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "User-Agent", .value = "whatwg-fetch-test/1.0" },
        },
        .body = null,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body != null);
    try testing.expect(response.body.?.len > 0);

    // Verify JSON response contains our User-Agent
    const body = response.body.?;
    try testing.expect(std.mem.indexOf(u8, body, "whatwg-fetch-test") != null);
}

test "LibcurlBackend - POST request with body" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const body_content = "{\"name\":\"test\",\"value\":42}";

    const request = NetworkRequest{
        .url = "https://httpbin.org/post",
        .method = "POST",
        .headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .body = body_content,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body != null);

    // httpbin echoes back our posted data
    const resp_body = response.body.?;
    try testing.expect(std.mem.indexOf(u8, resp_body, "test") != null);
    try testing.expect(std.mem.indexOf(u8, resp_body, "42") != null);
}

test "LibcurlBackend - PUT request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/put",
        .method = "PUT",
        .headers = &.{
            .{ .name = "Content-Type", .value = "text/plain" },
        },
        .body = "updated data",
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
}

test "LibcurlBackend - DELETE request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/delete",
        .method = "DELETE",
        .headers = &.{},
        .body = null,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
}

// =============================================================================
// Status Code Tests
// =============================================================================

test "LibcurlBackend - various status codes" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const status_codes = [_]u16{ 200, 201, 204, 301, 400, 404, 500 };

    for (status_codes) |expected_status| {
        var url_buf: [64]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "https://httpbin.org/status/{d}", .{expected_status}) catch unreachable;

        const request = NetworkRequest{
            .url = url,
            .method = "GET",
            .headers = &.{},
            .body = null,
            .timeout_ms = 30000,
            .follow_redirects = false, // Don't follow redirects for 301
        };

        var response = try backend.getBackend().send(allocator, &request);
        defer response.deinit();

        // If httpbin.org returns a 5xx error when we didn't expect one,
        // skip this test as httpbin.org is having issues
        if (isServerError(response.status) and !isServerError(expected_status)) {
            std.debug.print("Skipping status code test: httpbin.org returned {d} (server error)\n", .{response.status});
            return error.SkipZigTest;
        }

        try testing.expectEqual(expected_status, response.status);
    }
}

// =============================================================================
// Header Tests
// =============================================================================

test "LibcurlBackend - custom headers are sent" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/headers",
        .method = "GET",
        .headers = &.{
            .{ .name = "X-Custom-Header", .value = "custom-value-123" },
            .{ .name = "X-Another-Header", .value = "another-value" },
        },
        .body = null,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);

    // httpbin echoes headers in the response
    const body = response.body.?;
    try testing.expect(std.mem.indexOf(u8, body, "custom-value-123") != null);
    try testing.expect(std.mem.indexOf(u8, body, "another-value") != null);
}

test "LibcurlBackend - response headers are captured" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/response-headers?X-Test-Header=test-value",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    // Skip if httpbin.org is having server issues
    try skipOnServerError(response.status);

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.headers.len > 0);

    // Look for our custom response header
    var found_test_header = false;
    for (response.headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "X-Test-Header")) {
            try testing.expectEqualStrings("test-value", header.value);
            found_test_header = true;
            break;
        }
    }
    try testing.expect(found_test_header);
}

// =============================================================================
// Timeout Tests
// =============================================================================

test "LibcurlBackend - request timeout" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    // Request a 10 second delay but timeout after 1 second
    const request = NetworkRequest{
        .url = "https://httpbin.org/delay/10",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 1000, // 1 second timeout
    };

    const result = backend.getBackend().send(allocator, &request);
    try testing.expectError(NetworkError.RequestTimeout, result);
}

// =============================================================================
// Error Handling Tests
// =============================================================================

test "LibcurlBackend - DNS resolution failure" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://this-domain-definitely-does-not-exist-12345.invalid/",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .connect_timeout_ms = 5000,
    };

    const result = backend.getBackend().send(allocator, &request);
    try testing.expectError(NetworkError.DnsResolutionFailed, result);
}

test "LibcurlBackend - connection refused" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    // Port 1 is typically not listening
    const request = NetworkRequest{
        .url = "http://127.0.0.1:1/",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .connect_timeout_ms = 2000,
    };

    const result = backend.getBackend().send(allocator, &request);
    // Could be ConnectionRefused or RequestTimeout depending on OS
    if (result) |response| {
        var resp = response;
        resp.deinit();
        try testing.expect(false); // Should have errored
    } else |err| {
        try testing.expect(err == NetworkError.ConnectionRefused or
            err == NetworkError.RequestTimeout or
            err == NetworkError.ConnectionReset);
    }
}

// =============================================================================
// HTTPS/TLS Tests
// =============================================================================

test "LibcurlBackend - HTTPS with valid certificate" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/get",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 30000,
        .cert_options = .{
            .verify_peer = true,
            .verify_host = true,
        },
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
}

// =============================================================================
// Compression Tests
// =============================================================================

test "LibcurlBackend - gzip compressed response" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/gzip",
        .method = "GET",
        .headers = &.{
            .{ .name = "Accept-Encoding", .value = "gzip" },
        },
        .body = null,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    // libcurl automatically decompresses, so body should contain readable JSON
    try testing.expect(response.body != null);
    try testing.expect(std.mem.indexOf(u8, response.body.?, "gzipped") != null);
}

// =============================================================================
// Response Timing Tests
// =============================================================================

test "LibcurlBackend - timing information populated" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/get",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);

    // Timing should be populated
    try testing.expect(response.total_time_ms > 0);
    // Time to first byte should be reasonable
    try testing.expect(response.time_to_first_byte_ms <= response.total_time_ms);
}

// =============================================================================
// HTTP/2 Tests (requires -Dhttp2=true build option)
// =============================================================================

test "LibcurlBackend - HTTP/2 request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    // Request HTTP/2 - curl will negotiate via ALPN
    const request = NetworkRequest{
        .url = "https://nghttp2.org/httpbin/get", // This server supports HTTP/2
        .method = "GET",
        .headers = &.{},
        .body = null,
        .http_version = .http_2,
        .timeout_ms = 30000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    // Note: HTTP/2 will only be used if built with -Dhttp2=true
    // The test passes either way, but http_version will differ
    try testing.expect(response.http_version == .http_1_1 or response.http_version == .http_2);
}

// =============================================================================
// Connection Pool Tests
// =============================================================================

test "ConnectionPool - basic request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const pool = try ConnectionPool.init(allocator);
    defer pool.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/get",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 30000,
    };

    var response = try pool.send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body != null);
}

test "ConnectionPool - connection reuse" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    if (!canReachTestEndpoint(allocator)) {
        std.debug.print("Skipping network test: endpoint not reachable\n", .{});
        return error.SkipZigTest;
    }

    const pool = try ConnectionPool.init(allocator);
    defer pool.deinit();

    const request = NetworkRequest{
        .url = "https://httpbin.org/get",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 30000,
    };

    // First request - establishes connection
    {
        var response = try pool.send(allocator, &request);
        defer response.deinit();
        try testing.expectEqual(@as(u16, 200), response.status);
        // First request should establish new connection
        try testing.expect(!response.connection_reused);
    }

    // Second request - should reuse connection
    {
        var response = try pool.send(allocator, &request);
        defer response.deinit();
        try testing.expectEqual(@as(u16, 200), response.status);
        // Second request should reuse connection (num_connects == 0)
        try testing.expect(response.connection_reused);
    }
}
