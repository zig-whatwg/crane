//! HTTP Mock Server for V8 Fetch Integration Tests
//!
//! This module wraps the existing MockServer (tests/fetch/mock_server.zig)
//! and exposes it over HTTP on localhost:8080 for V8 JavaScript tests.
//!
//! It translates HTTP requests → MockRequest → MockResponse → HTTP responses.
//!
//! Run standalone: zig build run-mock-server
//! Or import and use programmatically in test runners.

const std = @import("std");
const mock_server = @import("mock_server");
const MockServer = mock_server.MockServer;
const MockRequest = mock_server.MockRequest;
const MockResponse = mock_server.MockResponse;

/// HTTP wrapper around MockServer
pub const HttpMockServer = struct {
    allocator: std.mem.Allocator,
    mock: MockServer,
    server: std.net.Server,
    should_stop: std.atomic.Value(bool),
    large_content: ?[]u8,

    pub fn init(allocator: std.mem.Allocator) !*HttpMockServer {
        const self = try allocator.create(HttpMockServer);

        const address = try std.net.Address.parseIp("127.0.0.1", 8080);
        const server = try address.listen(.{
            .reuse_address = true,
        });

        self.* = .{
            .allocator = allocator,
            .mock = MockServer.init(allocator),
            .server = server,
            .should_stop = std.atomic.Value(bool).init(false),
            .large_content = null,
        };

        // Setup default routes for fetch tests
        try self.setupDefaultRoutes();

        return self;
    }

    pub fn deinit(self: *HttpMockServer) void {
        if (self.large_content) |lc| {
            self.allocator.free(lc);
        }
        self.mock.deinit();
        self.server.deinit();
        self.allocator.destroy(self);
    }

    /// Setup all routes needed for fetch integration tests
    fn setupDefaultRoutes(self: *HttpMockServer) !void {
        // /api/test
        try self.mock.addRoute("/api/test", .{
            .status = 200,
            .body = "{\"message\": \"test successful\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/users (GET)
        try self.mock.addRouteWithMethod("GET", "/api/users", .{
            .status = 200,
            .body =
            \\[{"id": 1, "name": "Alice", "email": "alice@example.com"},
            \\ {"id": 2, "name": "Bob", "email": "bob@example.com"}]
            ,
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/users (POST)
        try self.mock.addRouteWithMethod("POST", "/api/users", .{
            .status = 201,
            .body = "{\"id\": 3, \"message\": \"User created\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/users/:id
        try self.mock.addPrefixRoute("/api/users/", .{
            .status = 200,
            .body = "{\"id\": 123, \"name\": \"User 123\", \"email\": \"user123@example.com\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/posts (POST)
        try self.mock.addRouteWithMethod("POST", "/api/posts", .{
            .status = 201,
            .body = "{\"id\": 1, \"message\": \"Post created\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/posts/:id (PUT/PATCH)
        try self.mock.addPrefixRoute("/api/posts/", .{
            .status = 200,
            .body = "{\"message\": \"Post updated\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // Status codes
        const status_codes = [_]u16{ 200, 201, 204, 400, 401, 403, 404, 500, 503 };
        for (status_codes) |code| {
            const path = try std.fmt.allocPrint(self.allocator, "/status/{d}", .{code});
            defer self.allocator.free(path);

            const status_text = getStatusText(code);
            const body = if (code == 204) null else status_text;

            try self.mock.addRoute(path, .{
                .status = code,
                .status_text = status_text,
                .body = body,
            });
        }

        // Redirects
        try self.mock.addRoute("/redirect/permanent", .{
            .status = 301,
            .status_text = "Moved Permanently",
            .headers = &.{.{ "Location", "http://localhost:8080/redirect/target" }},
        });

        try self.mock.addRoute("/redirect/301", .{
            .status = 301,
            .headers = &.{.{ "Location", "http://localhost:8080/redirect/target" }},
        });

        try self.mock.addRoute("/redirect/302", .{
            .status = 302,
            .headers = &.{.{ "Location", "http://localhost:8080/redirect/target" }},
        });

        try self.mock.addRoute("/redirect/307", .{
            .status = 307,
            .headers = &.{.{ "Location", "http://localhost:8080/redirect/target" }},
        });

        try self.mock.addRoute("/redirect/target", .{
            .status = 200,
            .body = "Redirect target reached",
        });

        // Content types
        try self.mock.addRoute("/content/text", .{
            .status = 200,
            .body = "Hello, World!",
            .headers = &.{.{ "Content-Type", "text/plain" }},
        });

        try self.mock.addRoute("/content/json", .{
            .status = 200,
            .body = "{\"message\": \"success\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        try self.mock.addRoute("/content/binary", .{
            .status = 200,
            .body = &[_]u8{ 0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD },
            .headers = &.{.{ "Content-Type", "application/octet-stream" }},
        });

        // Large content
        self.large_content = try self.allocator.alloc(u8, 10240);
        @memset(self.large_content.?, 'X');
        try self.mock.addRoute("/content/large", .{
            .status = 200,
            .body = self.large_content.?,
            .headers = &.{.{ "Content-Type", "text/plain" }},
        });

        // Echo endpoints will be handled specially in handleRequest

        // CORS
        try self.mock.addPrefixRoute("/cors/", .{
            .status = 200,
            .body = "{\"cors\": \"allowed\"}",
            .headers = &.{
                .{ "Access-Control-Allow-Origin", "*" },
                .{ "Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS" },
                .{ "Access-Control-Allow-Headers", "Content-Type, Authorization" },
                .{ "Content-Type", "application/json" },
            },
        });

        // Custom headers
        try self.mock.addRoute("/headers/custom", .{
            .status = 200,
            .body = "Custom headers",
            .headers = &.{
                .{ "X-Custom-Header", "custom-value" },
                .{ "Content-Type", "text/plain" },
            },
        });

        try self.mock.addRoute("/headers/multiple", .{
            .status = 200,
            .body = "Multiple headers",
            .headers = &.{
                .{ "Set-Cookie", "cookie1=value1, cookie2=value2" },
                .{ "Content-Type", "text/plain" },
            },
        });
    }

    pub fn start(self: *HttpMockServer) !void {
        std.debug.print("Mock HTTP server listening on http://127.0.0.1:8080\n", .{});
        std.debug.print("Press Ctrl+C to stop\n\n", .{});

        while (!self.should_stop.load(.acquire)) {
            // Accept connection
            const conn = self.server.accept() catch |err| {
                std.debug.print("Error accepting connection: {}\n", .{err});
                continue;
            };

            // Handle request
            self.handleHttpRequest(conn) catch |err| {
                std.debug.print("Error handling request: {}\n", .{err});
            };
        }
    }

    pub fn stop(self: *HttpMockServer) void {
        self.should_stop.store(true, .release);

        // Make a dummy connection to wake up the accept() call
        const address = std.net.Address.parseIp("127.0.0.1", 8080) catch return;
        const stream = std.net.tcpConnectToAddress(address) catch return;
        stream.close();
    }

    fn handleHttpRequest(self: *HttpMockServer, conn: std.net.Server.Connection) !void {
        defer conn.stream.close();

        var buf: [8192]u8 = undefined;
        const bytes_read = try conn.stream.read(&buf);

        if (bytes_read == 0) return;

        const request_data = buf[0..bytes_read];

        // Parse HTTP request
        const parsed = try parseHttpRequest(self.allocator, request_data);
        defer {
            self.allocator.free(parsed.method);
            self.allocator.free(parsed.path);
            if (parsed.body) |b| self.allocator.free(b);
            for (parsed.headers) |h| {
                self.allocator.free(h[0]);
                self.allocator.free(h[1]);
            }
            self.allocator.free(parsed.headers);
        }

        std.debug.print("{s} {s}\n", .{ parsed.method, parsed.path });

        // Handle echo endpoints specially
        var response: MockResponse = undefined;
        if (std.mem.startsWith(u8, parsed.path, "/echo/")) {
            response = try self.handleEchoRequest(parsed);
        } else if (std.mem.startsWith(u8, parsed.path, "/delay/")) {
            response = try self.handleDelayRequest(parsed);
        } else {
            // Convert to MockRequest
            const mock_req = MockRequest{
                .method = parsed.method,
                .url = parsed.path,
                .headers = parsed.headers,
                .body = parsed.body,
            };

            // Get response from mock server
            response = try self.mock.handleRequest(mock_req);
        }

        // Send HTTP response
        try self.sendHttpResponse(conn.stream, response);
    }

    fn handleEchoRequest(self: *HttpMockServer, parsed: ParsedRequest) !MockResponse {
        if (std.mem.eql(u8, parsed.path, "/echo/headers")) {
            // Echo headers as JSON
            var json: std.ArrayList(u8) = .{};
            defer json.deinit(self.allocator);

            try json.appendSlice(self.allocator, "{");
            for (parsed.headers, 0..) |header, i| {
                if (i > 0) try json.appendSlice(self.allocator, ",");
                try std.fmt.format(json.writer(self.allocator), "\"{s}\": \"{s}\"", .{ header[0], header[1] });
            }
            try json.appendSlice(self.allocator, "}");

            return .{
                .status = 200,
                .body = try self.allocator.dupe(u8, json.items),
                .headers = &.{.{ "Content-Type", "application/json" }},
            };
        } else if (std.mem.eql(u8, parsed.path, "/echo/body")) {
            // Echo body back
            const content_type = blk: {
                for (parsed.headers) |h| {
                    if (std.ascii.eqlIgnoreCase(h[0], "content-type")) {
                        break :blk h[1];
                    }
                }
                break :blk "text/plain";
            };

            return .{
                .status = 200,
                .body = if (parsed.body) |b| try self.allocator.dupe(u8, b) else "",
                .headers = &.{.{ "Content-Type", content_type }},
            };
        } else if (std.mem.eql(u8, parsed.path, "/echo/formdata")) {
            return .{
                .status = 200,
                .body = "{\"received\": \"formdata\"}",
                .headers = &.{.{ "Content-Type", "application/json" }},
            };
        }

        return .{ .status = 404, .body = "Not Found" };
    }

    fn handleDelayRequest(self: *HttpMockServer, parsed: ParsedRequest) !MockResponse {
        _ = self;

        const delay_str = parsed.path[7..]; // Skip "/delay/"
        const delay_ms = std.fmt.parseInt(u64, delay_str, 10) catch {
            return .{ .status = 404, .body = "Invalid delay" };
        };

        std.Thread.sleep(delay_ms * std.time.ns_per_ms);

        return .{
            .status = 200,
            .body = "Delayed response",
        };
    }

    fn sendHttpResponse(self: *HttpMockServer, stream: std.net.Stream, response: MockResponse) !void {
        var response_buf: std.ArrayList(u8) = .{};
        defer response_buf.deinit(self.allocator);

        const writer = response_buf.writer(self.allocator);

        // Status line
        try std.fmt.format(writer, "HTTP/1.1 {d} {s}\r\n", .{ response.status, response.status_text });

        // Headers
        for (response.headers) |header| {
            try std.fmt.format(writer, "{s}: {s}\r\n", .{ header[0], header[1] });
        }

        // Content-Length
        const body = response.body orelse "";
        try std.fmt.format(writer, "Content-Length: {d}\r\n", .{body.len});

        // End of headers
        try writer.writeAll("\r\n");

        // Body
        try writer.writeAll(body);

        // Send
        try stream.writeAll(response_buf.items);
    }

    fn getStatusText(code: u16) []const u8 {
        return switch (code) {
            200 => "OK",
            201 => "Created",
            204 => "No Content",
            400 => "Bad Request",
            401 => "Unauthorized",
            403 => "Forbidden",
            404 => "Not Found",
            500 => "Internal Server Error",
            503 => "Service Unavailable",
            else => "Unknown",
        };
    }
};

const ParsedRequest = struct {
    method: []const u8,
    path: []const u8,
    headers: []const [2][]const u8,
    body: ?[]const u8,
};

fn parseHttpRequest(allocator: std.mem.Allocator, data: []const u8) !ParsedRequest {
    var lines = std.mem.splitSequence(u8, data, "\r\n");

    // Parse request line
    const request_line = lines.next() orelse return error.InvalidRequest;
    var parts = std.mem.splitSequence(u8, request_line, " ");

    const method = try allocator.dupe(u8, parts.next() orelse return error.InvalidRequest);
    errdefer allocator.free(method);

    const path = try allocator.dupe(u8, parts.next() orelse return error.InvalidRequest);
    errdefer allocator.free(path);

    // Parse headers
    var headers: std.ArrayList([2][]const u8) = .{};
    errdefer {
        for (headers.items) |h| {
            allocator.free(h[0]);
            allocator.free(h[1]);
        }
        headers.deinit(allocator);
    }

    while (lines.next()) |line| {
        if (line.len == 0) break; // End of headers

        const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const name = try allocator.dupe(u8, std.mem.trim(u8, line[0..colon_idx], " \t"));
        const value = try allocator.dupe(u8, std.mem.trim(u8, line[colon_idx + 1 ..], " \t"));

        try headers.append(allocator, .{ name, value });
    }

    // Body is everything after headers
    const body: ?[]const u8 = blk: {
        const rest = lines.rest();
        if (rest.len > 0) {
            break :blk try allocator.dupe(u8, rest);
        }
        break :blk null;
    };

    return .{
        .method = method,
        .path = path,
        .headers = try headers.toOwnedSlice(allocator),
        .body = body,
    };
}

// Standalone server for manual testing
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = try HttpMockServer.init(allocator);
    defer server.deinit();

    try server.start();
}
