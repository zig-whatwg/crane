//! Mock HTTP Server for Fetch Integration Tests
//!
//! This module starts a real HTTP server on localhost:8080 that responds
//! to fetch() requests from JavaScript tests.
//!
//! The server provides various endpoints for testing different scenarios:
//! - /api/* - JSON API endpoints
//! - /status/* - Different HTTP status codes
//! - /redirect/* - Redirect scenarios
//! - /content/* - Different content types
//! - /echo/* - Echo request data back
//! - /cors/* - CORS testing
//! - /delay/* - Delayed responses
//!
//! Run with: zig build test-v8-fetch

const std = @import("std");
const http = std.http;
const Server = http.Server;

pub const MockHttpServer = struct {
    server: Server,
    allocator: std.mem.Allocator,
    should_stop: std.atomic.Value(bool),

    pub fn init(allocator: std.mem.Allocator) !*MockHttpServer {
        const self = try allocator.create(MockHttpServer);

        self.* = .{
            .server = Server.init(allocator, .{}),
            .allocator = allocator,
            .should_stop = std.atomic.Value(bool).init(false),
        };

        return self;
    }

    pub fn deinit(self: *MockHttpServer) void {
        self.server.deinit();
        self.allocator.destroy(self);
    }

    pub fn start(self: *MockHttpServer) !void {
        const address = try std.net.Address.parseIp("127.0.0.1", 8080);

        try self.server.listen(address);

        std.debug.print("Mock HTTP server listening on http://127.0.0.1:8080\n", .{});

        while (!self.should_stop.load(.acquire)) {
            // Accept connection with timeout
            const conn = self.server.accept(.{
                .allocator = self.allocator,
            }) catch |err| {
                if (err == error.WouldBlock) {
                    std.time.sleep(10 * std.time.ns_per_ms);
                    continue;
                }
                return err;
            };

            // Handle request in this thread (simple sequential handling)
            self.handleConnection(conn) catch |err| {
                std.debug.print("Error handling connection: {}\n", .{err});
            };
        }
    }

    pub fn stop(self: *MockHttpServer) void {
        self.should_stop.store(true, .release);
    }

    fn handleConnection(self: *MockHttpServer, conn: *http.Server.Connection) !void {
        defer conn.deinit();

        const request = try conn.receiveHead();

        std.debug.print("Request: {} {s}\n", .{ request.method, request.target });

        // Route the request
        if (std.mem.startsWith(u8, request.target, "/api/")) {
            try self.handleApiRequest(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/status/")) {
            try self.handleStatusRequest(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/redirect/")) {
            try self.handleRedirectRequest(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/content/")) {
            try self.handleContentRequest(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/echo/")) {
            try self.handleEchoRequest(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/cors/")) {
            try self.handleCorsRequest(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/delay/")) {
            try self.handleDelayRequest(conn, request);
        } else if (std.mem.startsWith(u8, request.target, "/headers/")) {
            try self.handleHeadersRequest(conn, request);
        } else {
            try self.send404(conn);
        }
    }

    fn handleApiRequest(self: *MockHttpServer, conn: *http.Server.Connection, request: http.Server.Request) !void {
        if (std.mem.eql(u8, request.target, "/api/test")) {
            try self.sendJson(conn, .ok, "{\"message\": \"test successful\"}");
        } else if (std.mem.eql(u8, request.target, "/api/users")) {
            if (request.method == .GET) {
                try self.sendJson(conn, .ok,
                    \\[{"id": 1, "name": "Alice", "email": "alice@example.com"},
                    \\ {"id": 2, "name": "Bob", "email": "bob@example.com"}]
                );
            } else if (request.method == .POST) {
                try self.sendJson(conn, .created, "{\"id\": 3, \"message\": \"User created\"}");
            }
        } else if (std.mem.startsWith(u8, request.target, "/api/users/")) {
            const id_str = request.target[11..];
            const id = std.fmt.parseInt(u32, id_str, 10) catch {
                try self.send404(conn);
                return;
            };

            const json = try std.fmt.allocPrint(self.allocator, "{{\"id\": {d}, \"name\": \"User {d}\", \"email\": \"user{d}@example.com\"}}", .{ id, id, id });
            defer self.allocator.free(json);

            try self.sendJson(conn, .ok, json);
        } else if (std.mem.eql(u8, request.target, "/api/posts")) {
            if (request.method == .POST) {
                try self.sendJson(conn, .created, "{\"id\": 1, \"message\": \"Post created\"}");
            }
        } else if (std.mem.startsWith(u8, request.target, "/api/posts/")) {
            if (request.method == .PUT or request.method == .PATCH) {
                try self.sendJson(conn, .ok, "{\"message\": \"Post updated\"}");
            } else if (request.method == .DELETE) {
                try conn.writeHead(.no_content, .{});
                try conn.finish();
            }
        } else {
            try self.send404(conn);
        }
    }

    fn handleStatusRequest(self: *MockHttpServer, conn: *http.Server.Connection, request: http.Server.Request) !void {
        const code_str = request.target[8..]; // Skip "/status/"
        const code = std.fmt.parseInt(u16, code_str, 10) catch {
            try self.send404(conn);
            return;
        };

        const status: http.Status = switch (code) {
            200 => .ok,
            201 => .created,
            204 => .no_content,
            400 => .bad_request,
            401 => .unauthorized,
            403 => .forbidden,
            404 => .not_found,
            500 => .internal_server_error,
            503 => .service_unavailable,
            else => {
                try self.send404(conn);
                return;
            },
        };

        if (status == .no_content) {
            try conn.writeHead(status, .{});
            try conn.finish();
        } else {
            try self.sendText(conn, status, "Status response");
        }
    }

    fn handleRedirectRequest(self: *MockHttpServer, conn: *http.Server.Connection, request: http.Server.Request) !void {
        if (std.mem.eql(u8, request.target, "/redirect/permanent") or
            std.mem.eql(u8, request.target, "/redirect/301"))
        {
            try conn.writeHead(.moved_permanently, .{
                .location = "/redirect/target",
            });
            try conn.finish();
        } else if (std.mem.eql(u8, request.target, "/redirect/302")) {
            try conn.writeHead(.found, .{
                .location = "/redirect/target",
            });
            try conn.finish();
        } else if (std.mem.eql(u8, request.target, "/redirect/307")) {
            try conn.writeHead(.temporary_redirect, .{
                .location = "/redirect/target",
            });
            try conn.finish();
        } else if (std.mem.eql(u8, request.target, "/redirect/target")) {
            try self.sendText(conn, .ok, "Redirect target reached");
        } else {
            try self.send404(conn);
        }
    }

    fn handleContentRequest(self: *MockHttpServer, conn: *http.Server.Connection, request: http.Server.Request) !void {
        if (std.mem.eql(u8, request.target, "/content/text")) {
            try self.sendText(conn, .ok, "Hello, World!");
        } else if (std.mem.eql(u8, request.target, "/content/json")) {
            try self.sendJson(conn, .ok, "{\"message\": \"success\"}");
        } else if (std.mem.eql(u8, request.target, "/content/binary")) {
            // Send some binary data
            const binary_data = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD };
            try conn.writeHead(.ok, .{
                .@"content-type" = "application/octet-stream",
                .@"content-length" = try std.fmt.allocPrint(self.allocator, "{d}", .{binary_data.len}),
            });
            try conn.writeAll(&binary_data);
            try conn.finish();
        } else if (std.mem.eql(u8, request.target, "/content/large")) {
            // Generate large content (10KB)
            const large_buf = try self.allocator.alloc(u8, 10240);
            defer self.allocator.free(large_buf);

            @memset(large_buf, 'X');

            try conn.writeHead(.ok, .{
                .@"content-type" = "text/plain",
                .@"content-length" = "10240",
            });
            try conn.writeAll(large_buf);
            try conn.finish();
        } else if (std.mem.eql(u8, request.target, "/content/stream")) {
            // Send chunked response
            try conn.writeHead(.ok, .{
                .@"content-type" = "text/plain",
                .@"transfer-encoding" = "chunked",
            });

            // Send multiple chunks
            var i: u8 = 0;
            while (i < 5) : (i += 1) {
                const chunk = try std.fmt.allocPrint(self.allocator, "Chunk {d}\n", .{i});
                defer self.allocator.free(chunk);
                try conn.writeAll(chunk);
                std.time.sleep(100 * std.time.ns_per_ms); // 100ms delay between chunks
            }

            try conn.finish();
        } else {
            try self.send404(conn);
        }
    }

    fn handleEchoRequest(self: *MockHttpServer, conn: *http.Server.Connection, request: http.Server.Request) !void {

        // Read request body
        const body = try conn.readAll(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(body);

        if (std.mem.eql(u8, request.target, "/echo/headers")) {
            // Echo headers as JSON
            var json_buf = std.ArrayList(u8).init(self.allocator);
            defer json_buf.deinit();

            try json_buf.appendSlice("{");

            var first = true;
            var it = request.headers.iterator();
            while (it.next()) |header| {
                if (!first) try json_buf.appendSlice(",");
                first = false;

                try std.fmt.format(json_buf.writer(), "\"{s}\": \"{s}\"", .{ header.name, header.value });
            }

            try json_buf.appendSlice("}");

            try self.sendJson(conn, .ok, json_buf.items);
        } else if (std.mem.eql(u8, request.target, "/echo/body")) {
            // Echo body back
            const content_type = request.headers.getFirstValue("content-type") orelse "text/plain";

            try conn.writeHead(.ok, .{
                .@"content-type" = content_type,
                .@"content-length" = try std.fmt.allocPrint(self.allocator, "{d}", .{body.len}),
            });
            try conn.writeAll(body);
            try conn.finish();
        } else if (std.mem.eql(u8, request.target, "/echo/formdata")) {
            // Just confirm we received formdata
            try self.sendJson(conn, .ok, "{\"received\": \"formdata\"}");
        } else {
            try self.send404(conn);
        }
    }

    fn handleCorsRequest(_: *MockHttpServer, conn: *http.Server.Connection, _: http.Server.Request) !void {

        // Send CORS headers
        try conn.writeHead(.ok, .{
            .@"access-control-allow-origin" = "*",
            .@"access-control-allow-methods" = "GET, POST, PUT, DELETE, OPTIONS",
            .@"access-control-allow-headers" = "Content-Type, Authorization",
        });
        try conn.writeAll("{\"cors\": \"allowed\"}");
        try conn.finish();
    }

    fn handleDelayRequest(self: *MockHttpServer, conn: *http.Server.Connection, request: http.Server.Request) !void {
        const delay_str = request.target[7..]; // Skip "/delay/"
        const delay_ms = std.fmt.parseInt(u64, delay_str, 10) catch {
            try self.send404(conn);
            return;
        };

        // Sleep for specified delay
        std.time.sleep(delay_ms * std.time.ns_per_ms);

        try self.sendText(conn, .ok, "Delayed response");
    }

    fn handleHeadersRequest(self: *MockHttpServer, conn: *http.Server.Connection, request: http.Server.Request) !void {
        if (std.mem.eql(u8, request.target, "/headers/custom")) {
            try conn.writeHead(.ok, .{
                .@"x-custom-header" = "custom-value",
                .@"content-type" = "text/plain",
            });
            try conn.writeAll("Custom headers");
            try conn.finish();
        } else if (std.mem.eql(u8, request.target, "/headers/multiple")) {
            try conn.writeHead(.ok, .{
                .@"set-cookie" = "cookie1=value1, cookie2=value2",
                .@"content-type" = "text/plain",
            });
            try conn.writeAll("Multiple headers");
            try conn.finish();
        } else {
            try self.send404(conn);
        }
    }

    fn send404(self: *MockHttpServer, conn: *http.Server.Connection) !void {
        try self.sendText(conn, .not_found, "Not Found");
    }

    fn sendText(self: *MockHttpServer, conn: *http.Server.Connection, status: http.Status, text: []const u8) !void {
        const content_length = try std.fmt.allocPrint(self.allocator, "{d}", .{text.len});
        defer self.allocator.free(content_length);

        try conn.writeHead(status, .{
            .@"content-type" = "text/plain",
            .@"content-length" = content_length,
        });
        try conn.writeAll(text);
        try conn.finish();
    }

    fn sendJson(self: *MockHttpServer, conn: *http.Server.Connection, status: http.Status, json: []const u8) !void {
        const content_length = try std.fmt.allocPrint(self.allocator, "{d}", .{json.len});
        defer self.allocator.free(content_length);

        try conn.writeHead(status, .{
            .@"content-type" = "application/json",
            .@"content-length" = content_length,
        });
        try conn.writeAll(json);
        try conn.finish();
    }
};

// Test entry point that starts server and runs JS tests
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = try MockHttpServer.init(allocator);
    defer server.deinit();

    std.debug.print("Starting mock HTTP server for fetch tests...\n", .{});
    std.debug.print("Server will run on http://127.0.0.1:8080\n", .{});
    std.debug.print("Press Ctrl+C to stop\n\n", .{});

    try server.start();
}
