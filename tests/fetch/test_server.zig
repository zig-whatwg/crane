//! Local HTTP test server for network integration tests
//!
//! Provides a simple HTTP server that mimics httpbin.org endpoints locally,
//! eliminating external network dependencies and flaky test failures.

const std = @import("std");
const net = std.net;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

pub const TestServer = struct {
    allocator: Allocator,
    server: net.Server,
    thread: ?Thread = null,
    should_stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    port: u16,

    pub fn start(allocator: Allocator) !*TestServer {
        const self = try allocator.create(TestServer);
        errdefer allocator.destroy(self);

        // Bind to localhost on a random available port
        const address = net.Address.initIp4(.{ 127, 0, 0, 1 }, 0);
        self.* = .{
            .allocator = allocator,
            .server = try address.listen(.{ .reuse_address = true }),
            .port = self.server.listen_address.getPort(),
        };

        // Start server thread
        self.thread = try Thread.spawn(.{}, serverLoop, .{self});

        return self;
    }

    pub fn stop(self: *TestServer) void {
        self.should_stop.store(true, .release);
        // Close server socket to unblock accept()
        self.server.deinit();
        if (self.thread) |thread| {
            thread.join();
        }
        self.allocator.destroy(self);
    }

    pub fn getBaseUrl(self: *TestServer, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}", .{self.port}) catch "http://127.0.0.1:0";
    }

    fn serverLoop(self: *TestServer) void {
        while (!self.should_stop.load(.acquire)) {
            const conn = self.server.accept() catch |err| {
                if (err == error.SocketNotListening) break;
                continue;
            };
            defer conn.stream.close();

            handleConnection(self.allocator, conn.stream) catch |err| {
                std.debug.print("Test server error: {}\n", .{err});
            };
        }
    }

    fn handleConnection(allocator: Allocator, stream: net.Stream) !void {
        var buf: [4096]u8 = undefined;
        const bytes_read = try stream.read(&buf);
        if (bytes_read == 0) return;

        const request = buf[0..bytes_read];

        // Parse request line
        var lines = std.mem.splitScalar(u8, request, '\n');
        const request_line = lines.first();
        var parts = std.mem.splitScalar(u8, request_line, ' ');
        const method = parts.next() orelse return;
        const path = parts.next() orelse return;

        // Route to handler
        const response = routeRequest(allocator, method, path) catch |err| {
            std.debug.print("Route error: {}\n", .{err});
            return sendResponse(stream, 500, "Internal Server Error", "text/plain", "Internal Server Error");
        };
        defer if (response.body_allocated) allocator.free(response.body);

        try sendResponse(stream, response.status, response.status_text, response.content_type, response.body);
    }

    const RouteResponse = struct {
        status: u16,
        status_text: []const u8,
        content_type: []const u8,
        body: []const u8,
        body_allocated: bool = false,
    };

    fn routeRequest(allocator: Allocator, method: []const u8, path: []const u8) !RouteResponse {
        // GET /get - echo request info
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/get")) {
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/json",
                .body =
                \\{"url": "/get", "method": "GET"}
                ,
            };
        }

        // POST /post - echo request
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/post")) {
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/json",
                .body =
                \\{"url": "/post", "method": "POST"}
                ,
            };
        }

        // PUT /put - echo request
        if (std.mem.eql(u8, method, "PUT") and std.mem.eql(u8, path, "/put")) {
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/json",
                .body =
                \\{"url": "/put", "method": "PUT"}
                ,
            };
        }

        // DELETE /delete - echo request
        if (std.mem.eql(u8, method, "DELETE") and std.mem.eql(u8, path, "/delete")) {
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/json",
                .body =
                \\{"url": "/delete", "method": "DELETE"}
                ,
            };
        }

        // GET /headers - echo headers
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/headers")) {
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/json",
                .body =
                \\{"headers": {}}
                ,
            };
        }

        // GET /status/{code} - return specific status code
        if (std.mem.startsWith(u8, path, "/status/")) {
            const code_str = path[8..];
            const code = std.fmt.parseInt(u16, code_str, 10) catch 200;
            const status_text = getStatusText(code);
            return .{
                .status = code,
                .status_text = status_text,
                .content_type = "text/plain",
                .body = status_text,
            };
        }

        // GET /delay/{seconds} - delay response (for timeout tests)
        if (std.mem.startsWith(u8, path, "/delay/")) {
            const delay_str = path[7..];
            const delay_secs = std.fmt.parseInt(u64, delay_str, 10) catch 0;
            // Cap delay at 30 seconds for safety
            const capped_delay: u64 = @min(delay_secs, 30);
            std.Thread.sleep(capped_delay * @as(u64, std.time.ns_per_s));
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/json",
                .body =
                \\{"delayed": true}
                ,
            };
        }

        // GET /response-headers?key=value - return custom response headers
        if (std.mem.startsWith(u8, path, "/response-headers")) {
            // For simplicity, just return 200 with X-Test-Header
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/json",
                .body =
                \\{"X-Test-Header": "test-value"}
                ,
            };
        }

        // GET /bytes/{n} - return n random bytes
        if (std.mem.startsWith(u8, path, "/bytes/")) {
            const n_str = path[7..];
            const n = std.fmt.parseInt(usize, n_str, 10) catch 0;
            const capped_n = @min(n, 10000); // Cap at 10KB
            const body = try allocator.alloc(u8, capped_n);
            @memset(body, 'X');
            return .{
                .status = 200,
                .status_text = "OK",
                .content_type = "application/octet-stream",
                .body = body,
                .body_allocated = true,
            };
        }

        // Default: 404
        return .{
            .status = 404,
            .status_text = "Not Found",
            .content_type = "text/plain",
            .body = "Not Found",
        };
    }

    fn getStatusText(code: u16) []const u8 {
        return switch (code) {
            200 => "OK",
            201 => "Created",
            204 => "No Content",
            301 => "Moved Permanently",
            302 => "Found",
            304 => "Not Modified",
            400 => "Bad Request",
            401 => "Unauthorized",
            403 => "Forbidden",
            404 => "Not Found",
            405 => "Method Not Allowed",
            500 => "Internal Server Error",
            502 => "Bad Gateway",
            503 => "Service Unavailable",
            else => "Unknown",
        };
    }

    fn sendResponse(stream: net.Stream, status: u16, status_text: []const u8, content_type: []const u8, body: []const u8) !void {
        var response_buf: [8192]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\nX-Test-Header: test-value\r\n\r\n{s}", .{ status, status_text, content_type, body.len, body }) catch return error.ResponseTooLarge;

        _ = try stream.write(response);
    }
};

// Test the server itself
test "TestServer - starts and stops" {
    const allocator = std.testing.allocator;
    const server = try TestServer.start(allocator);
    defer server.stop();

    var buf: [64]u8 = undefined;
    const url = server.getBaseUrl(&buf);
    try std.testing.expect(std.mem.startsWith(u8, url, "http://127.0.0.1:"));
}
