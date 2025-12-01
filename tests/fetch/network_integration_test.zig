//! Network Integration Tests
//!
//! Tests the LibcurlBackend with actual network requests using a local test server.
//! No external network dependencies - all tests run against localhost.

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
const TestServer = @import("test_server.zig").TestServer;

// =============================================================================
// Basic HTTP Method Tests
// =============================================================================

test "LibcurlBackend - GET request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/get", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "GET",
        .headers = &.{
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "User-Agent", .value = "whatwg-fetch-test/1.0" },
        },
        .body = null,
        .timeout_ms = 5000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body != null);
    try testing.expect(response.body.?.len > 0);
}

test "LibcurlBackend - POST request with body" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/post", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const post_body = "test=value&foo=bar";
    const request = NetworkRequest{
        .url = url,
        .method = "POST",
        .headers = &.{
            .{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" },
        },
        .body = post_body,
        .timeout_ms = 5000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body != null);
}

test "LibcurlBackend - PUT request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/put", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "PUT",
        .headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .body =
        \\{"key": "value"}
        ,
        .timeout_ms = 5000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
}

test "LibcurlBackend - DELETE request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/delete", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "DELETE",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
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

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const status_codes = [_]u16{ 200, 201, 204, 301, 400, 404, 500 };

    for (status_codes) |expected_status| {
        var full_url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&full_url_buf, "{s}/status/{d}", .{ base_url, expected_status }) catch unreachable;

        const request = NetworkRequest{
            .url = url,
            .method = "GET",
            .headers = &.{},
            .body = null,
            .timeout_ms = 5000,
            .follow_redirects = false, // Don't follow redirects for 301
        };

        var response = try backend.getBackend().send(allocator, &request);
        defer response.deinit();

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

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/headers", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "GET",
        .headers = &.{
            .{ .name = "X-Custom-Header", .value = "custom-value-123" },
            .{ .name = "X-Another-Header", .value = "another-value" },
        },
        .body = null,
        .timeout_ms = 5000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
}

test "LibcurlBackend - response headers are captured" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/response-headers", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.headers.len > 0);

    // Look for our custom response header from test server
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

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    // Request 10 second delay but timeout after 1 second
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/delay/10", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
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
        .url = "http://this-domain-definitely-does-not-exist-12345.invalid/test",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
    };

    const result = backend.getBackend().send(allocator, &request);
    // Should fail with DNS resolution error
    try testing.expectError(NetworkError.DnsResolutionFailed, result);
}

test "LibcurlBackend - connection refused" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    // Use a port that's almost certainly not listening
    const request = NetworkRequest{
        .url = "http://127.0.0.1:59999/test",
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
        .connect_timeout_ms = 1000,
    };

    const result = backend.getBackend().send(allocator, &request);
    // Should fail with connection error
    try testing.expectError(NetworkError.ConnectionRefused, result);
}

// =============================================================================
// Response Body Tests
// =============================================================================

test "LibcurlBackend - binary response body" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/bytes/1024", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body != null);
    try testing.expectEqual(@as(usize, 1024), response.body.?.len);
}

test "LibcurlBackend - empty response body" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/status/204", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
    };

    var response = try backend.getBackend().send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 204), response.status);
}

// =============================================================================
// Multiple Requests Tests
// =============================================================================

test "LibcurlBackend - multiple sequential requests" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/get", .{base_url}) catch unreachable;

    const backend = try LibcurlBackend.init(allocator);
    defer backend.deinit();

    // Make 5 requests sequentially
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const request = NetworkRequest{
            .url = url,
            .method = "GET",
            .headers = &.{},
            .body = null,
            .timeout_ms = 5000,
        };

        var response = try backend.getBackend().send(allocator, &request);
        defer response.deinit();

        try testing.expectEqual(@as(u16, 200), response.status);
    }
}

// =============================================================================
// ConnectionPool Tests
// =============================================================================

test "ConnectionPool - basic request" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/get", .{base_url}) catch unreachable;

    const pool = try ConnectionPool.init(allocator);
    defer pool.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
    };

    var response = try pool.send(allocator, &request);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body != null);
}

test "ConnectionPool - multiple requests" {
    const allocator = testing.allocator;

    try globalInit();
    defer globalCleanup();

    const server = try TestServer.start(allocator);
    defer server.stop();

    var url_buf: [128]u8 = undefined;
    const base_url = server.getBaseUrl(&url_buf);
    var full_url_buf: [256]u8 = undefined;
    const url = std.fmt.bufPrint(&full_url_buf, "{s}/get", .{base_url}) catch unreachable;

    const pool = try ConnectionPool.init(allocator);
    defer pool.deinit();

    const request = NetworkRequest{
        .url = url,
        .method = "GET",
        .headers = &.{},
        .body = null,
        .timeout_ms = 5000,
    };

    // Make multiple requests through the pool
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        var response = try pool.send(allocator, &request);
        defer response.deinit();
        try testing.expectEqual(@as(u16, 200), response.status);
    }
}
