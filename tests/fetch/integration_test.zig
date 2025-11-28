//! Fetch Integration Tests
//!
//! Comprehensive integration tests for complete fetch flows.
//! Tests the full stack from WebIDL interfaces through algorithms.

const std = @import("std");
const testing = std.testing;

// Import fetch modules
const fetch = @import("fetch");
const Headers = fetch.Headers;
const Request = fetch.Request;
const Response = fetch.Response;
const webidl = fetch.webidl;

// Import mock server
const mock_server = @import("mock_server.zig");
const MockServer = mock_server.MockServer;

// =============================================================================
// Basic Fetch Tests
// =============================================================================

test "fetch - simple GET to about:blank" {
    const allocator = testing.allocator;

    var result = webidl.fetchUrl(allocator, "about:blank");
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try testing.expectEqual(@as(u16, 200), response.status());
            try testing.expect(response.ok());
        },
        .err => {
            try testing.expect(false);
        },
    }
}

test "fetch - data URL text/plain" {
    const allocator = testing.allocator;

    var result = webidl.fetchUrl(allocator, "data:text/plain,Hello%20World");
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try testing.expectEqual(@as(u16, 200), response.status());
        },
        .err => {
            try testing.expect(false);
        },
    }
}

test "fetch - data URL with base64 encoding" {
    const allocator = testing.allocator;

    // "Hello" in base64
    var result = webidl.fetchUrl(allocator, "data:text/plain;base64,SGVsbG8=");
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try testing.expectEqual(@as(u16, 200), response.status());
        },
        .err => {
            try testing.expect(false);
        },
    }
}

test "fetch - data URL with JSON content type" {
    const allocator = testing.allocator;

    var result = webidl.fetchUrl(allocator, "data:application/json,{\"key\":\"value\"}");
    defer result.deinit();

    switch (result) {
        .response => |response| {
            try testing.expectEqual(@as(u16, 200), response.status());
        },
        .err => {
            try testing.expect(false);
        },
    }
}

test "fetch - unsupported scheme returns network error" {
    const allocator = testing.allocator;

    var result = webidl.fetchUrl(allocator, "ftp://example.com");
    defer result.deinit();

    switch (result) {
        .response => |response| {
            // Network errors have status 0 and type "error"
            try testing.expectEqual(@as(u16, 0), response.status());
        },
        .err => {
            // Also acceptable
        },
    }
}

// =============================================================================
// Headers Tests
// =============================================================================

test "Headers - create empty" {
    const allocator = testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try testing.expectEqual(@as(usize, 0), headers.len());
}

test "Headers - append and get" {
    const allocator = testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "application/json");
    try headers.append("Accept", "text/html");

    try testing.expectEqual(@as(usize, 2), headers.len());
    try testing.expect(try headers.has("Content-Type"));
    try testing.expect(try headers.has("Accept"));

    const ct = try headers.get(allocator, "Content-Type");
    defer if (ct) |c| allocator.free(c);
    try testing.expectEqualStrings("application/json", ct.?);
}

test "Headers - case insensitive" {
    const allocator = testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "text/plain");

    try testing.expect(try headers.has("content-type"));
    try testing.expect(try headers.has("CONTENT-TYPE"));
    try testing.expect(try headers.has("Content-Type"));
}

test "Headers - append combines values" {
    const allocator = testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Accept", "text/html");
    try headers.append("Accept", "application/json");

    const value = try headers.get(allocator, "Accept");
    defer if (value) |v| allocator.free(v);

    try testing.expectEqualStrings("text/html, application/json", value.?);
}

test "Headers - set replaces" {
    const allocator = testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "text/plain");
    try headers.set("Content-Type", "application/json");

    const value = try headers.get(allocator, "Content-Type");
    defer if (value) |v| allocator.free(v);

    try testing.expectEqualStrings("application/json", value.?);
}

test "Headers - delete" {
    const allocator = testing.allocator;

    const headers = try Headers.init(allocator, .none);
    defer headers.deinit();

    try headers.append("Content-Type", "text/plain");
    try headers.append("Accept", "text/html");

    try headers.delete("Content-Type");

    try testing.expect(!(try headers.has("Content-Type")));
    try testing.expect(try headers.has("Accept"));
}

// =============================================================================
// Request Tests
// =============================================================================

test "Request - create with URL" {
    const allocator = testing.allocator;

    const request = try Request.init(allocator, .{ .url = "https://example.com/api" }, .{});
    defer request.deinit();

    try testing.expectEqualStrings("GET", request.method());
    try testing.expectEqualStrings("https://example.com/api", request.url());
}

test "Request - create with method" {
    const allocator = testing.allocator;

    const request = try Request.init(allocator, .{ .url = "https://example.com/api" }, .{
        .method = "POST",
    });
    defer request.deinit();

    try testing.expectEqualStrings("POST", request.method());
}

test "Request - create with headers" {
    const allocator = testing.allocator;

    const init_headers = [_][2][]const u8{
        .{ "Content-Type", "application/json" },
        .{ "Authorization", "Bearer token" },
    };

    const request = try Request.init(allocator, .{ .url = "https://example.com" }, .{
        .headers = .{ .sequence = &init_headers },
    });
    defer request.deinit();

    try testing.expect(try request.headers().has("Content-Type"));
    try testing.expect(try request.headers().has("Authorization"));
}

test "Request - clone" {
    const allocator = testing.allocator;

    const original = try Request.init(allocator, .{ .url = "https://example.com" }, .{
        .method = "POST",
    });
    defer original.deinit();

    const cloned = try original.clone();
    defer cloned.deinit();

    try testing.expectEqualStrings("POST", cloned.method());
    try testing.expectEqualStrings("https://example.com", cloned.url());
}

test "Request - mode defaults" {
    const allocator = testing.allocator;

    const request = try Request.init(allocator, .{ .url = "https://example.com" }, .{});
    defer request.deinit();

    // Default mode should be no-cors
    try testing.expectEqual(fetch.internal.request.RequestMode.no_cors, request.mode());
}

test "Request - set mode cors" {
    const allocator = testing.allocator;

    const request = try Request.init(allocator, .{ .url = "https://example.com" }, .{
        .mode = .cors,
    });
    defer request.deinit();

    try testing.expectEqual(fetch.internal.request.RequestMode.cors, request.mode());
}

// =============================================================================
// Response Tests
// =============================================================================

test "Response - create with defaults" {
    const allocator = testing.allocator;

    const response = try Response.init(allocator, null, .{});
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status());
    try testing.expect(response.ok());
}

test "Response - create with status" {
    const allocator = testing.allocator;

    const response = try Response.init(allocator, null, .{ .status = 404 });
    defer response.deinit();

    try testing.expectEqual(@as(u16, 404), response.status());
    try testing.expect(!response.ok());
}

test "Response - create with body" {
    const allocator = testing.allocator;

    const response = try Response.init(allocator, "Hello, World!", .{});
    defer response.deinit();

    try testing.expectEqual(@as(u16, 200), response.status());
}

test "Response - error static method" {
    const allocator = testing.allocator;

    const response = try Response.createError(allocator);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 0), response.status());
    try testing.expectEqual(fetch.internal.response.ResponseType.@"error", response.responseType());
}

test "Response - redirect static method" {
    const allocator = testing.allocator;

    const response = try Response.createRedirect(allocator, "https://example.com/new", 302);
    defer response.deinit();

    try testing.expectEqual(@as(u16, 302), response.status());
}

test "Response - redirect rejects non-redirect status" {
    const allocator = testing.allocator;

    const result = Response.createRedirect(allocator, "https://example.com", 200);
    try testing.expectError(error.RangeError, result);
}

test "Response - clone" {
    const allocator = testing.allocator;

    const original = try Response.init(allocator, "test body", .{ .status = 201 });
    defer original.deinit();

    const cloned = try original.clone();
    defer cloned.deinit();

    try testing.expectEqual(@as(u16, 201), cloned.status());
}

test "Response - ok status range" {
    const allocator = testing.allocator;

    // 200-299 should be ok
    {
        const r = try Response.init(allocator, null, .{ .status = 200 });
        defer r.deinit();
        try testing.expect(r.ok());
    }
    {
        const r = try Response.init(allocator, null, .{ .status = 201 });
        defer r.deinit();
        try testing.expect(r.ok());
    }
    {
        const r = try Response.init(allocator, null, .{ .status = 299 });
        defer r.deinit();
        try testing.expect(r.ok());
    }

    // Outside range not ok
    {
        const r = try Response.init(allocator, null, .{ .status = 199 });
        defer r.deinit();
        try testing.expect(!r.ok());
    }
    {
        const r = try Response.init(allocator, null, .{ .status = 300 });
        defer r.deinit();
        try testing.expect(!r.ok());
    }
}

// =============================================================================
// Algorithm Integration Tests
// =============================================================================

test "algorithms - processDataUrl" {
    const allocator = testing.allocator;

    var result = try fetch.processDataUrl(allocator, "data:text/plain,Hello");
    defer if (result) |*r| r.deinit();

    try testing.expect(result != null);
    try testing.expectEqualStrings("text/plain", result.?.mime_type);
    try testing.expectEqualStrings("Hello", result.?.body);
}

test "algorithms - schemeFetch about:blank" {
    const allocator = testing.allocator;

    const result = try fetch.schemeFetch(allocator, "about", "about:blank");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try testing.expectEqual(@as(u16, 200), response.status);
        },
        .network_error => {
            try testing.expect(false);
        },
    }
}

test "algorithms - schemeFetch data URL" {
    const allocator = testing.allocator;

    const result = try fetch.schemeFetch(allocator, "data", "data:text/plain,Test");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try testing.expectEqual(@as(u16, 200), response.status);
        },
        .network_error => {
            try testing.expect(false);
        },
    }
}

test "algorithms - schemeFetch unsupported scheme" {
    const allocator = testing.allocator;

    const result = try fetch.schemeFetch(allocator, "ftp", "ftp://example.com");

    switch (result) {
        .response => |response| {
            defer response.deinit();
            try testing.expect(false); // Should be network error
        },
        .network_error => {
            // Expected
        },
    }
}

// =============================================================================
// Mock Server Integration Tests
// =============================================================================

test "mock server - simulate API responses" {
    const allocator = testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    // Set up routes - method-specific routes must come BEFORE catch-all routes
    // because routing matches in order
    try server.addRouteWithMethod("POST", "/api/users", mock_server.jsonResponse(201, "{\"id\":2}"));
    try server.addRouteWithMethod("GET", "/api/users", mock_server.jsonResponse(200, "[{\"id\":1,\"name\":\"Alice\"}]"));
    try server.addRoute("/api/posts", mock_server.jsonResponse(200, "[]"));

    // Test GET /api/users
    const get_users = try server.handleRequest(.{
        .method = "GET",
        .url = "/api/users",
    });
    try testing.expectEqual(@as(u16, 200), get_users.status);
    try testing.expectEqualStrings("[{\"id\":1,\"name\":\"Alice\"}]", get_users.body.?);

    // Test POST /api/users
    const create_user = try server.handleRequest(.{
        .method = "POST",
        .url = "/api/users",
        .body = "{\"name\":\"Bob\"}",
    });
    try testing.expectEqual(@as(u16, 201), create_user.status);

    // Verify requests were recorded
    try testing.expectEqual(@as(usize, 2), server.requestCount());
    try testing.expect(server.wasRequestMade("GET", "/api/users"));
    try testing.expect(server.wasRequestMade("POST", "/api/users"));
}

test "mock server - redirect handling" {
    const allocator = testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addRoute("/old", mock_server.redirectResponse(301, "/new"));
    try server.addRoute("/new", mock_server.textResponse(200, "New location"));

    const redirect = try server.handleRequest(.{
        .method = "GET",
        .url = "/old",
    });
    try testing.expectEqual(@as(u16, 301), redirect.status);

    const final = try server.handleRequest(.{
        .method = "GET",
        .url = "/new",
    });
    try testing.expectEqual(@as(u16, 200), final.status);
}

test "mock server - CORS responses" {
    const allocator = testing.allocator;

    // Test the corsResponse helper directly first
    const cors_resp = mock_server.corsResponse(200, "{}", "*");

    // Verify the corsResponse helper produces expected headers
    try testing.expectEqual(@as(u16, 200), cors_resp.status);
    try testing.expectEqual(@as(usize, 3), cors_resp.headers.len);
    try testing.expectEqualStrings("Access-Control-Allow-Origin", cors_resp.headers[0][0]);
    try testing.expectEqualStrings("*", cors_resp.headers[0][1]);

    // Now test via the mock server
    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addRoute("/api/data", cors_resp);

    const response = try server.handleRequest(.{
        .method = "GET",
        .url = "/api/data",
    });

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqual(@as(usize, 3), response.headers.len);
}
