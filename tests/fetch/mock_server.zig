//! Mock Test Server for Fetch Integration Tests
//!
//! This module provides a configurable mock server for testing fetch operations.
//! It allows setting up canned responses, simulating errors, and tracking requests.
//!
//! Usage:
//! ```zig
//! var server = MockServer.init(allocator);
//! defer server.deinit();
//!
//! // Configure responses
//! try server.addResponse("/api/data", .{
//!     .status = 200,
//!     .body = "{\"key\": \"value\"}",
//!     .headers = &.{.{"Content-Type", "application/json"}},
//! });
//!
//! // Make request
//! const response = try server.handleRequest(.{
//!     .method = "GET",
//!     .url = "/api/data",
//! });
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Mock HTTP request.
pub const MockRequest = struct {
    method: []const u8,
    url: []const u8,
    headers: []const [2][]const u8 = &.{},
    body: ?[]const u8 = null,

    /// Get a header value by name (case-insensitive).
    pub fn getHeader(self: *const MockRequest, name: []const u8) ?[]const u8 {
        for (self.headers) |header| {
            if (std.ascii.eqlIgnoreCase(header[0], name)) {
                return header[1];
            }
        }
        return null;
    }
};

/// Mock HTTP response configuration.
pub const MockResponse = struct {
    status: u16 = 200,
    status_text: []const u8 = "OK",
    headers: []const [2][]const u8 = &.{},
    body: ?[]const u8 = null,
    /// Delay in milliseconds before responding (simulates network latency)
    delay_ms: u32 = 0,
    /// If true, simulate a network error instead of responding
    network_error: bool = false,
    /// If true, simulate connection timeout
    timeout: bool = false,
};

/// Route matcher for URL patterns.
pub const RouteMatcher = union(enum) {
    /// Exact path match
    exact: []const u8,
    /// Prefix match (path starts with)
    prefix: []const u8,
    /// Match any path
    any,

    pub fn matches(self: RouteMatcher, path: []const u8) bool {
        return switch (self) {
            .exact => |pattern| std.mem.eql(u8, path, pattern),
            .prefix => |pattern| std.mem.startsWith(u8, path, pattern),
            .any => true,
        };
    }
};

/// Route configuration.
pub const Route = struct {
    matcher: RouteMatcher,
    method: ?[]const u8 = null, // null matches any method
    response: MockResponse,
    /// Number of times this route can be matched (null = unlimited)
    times: ?u32 = null,
    /// Count of times matched
    match_count: u32 = 0,
};

/// Recorded request for inspection.
pub const RecordedRequest = struct {
    method: []const u8,
    url: []const u8,
    headers: std.StringHashMapUnmanaged([]const u8),
    body: ?[]const u8,
    timestamp: i64,

    pub fn deinit(self: *RecordedRequest, allocator: Allocator) void {
        allocator.free(self.method);
        allocator.free(self.url);
        if (self.body) |b| allocator.free(b);

        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit(allocator);
    }
};

/// Mock server for testing.
pub const MockServer = struct {
    allocator: Allocator,
    routes: std.ArrayListUnmanaged(Route),
    requests: std.ArrayListUnmanaged(RecordedRequest),
    /// Default response for unmatched routes
    default_response: MockResponse,
    /// Whether to record requests
    record_requests: bool,

    const Self = @This();

    /// Initialize a new mock server.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .routes = .{},
            .requests = .{},
            .default_response = .{
                .status = 404,
                .status_text = "Not Found",
                .body = "Not Found",
            },
            .record_requests = true,
        };
    }

    /// Deinitialize the mock server.
    pub fn deinit(self: *Self) void {
        self.routes.deinit(self.allocator);
        for (self.requests.items) |*req| {
            req.deinit(self.allocator);
        }
        self.requests.deinit(self.allocator);
    }

    /// Add a route with exact path match.
    pub fn addRoute(self: *Self, path: []const u8, response: MockResponse) !void {
        try self.routes.append(self.allocator, .{
            .matcher = .{ .exact = path },
            .response = response,
        });
    }

    /// Add a route with method and path.
    pub fn addRouteWithMethod(self: *Self, method: []const u8, path: []const u8, response: MockResponse) !void {
        try self.routes.append(self.allocator, .{
            .matcher = .{ .exact = path },
            .method = method,
            .response = response,
        });
    }

    /// Add a route with prefix matching.
    pub fn addPrefixRoute(self: *Self, prefix: []const u8, response: MockResponse) !void {
        try self.routes.append(self.allocator, .{
            .matcher = .{ .prefix = prefix },
            .response = response,
        });
    }

    /// Add a route that matches once then removes itself.
    pub fn addOneTimeRoute(self: *Self, path: []const u8, response: MockResponse) !void {
        try self.routes.append(self.allocator, .{
            .matcher = .{ .exact = path },
            .response = response,
            .times = 1,
        });
    }

    /// Set the default response for unmatched routes.
    pub fn setDefaultResponse(self: *Self, response: MockResponse) void {
        self.default_response = response;
    }

    /// Clear all routes.
    pub fn clearRoutes(self: *Self) void {
        self.routes.clearRetainingCapacity();
    }

    /// Clear recorded requests.
    pub fn clearRequests(self: *Self) void {
        for (self.requests.items) |*req| {
            req.deinit(self.allocator);
        }
        self.requests.clearRetainingCapacity();
    }

    /// Handle a request and return the response.
    pub fn handleRequest(self: *Self, request: MockRequest) !MockResponse {
        // Record the request if enabled
        if (self.record_requests) {
            try self.recordRequest(request);
        }

        // Find matching route
        for (self.routes.items) |*route| {
            if (self.matchesRoute(route, request)) {
                route.match_count += 1;

                // Check if route is exhausted
                if (route.times) |times| {
                    if (route.match_count > times) {
                        continue; // Skip exhausted route
                    }
                }

                return route.response;
            }
        }

        // No match - return default
        return self.default_response;
    }

    fn matchesRoute(self: *const Self, route: *const Route, request: MockRequest) bool {
        _ = self;

        // Check method if specified
        if (route.method) |method| {
            if (!std.ascii.eqlIgnoreCase(method, request.method)) {
                return false;
            }
        }

        // Check path
        // Extract path from URL (remove query string)
        const path = extractPath(request.url);
        return route.matcher.matches(path);
    }

    fn recordRequest(self: *Self, request: MockRequest) !void {
        var headers = std.StringHashMapUnmanaged([]const u8){};
        errdefer headers.deinit(self.allocator);

        for (request.headers) |header| {
            const key = try self.allocator.dupe(u8, header[0]);
            errdefer self.allocator.free(key);
            const value = try self.allocator.dupe(u8, header[1]);
            try headers.put(self.allocator, key, value);
        }

        const recorded = RecordedRequest{
            .method = try self.allocator.dupe(u8, request.method),
            .url = try self.allocator.dupe(u8, request.url),
            .headers = headers,
            .body = if (request.body) |b| try self.allocator.dupe(u8, b) else null,
            .timestamp = std.time.timestamp(),
        };

        try self.requests.append(self.allocator, recorded);
    }

    /// Get the number of requests made.
    pub fn requestCount(self: *const Self) usize {
        return self.requests.items.len;
    }

    /// Get a recorded request by index.
    pub fn getRequest(self: *const Self, index: usize) ?*const RecordedRequest {
        if (index >= self.requests.items.len) return null;
        return &self.requests.items[index];
    }

    /// Get the last recorded request.
    pub fn lastRequest(self: *const Self) ?*const RecordedRequest {
        if (self.requests.items.len == 0) return null;
        return &self.requests.items[self.requests.items.len - 1];
    }

    /// Check if a request was made to a specific path.
    pub fn wasRequestMade(self: *const Self, method: []const u8, path: []const u8) bool {
        for (self.requests.items) |req| {
            if (std.ascii.eqlIgnoreCase(req.method, method)) {
                const req_path = extractPath(req.url);
                if (std.mem.eql(u8, req_path, path)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Count requests to a specific path.
    pub fn countRequestsTo(self: *const Self, path: []const u8) usize {
        var count: usize = 0;
        for (self.requests.items) |req| {
            const req_path = extractPath(req.url);
            if (std.mem.eql(u8, req_path, path)) {
                count += 1;
            }
        }
        return count;
    }
};

/// Extract path from URL (remove query string and fragment).
fn extractPath(url: []const u8) []const u8 {
    // Handle full URLs
    var path = url;

    // Skip scheme if present
    if (std.mem.indexOf(u8, path, "://")) |pos| {
        path = path[pos + 3 ..];
        // Skip host
        if (std.mem.indexOf(u8, path, "/")) |slash| {
            path = path[slash..];
        } else {
            return "/";
        }
    }

    // Remove query string
    if (std.mem.indexOf(u8, path, "?")) |pos| {
        path = path[0..pos];
    }

    // Remove fragment
    if (std.mem.indexOf(u8, path, "#")) |pos| {
        path = path[0..pos];
    }

    return path;
}

// =============================================================================
// Preset Response Builders
// =============================================================================

/// Create a JSON response.
pub fn jsonResponse(status: u16, body: []const u8) MockResponse {
    return .{
        .status = status,
        .headers = &.{.{ "Content-Type", "application/json" }},
        .body = body,
    };
}

/// Create a text response.
pub fn textResponse(status: u16, body: []const u8) MockResponse {
    return .{
        .status = status,
        .headers = &.{.{ "Content-Type", "text/plain" }},
        .body = body,
    };
}

/// Create an HTML response.
pub fn htmlResponse(status: u16, body: []const u8) MockResponse {
    return .{
        .status = status,
        .headers = &.{.{ "Content-Type", "text/html" }},
        .body = body,
    };
}

/// Create a redirect response.
pub fn redirectResponse(status: u16, location: []const u8) MockResponse {
    return .{
        .status = status,
        .headers = &.{.{ "Location", location }},
    };
}

/// Create a CORS-enabled response.
pub fn corsResponse(status: u16, body: ?[]const u8, origin: []const u8) MockResponse {
    return .{
        .status = status,
        .headers = &.{
            .{ "Access-Control-Allow-Origin", origin },
            .{ "Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS" },
            .{ "Access-Control-Allow-Headers", "Content-Type, Authorization" },
        },
        .body = body,
    };
}

/// Create a network error response.
pub fn networkErrorResponse() MockResponse {
    return .{
        .network_error = true,
    };
}

/// Create a timeout response.
pub fn timeoutResponse() MockResponse {
    return .{
        .timeout = true,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "MockServer - basic routing" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addRoute("/api/data", jsonResponse(200, "{\"ok\":true}"));

    const response = try server.handleRequest(.{
        .method = "GET",
        .url = "/api/data",
    });

    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("{\"ok\":true}", response.body.?);
}

test "MockServer - method matching" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addRouteWithMethod("GET", "/api/data", jsonResponse(200, "get"));
    try server.addRouteWithMethod("POST", "/api/data", jsonResponse(201, "post"));

    const get_response = try server.handleRequest(.{
        .method = "GET",
        .url = "/api/data",
    });
    try std.testing.expectEqual(@as(u16, 200), get_response.status);

    const post_response = try server.handleRequest(.{
        .method = "POST",
        .url = "/api/data",
    });
    try std.testing.expectEqual(@as(u16, 201), post_response.status);
}

test "MockServer - prefix routing" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addPrefixRoute("/api/", jsonResponse(200, "api"));

    const response1 = try server.handleRequest(.{ .method = "GET", .url = "/api/users" });
    try std.testing.expectEqual(@as(u16, 200), response1.status);

    const response2 = try server.handleRequest(.{ .method = "GET", .url = "/api/posts" });
    try std.testing.expectEqual(@as(u16, 200), response2.status);

    const response3 = try server.handleRequest(.{ .method = "GET", .url = "/other" });
    try std.testing.expectEqual(@as(u16, 404), response3.status);
}

test "MockServer - request recording" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addRoute("/test", jsonResponse(200, "ok"));

    _ = try server.handleRequest(.{
        .method = "POST",
        .url = "/test",
        .headers = &.{.{ "Content-Type", "application/json" }},
        .body = "{\"key\":\"value\"}",
    });

    try std.testing.expectEqual(@as(usize, 1), server.requestCount());

    const recorded = server.lastRequest().?;
    try std.testing.expectEqualStrings("POST", recorded.method);
    try std.testing.expectEqualStrings("/test", recorded.url);
    try std.testing.expectEqualStrings("{\"key\":\"value\"}", recorded.body.?);
}

test "MockServer - one-time route" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addOneTimeRoute("/once", jsonResponse(200, "first"));
    try server.addRoute("/once", jsonResponse(200, "subsequent"));

    const first = try server.handleRequest(.{ .method = "GET", .url = "/once" });
    try std.testing.expectEqualStrings("first", first.body.?);

    const second = try server.handleRequest(.{ .method = "GET", .url = "/once" });
    try std.testing.expectEqualStrings("subsequent", second.body.?);
}

test "MockServer - default response" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    const response = try server.handleRequest(.{ .method = "GET", .url = "/unknown" });
    try std.testing.expectEqual(@as(u16, 404), response.status);
}

test "MockServer - wasRequestMade" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator);
    defer server.deinit();

    try server.addRoute("/test", jsonResponse(200, "ok"));

    _ = try server.handleRequest(.{ .method = "GET", .url = "/test" });
    _ = try server.handleRequest(.{ .method = "POST", .url = "/other" });

    try std.testing.expect(server.wasRequestMade("GET", "/test"));
    try std.testing.expect(server.wasRequestMade("POST", "/other"));
    try std.testing.expect(!server.wasRequestMade("PUT", "/test"));
    try std.testing.expect(!server.wasRequestMade("GET", "/missing"));
}

test "extractPath" {
    try std.testing.expectEqualStrings("/path", extractPath("/path"));
    try std.testing.expectEqualStrings("/path", extractPath("/path?query=1"));
    try std.testing.expectEqualStrings("/path", extractPath("/path#fragment"));
    try std.testing.expectEqualStrings("/path", extractPath("/path?query=1#fragment"));
    try std.testing.expectEqualStrings("/api/data", extractPath("https://example.com/api/data"));
    try std.testing.expectEqualStrings("/api/data", extractPath("https://example.com/api/data?q=1"));
}

test "preset response builders" {
    const json = jsonResponse(200, "{}");
    try std.testing.expectEqual(@as(u16, 200), json.status);

    const redirect = redirectResponse(302, "/new-location");
    try std.testing.expectEqual(@as(u16, 302), redirect.status);

    const cors = corsResponse(200, "ok", "*");
    try std.testing.expectEqual(@as(u16, 200), cors.status);

    const err = networkErrorResponse();
    try std.testing.expect(err.network_error);

    const timeout = timeoutResponse();
    try std.testing.expect(timeout.timeout);
}
