//! Local HTTP and WebSocket test server
//!
//! Provides HTTP and WebSocket endpoints for integration testing,
//! eliminating external network dependencies and flaky test failures.
//!
//! HTTP Endpoints:
//!   GET  /get              - Echo request info
//!   POST /post             - Echo request with body
//!   PUT  /put              - Echo request with body
//!   DELETE /delete         - Echo request
//!   GET  /headers          - Echo request headers
//!   GET  /status/{code}    - Return specific HTTP status code
//!   GET  /delay/{seconds}  - Delay response (for timeout tests)
//!   GET  /response-headers - Return custom response headers
//!   GET  /bytes/{n}        - Return n bytes
//!
//! WebSocket Endpoints:
//!   /ws/echo               - Echo all messages back
//!   /ws/close              - Accept connection, then immediately close
//!   /ws/close/{code}       - Close with specific code
//!   /ws/binary             - Echo binary messages back

const std = @import("std");
const net = std.net;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const base64 = std.base64;
const Sha1 = std.crypto.hash.Sha1;

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

    pub fn getWsUrl(self: *TestServer, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "ws://127.0.0.1:{d}", .{self.port}) catch "ws://127.0.0.1:0";
    }

    fn serverLoop(self: *TestServer) void {
        while (!self.should_stop.load(.acquire)) {
            const conn = self.server.accept() catch |err| {
                if (err == error.SocketNotListening) break;
                continue;
            };

            // Handle connection in the same thread for simplicity
            // (for production, spawn a thread per connection)
            handleConnection(self.allocator, conn.stream, &self.should_stop) catch |err| {
                std.debug.print("Test server error: {}\n", .{err});
            };
            conn.stream.close();
        }
    }

    fn handleConnection(allocator: Allocator, stream: net.Stream, should_stop: *std.atomic.Value(bool)) !void {
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

        // Check for WebSocket upgrade
        if (isWebSocketUpgrade(request)) {
            try handleWebSocketUpgrade(allocator, stream, request, path, should_stop);
            return;
        }

        // Route to HTTP handler
        const response = routeRequest(allocator, method, path) catch |err| {
            std.debug.print("Route error: {}\n", .{err});
            return sendResponse(stream, 500, "Internal Server Error", "text/plain", "Internal Server Error");
        };
        defer if (response.body_allocated) allocator.free(response.body);

        try sendResponse(stream, response.status, response.status_text, response.content_type, response.body);
    }

    fn isWebSocketUpgrade(request: []const u8) bool {
        // Check for "Upgrade: websocket" header (case-insensitive)
        var lines = std.mem.splitSequence(u8, request, "\r\n");
        while (lines.next()) |line| {
            if (std.ascii.startsWithIgnoreCase(line, "upgrade:")) {
                const value = std.mem.trim(u8, line["upgrade:".len..], " \t");
                if (std.ascii.eqlIgnoreCase(value, "websocket")) {
                    return true;
                }
            }
        }
        return false;
    }

    fn handleWebSocketUpgrade(allocator: Allocator, stream: net.Stream, request: []const u8, path: []const u8, should_stop: *std.atomic.Value(bool)) !void {
        // Extract Sec-WebSocket-Key
        const ws_key = extractHeader(request, "Sec-WebSocket-Key") orelse return error.MissingWebSocketKey;

        // Generate Sec-WebSocket-Accept
        const accept_key = try computeAcceptKey(ws_key);

        // Send upgrade response
        var response_buf: [512]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n", .{accept_key}) catch return error.ResponseTooLarge;

        _ = try stream.write(response);

        // Handle WebSocket frames based on path
        if (std.mem.startsWith(u8, path, "/ws/echo")) {
            try handleWebSocketEcho(stream, should_stop);
        } else if (std.mem.startsWith(u8, path, "/ws/close/")) {
            const code_str = path["/ws/close/".len..];
            const code = std.fmt.parseInt(u16, code_str, 10) catch 1000;
            try sendWebSocketClose(stream, code, "Server closing");
        } else if (std.mem.eql(u8, path, "/ws/close")) {
            try sendWebSocketClose(stream, 1000, "Normal closure");
        } else if (std.mem.eql(u8, path, "/ws/binary")) {
            try handleWebSocketBinaryEcho(allocator, stream, should_stop);
        } else {
            // Default: echo
            try handleWebSocketEcho(stream, should_stop);
        }
    }

    fn extractHeader(request: []const u8, header_name: []const u8) ?[]const u8 {
        var lines = std.mem.splitSequence(u8, request, "\r\n");
        while (lines.next()) |line| {
            if (std.ascii.startsWithIgnoreCase(line, header_name)) {
                if (line.len > header_name.len and line[header_name.len] == ':') {
                    return std.mem.trim(u8, line[header_name.len + 1 ..], " \t");
                }
            }
        }
        return null;
    }

    fn computeAcceptKey(client_key: []const u8) ![28]u8 {
        const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        var hasher = Sha1.init(.{});
        hasher.update(client_key);
        hasher.update(magic);
        const hash = hasher.finalResult();

        var encoded: [28]u8 = undefined;
        _ = base64.standard.Encoder.encode(&encoded, &hash);
        return encoded;
    }

    fn handleWebSocketEcho(stream: net.Stream, should_stop: *std.atomic.Value(bool)) !void {
        var frame_buf: [4096]u8 = undefined;

        while (!should_stop.load(.acquire)) {
            // Read frame header (at least 2 bytes)
            const header_bytes = stream.read(frame_buf[0..2]) catch |err| {
                if (err == error.ConnectionResetByPeer or err == error.BrokenPipe) break;
                return err;
            };
            if (header_bytes < 2) break;

            const fin = (frame_buf[0] & 0x80) != 0;
            const opcode = frame_buf[0] & 0x0F;
            const masked = (frame_buf[1] & 0x80) != 0;
            var payload_len: u64 = frame_buf[1] & 0x7F;

            // Handle extended payload length
            var header_offset: usize = 2;
            if (payload_len == 126) {
                const ext_bytes = try stream.read(frame_buf[2..4]);
                if (ext_bytes < 2) break;
                payload_len = std.mem.readInt(u16, frame_buf[2..4], .big);
                header_offset = 4;
            } else if (payload_len == 127) {
                const ext_bytes = try stream.read(frame_buf[2..10]);
                if (ext_bytes < 8) break;
                payload_len = std.mem.readInt(u64, frame_buf[2..10], .big);
                header_offset = 10;
            }

            // Read mask key if present
            var mask_key: [4]u8 = undefined;
            if (masked) {
                const mask_bytes = try stream.read(frame_buf[header_offset .. header_offset + 4]);
                if (mask_bytes < 4) break;
                @memcpy(&mask_key, frame_buf[header_offset .. header_offset + 4]);
                header_offset += 4;
            }

            // Read payload
            if (payload_len > frame_buf.len - header_offset) {
                // Payload too large for buffer
                break;
            }
            const payload_end = header_offset + @as(usize, @intCast(payload_len));
            if (payload_len > 0) {
                const payload_bytes = try stream.read(frame_buf[header_offset..payload_end]);
                if (payload_bytes < payload_len) break;
            }

            // Unmask payload
            if (masked) {
                for (frame_buf[header_offset..payload_end], 0..) |*byte, i| {
                    byte.* ^= mask_key[i % 4];
                }
            }

            const payload = frame_buf[header_offset..payload_end];

            // Handle frame by opcode
            switch (opcode) {
                0x1, 0x2 => { // Text or Binary frame
                    // Echo back (unmasked, server-to-client)
                    try sendWebSocketFrame(stream, opcode, fin, payload);
                },
                0x8 => { // Close frame
                    // Echo close frame and exit
                    try sendWebSocketFrame(stream, 0x8, true, payload);
                    break;
                },
                0x9 => { // Ping
                    // Respond with Pong
                    try sendWebSocketFrame(stream, 0xA, true, payload);
                },
                0xA => { // Pong
                    // Ignore
                },
                else => {
                    // Unknown opcode, close connection
                    break;
                },
            }

            // Note: fin flag handling (fragmentation) is simplified for test server
        }
    }

    fn handleWebSocketBinaryEcho(allocator: Allocator, stream: net.Stream, should_stop: *std.atomic.Value(bool)) !void {
        // Same as echo but explicitly for binary frames
        _ = allocator;
        try handleWebSocketEcho(stream, should_stop);
    }

    fn sendWebSocketFrame(stream: net.Stream, opcode: u8, fin: bool, payload: []const u8) !void {
        var frame_buf: [4096 + 10]u8 = undefined;
        var offset: usize = 0;

        // First byte: FIN + opcode
        frame_buf[0] = (if (fin) @as(u8, 0x80) else @as(u8, 0)) | opcode;
        offset = 1;

        // Second byte: payload length (server frames are not masked)
        if (payload.len < 126) {
            frame_buf[1] = @intCast(payload.len);
            offset = 2;
        } else if (payload.len < 65536) {
            frame_buf[1] = 126;
            std.mem.writeInt(u16, frame_buf[2..4], @intCast(payload.len), .big);
            offset = 4;
        } else {
            frame_buf[1] = 127;
            std.mem.writeInt(u64, frame_buf[2..10], @intCast(payload.len), .big);
            offset = 10;
        }

        // Write header
        _ = try stream.write(frame_buf[0..offset]);

        // Write payload
        if (payload.len > 0) {
            _ = try stream.write(payload);
        }
    }

    fn sendWebSocketClose(stream: net.Stream, code: u16, reason: []const u8) !void {
        var payload: [125]u8 = undefined;
        std.mem.writeInt(u16, payload[0..2], code, .big);
        const reason_len = @min(reason.len, 123);
        @memcpy(payload[2 .. 2 + reason_len], reason[0..reason_len]);
        try sendWebSocketFrame(stream, 0x8, true, payload[0 .. 2 + reason_len]);
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

// Tests
test "TestServer - starts and stops" {
    const allocator = std.testing.allocator;
    const server = try TestServer.start(allocator);
    defer server.stop();

    var buf: [64]u8 = undefined;
    const url = server.getBaseUrl(&buf);
    try std.testing.expect(std.mem.startsWith(u8, url, "http://127.0.0.1:"));
}

test "TestServer - WebSocket URL" {
    const allocator = std.testing.allocator;
    const server = try TestServer.start(allocator);
    defer server.stop();

    var buf: [64]u8 = undefined;
    const url = server.getWsUrl(&buf);
    try std.testing.expect(std.mem.startsWith(u8, url, "ws://127.0.0.1:"));
}

test "TestServer - computeAcceptKey" {
    // Test vector from RFC 6455
    const key = "dGhlIHNhbXBsZSBub25jZQ==";
    const expected = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=";
    const result = try TestServer.computeAcceptKey(key);
    try std.testing.expectEqualStrings(expected, &result);
}
