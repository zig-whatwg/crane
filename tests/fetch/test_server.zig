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
//!   *    /redirect-abs     - 302, Location: /get            (root-relative)
//!   *    /redirect-rel     - 301, Location: get             (path-relative)
//!   *    /redirect-303     - 303, Location: /get            (method becomes GET)
//!   *    /redirect-307     - 307, Location: /post           (method is kept)
//!   *    /redirect-loop    - 302, Location: /redirect-loop  (never ends)
//!   *    /redirect-none    - 302 with no Location at all
//!   *    /redirect-ftp     - 302, Location: ftp://127.0.0.1/ (not HTTP(S))
//!   GET  /trickle/{n}      - n chunks of "chunk\n", 100ms apart, chunked
//!   GET  /bad-chunk        - one good chunk, then a malformed one
//!
//! WebSocket Endpoints:
//!   /ws/echo               - Echo all messages back
//!   /ws/close              - Accept connection, then immediately close
//!   /ws/close/{code}       - Close with specific code
//!   /ws/binary             - Echo binary messages back

const std = @import("std");
const clock = @import("clock");
const host = @import("host");
/// Zig 0.16 moved networking onto `std.Io`: `std.net` became `std.Io.net` and
/// every socket operation now takes an `Io`. The alias is kept so the rest of
/// this file still reads `net.Stream` / `net.Server`.
const net = std.Io.net;
const Io = std.Io;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const base64 = std.base64;
const Sha1 = std.crypto.hash.Sha1;

pub const TestServer = struct {
    allocator: Allocator,
    /// Zig 0.16 needs an `Io` for every socket operation. It is 16 bytes and
    /// copyable; holding it here keeps `start(allocator)` unchanged for callers
    /// while the handlers below take it as an ordinary parameter.
    io: Io,
    server: net.Server,
    thread: ?Thread = null,
    should_stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    port: u16,

    pub fn start(allocator: Allocator) !*TestServer {
        const self = try allocator.create(TestServer);
        errdefer allocator.destroy(self);

        // The process `Io`. Exactly one `Io.Threaded` may exist per process
        // (its init installs SIGIO/SIGPIPE handlers), so borrow the shared one
        // rather than constructing another.
        // std.testing.io, NOT host.io(): this is test-only infrastructure and the
        // 0.16 test runner already owns a live Io.Threaded (std.testing.io_instance).
        // host.io() would lazily construct a SECOND one, and Io.Threaded.init installs
        // process-wide SIGIO/SIGPIPE handlers - two of them in one process, with
        // whichever deinits last restoring the other's handlers.
        const io = std.testing.io;

        // Bind to localhost on a random available port
        const address: net.IpAddress = .{ .ip4 = net.Ip4Address.loopback(0) };
        const server = try address.listen(io, .{ .reuse_address = true });

        // 0.16 `Server` has no `listen_address`; `listen` runs getsockname and
        // hands the kernel-assigned ephemeral port back on the socket's address.
        self.* = .{
            .allocator = allocator,
            .io = io,
            .server = server,
            .port = server.socket.address.getPort(),
        };

        // Start server thread
        self.thread = try Thread.spawn(.{}, serverLoop, .{self});

        return self;
    }

    pub fn stop(self: *TestServer) void {
        self.should_stop.store(true, .release);
        // Close server socket to unblock accept()
        self.server.deinit(self.io);
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
        const io = self.io;
        while (!self.should_stop.load(.acquire)) {
            // 0.16 `accept` hands back a `Stream` directly; `Server.Connection`
            // no longer exists, so there is no `.stream` to reach through.
            const stream = self.server.accept(io) catch |err| {
                if (err == error.SocketNotListening) break;
                continue;
            };

            // Handle connection in the same thread for simplicity
            // (for production, spawn a thread per connection)
            handleConnection(self.allocator, io, stream, &self.should_stop) catch |err| {
                std.debug.print("Test server error: {}\n", .{err});
            };
            stream.close(io);
        }
    }

    /// Write every byte of `bytes` to `stream`.
    ///
    /// `std.Io.net.Stream` has no `write`/`writeAll` in 0.16; it vends a buffered
    /// `Io.Writer`. A zero-length buffer makes `writeAll` drain straight through
    /// to the socket on every call. The buffered writer reports failure as the
    /// opaque `error.WriteFailed` and stashes the real socket error on the
    /// adapter, so unwrap it here to keep the errors callers used to see.
    fn writeAllToStream(io: Io, stream: net.Stream, bytes: []const u8) net.Stream.Writer.Error!void {
        var buffer: [0]u8 = .{};
        var stream_writer = stream.writer(io, &buffer);
        stream_writer.interface.writeAll(bytes) catch |err| switch (err) {
            error.WriteFailed => return stream_writer.err.?,
        };
        // No-op while `buffer` is empty; kept so enlarging it cannot lose bytes.
        stream_writer.interface.flush() catch |err| switch (err) {
            error.WriteFailed => return stream_writer.err.?,
        };
    }

    /// Read up to `buf.len` bytes, returning a short count only at end of stream.
    ///
    /// The WebSocket frame reader asks for exact, known byte counts - a 2-byte
    /// header, a 2- or 8-byte extended length, a 4-byte mask, then the payload -
    /// so looping until `buf` is full never over-blocks: the peer always sends
    /// exactly those bytes. At end of stream `readSliceShort` returns the short
    /// count instead of erroring, which is what 0.15's `read` did by returning
    /// zero, so the existing `< n` checks keep working unchanged. The opaque
    /// `error.ReadFailed` is unwrapped into the real socket error.
    fn readShort(stream_reader: *net.Stream.Reader, buf: []u8) net.Stream.Reader.Error!usize {
        const n = stream_reader.interface.readSliceShort(buf) catch |err| switch (err) {
            error.ReadFailed => return stream_reader.err.?,
        };
        return n;
    }

    fn handleConnection(allocator: Allocator, io: Io, stream: net.Stream, should_stop: *std.atomic.Value(bool)) !void {
        // 0.16 reads through a buffered `Io.Reader` whose buffer the caller owns.
        // `fillMore` performs exactly one underlying read - the true analogue of
        // 0.15's `read(&buf)` - and reports a closed peer as `error.EndOfStream`
        // where 0.15 returned zero bytes. `readSliceShort` would be wrong here:
        // it loops until the 4 KiB buffer is full, so any smaller request would
        // block until the client sent more or hung up.
        var buf: [4096]u8 = undefined;
        var stream_reader = stream.reader(io, &buf);
        const reader = &stream_reader.interface;
        reader.fillMore() catch |err| switch (err) {
            error.EndOfStream => return,
            error.ReadFailed => return stream_reader.err.?,
        };

        const request = reader.buffered();
        if (request.len == 0) return;

        // Parse request line
        var lines = std.mem.splitScalar(u8, request, '\n');
        const request_line = lines.first();
        var parts = std.mem.splitScalar(u8, request_line, ' ');
        const method = parts.next() orelse return;
        const path = parts.next() orelse return;

        // Check for WebSocket upgrade
        if (isWebSocketUpgrade(request)) {
            try handleWebSocketUpgrade(allocator, io, stream, request, path, should_stop);
            return;
        }

        // Streamed bodies: the headers go first, then the body a piece at a
        // time - what a streamed transfer has to hand on as it arrives.
        if (std.mem.startsWith(u8, path, "/trickle/")) {
            const count = std.fmt.parseInt(usize, path["/trickle/".len..], 10) catch 1;
            return sendTrickle(io, stream, @min(count, 50));
        }
        if (std.mem.eql(u8, path, "/bad-chunk")) {
            try writeAllToStream(io, stream, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n6\r\nchunk\n\r\n");
            clock.sleep(100 * std.time.ns_per_ms);
            return writeAllToStream(io, stream, "zz\r\nnot a chunk\r\n");
        }

        // A HEAD request is answered like the GET it stands for, minus the
        // body: RFC 9110 9.3.2 - the same header fields, Content-Length
        // included, and no content.
        const is_head = std.mem.eql(u8, method, "HEAD");

        // Route to HTTP handler
        const response = routeRequest(allocator, if (is_head) "GET" else method, path) catch |err| {
            std.debug.print("Route error: {}\n", .{err});
            return sendResponse(io, stream, 500, "Internal Server Error", "text/plain", "Internal Server Error");
        };
        defer if (response.body_allocated) allocator.free(response.body);

        if (response.location) |location| {
            return sendRedirect(io, stream, response.status, response.status_text, location);
        }
        if (is_head) {
            return sendHeadResponse(io, stream, response.status, response.status_text, response.content_type, response.body.len);
        }
        try sendResponse(io, stream, response.status, response.status_text, response.content_type, response.body);
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

    fn handleWebSocketUpgrade(allocator: Allocator, io: Io, stream: net.Stream, request: []const u8, path: []const u8, should_stop: *std.atomic.Value(bool)) !void {
        // Extract Sec-WebSocket-Key
        const ws_key = extractHeader(request, "Sec-WebSocket-Key") orelse return error.MissingWebSocketKey;

        // Generate Sec-WebSocket-Accept
        const accept_key = try computeAcceptKey(ws_key);

        // Send upgrade response
        var response_buf: [512]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n", .{accept_key}) catch return error.ResponseTooLarge;

        try writeAllToStream(io, stream, response);

        // Handle WebSocket frames based on path
        if (std.mem.startsWith(u8, path, "/ws/echo")) {
            try handleWebSocketEcho(io, stream, should_stop);
        } else if (std.mem.startsWith(u8, path, "/ws/close/")) {
            const code_str = path["/ws/close/".len..];
            const code = std.fmt.parseInt(u16, code_str, 10) catch 1000;
            try sendWebSocketClose(io, stream, code, "Server closing");
        } else if (std.mem.eql(u8, path, "/ws/close")) {
            try sendWebSocketClose(io, stream, 1000, "Normal closure");
        } else if (std.mem.eql(u8, path, "/ws/binary")) {
            try handleWebSocketBinaryEcho(allocator, io, stream, should_stop);
        } else {
            // Default: echo
            try handleWebSocketEcho(io, stream, should_stop);
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

    fn handleWebSocketEcho(io: Io, stream: net.Stream, should_stop: *std.atomic.Value(bool)) !void {
        var frame_buf: [4096]u8 = undefined;

        // One reader for the whole connection. The reads below are sequential
        // consumption of a single byte stream, so the reader's own buffer only
        // adds read-ahead: bytes pulled in past the current frame stay buffered
        // and are handed to the next read rather than being lost, which is what
        // 0.15's unbuffered `read` relied on the kernel socket buffer for.
        var read_buf: [4096]u8 = undefined;
        var stream_reader = stream.reader(io, &read_buf);

        while (!should_stop.load(.acquire)) {
            // Read frame header (at least 2 bytes)
            const header_bytes = readShort(&stream_reader, frame_buf[0..2]) catch |err| {
                // `Stream.Reader.Error` no longer carries `BrokenPipe`; a peer
                // that vanished surfaces as a short read or ConnectionResetByPeer.
                if (err == error.ConnectionResetByPeer) break;
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
                const ext_bytes = try readShort(&stream_reader, frame_buf[2..4]);
                if (ext_bytes < 2) break;
                payload_len = std.mem.readInt(u16, frame_buf[2..4], .big);
                header_offset = 4;
            } else if (payload_len == 127) {
                const ext_bytes = try readShort(&stream_reader, frame_buf[2..10]);
                if (ext_bytes < 8) break;
                payload_len = std.mem.readInt(u64, frame_buf[2..10], .big);
                header_offset = 10;
            }

            // Read mask key if present
            var mask_key: [4]u8 = undefined;
            if (masked) {
                const mask_bytes = try readShort(&stream_reader, frame_buf[header_offset .. header_offset + 4]);
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
                const payload_bytes = try readShort(&stream_reader, frame_buf[header_offset..payload_end]);
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
                    try sendWebSocketFrame(io, stream, opcode, fin, payload);
                },
                0x8 => { // Close frame
                    // Echo close frame and exit
                    try sendWebSocketFrame(io, stream, 0x8, true, payload);
                    break;
                },
                0x9 => { // Ping
                    // Respond with Pong
                    try sendWebSocketFrame(io, stream, 0xA, true, payload);
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

    fn handleWebSocketBinaryEcho(allocator: Allocator, io: Io, stream: net.Stream, should_stop: *std.atomic.Value(bool)) !void {
        // Same as echo but explicitly for binary frames
        _ = allocator;
        try handleWebSocketEcho(io, stream, should_stop);
    }

    fn sendWebSocketFrame(io: Io, stream: net.Stream, opcode: u8, fin: bool, payload: []const u8) !void {
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
        try writeAllToStream(io, stream, frame_buf[0..offset]);

        // Write payload
        if (payload.len > 0) {
            try writeAllToStream(io, stream, payload);
        }
    }

    fn sendWebSocketClose(io: Io, stream: net.Stream, code: u16, reason: []const u8) !void {
        var payload: [125]u8 = undefined;
        std.mem.writeInt(u16, payload[0..2], code, .big);
        const reason_len = @min(reason.len, 123);
        @memcpy(payload[2 .. 2 + reason_len], reason[0..reason_len]);
        try sendWebSocketFrame(io, stream, 0x8, true, payload[0 .. 2 + reason_len]);
    }

    const RouteResponse = struct {
        status: u16,
        status_text: []const u8,
        content_type: []const u8,
        body: []const u8,
        body_allocated: bool = false,
        /// A `Location` header, for the redirect routes.
        location: ?[]const u8 = null,
    };

    /// The fixed redirect routes. Any method: the tests check what the client
    /// does with its method on the way to the target.
    fn redirectRoute(path: []const u8) ?RouteResponse {
        const Redirect = struct { path: []const u8, status: u16, text: []const u8, location: ?[]const u8 };
        const routes = [_]Redirect{
            .{ .path = "/redirect-abs", .status = 302, .text = "Found", .location = "/get" },
            .{ .path = "/redirect-rel", .status = 301, .text = "Moved Permanently", .location = "get" },
            .{ .path = "/redirect-303", .status = 303, .text = "See Other", .location = "/get" },
            .{ .path = "/redirect-307", .status = 307, .text = "Temporary Redirect", .location = "/post" },
            .{ .path = "/redirect-loop", .status = 302, .text = "Found", .location = "/redirect-loop" },
            .{ .path = "/redirect-none", .status = 302, .text = "Found", .location = null },
            .{ .path = "/redirect-ftp", .status = 302, .text = "Found", .location = "ftp://127.0.0.1/" },
        };
        for (routes) |r| {
            if (std.mem.eql(u8, path, r.path)) return .{
                .status = r.status,
                .status_text = r.text,
                .content_type = "text/plain",
                .body = "",
                .location = r.location,
            };
        }
        return null;
    }

    fn routeRequest(allocator: Allocator, method: []const u8, path: []const u8) !RouteResponse {
        if (redirectRoute(path)) |redirect| return redirect;

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
            clock.sleep(capped_delay * @as(u64, std.time.ns_per_s));
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

    fn sendRedirect(io: Io, stream: net.Stream, status: u16, status_text: []const u8, location: []const u8) !void {
        var response_buf: [1024]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf, "HTTP/1.1 {d} {s}\r\nLocation: {s}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", .{ status, status_text, location }) catch return error.ResponseTooLarge;

        try writeAllToStream(io, stream, response);
    }

    /// The response to HEAD: GET's header fields - Content-Length announcing
    /// the body a GET would have carried - and no body. A client that waits
    /// for those bytes waits until the connection closes.
    fn sendHeadResponse(io: Io, stream: net.Stream, status: u16, status_text: []const u8, content_type: []const u8, content_length: usize) !void {
        var response_buf: [1024]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\nX-Test-Header: test-value\r\n\r\n", .{ status, status_text, content_type, content_length }) catch return error.ResponseTooLarge;

        try writeAllToStream(io, stream, response);
    }

    /// `count` chunks of "chunk\n", chunked, 100ms apart.
    fn sendTrickle(io: Io, stream: net.Stream, count: usize) !void {
        try writeAllToStream(io, stream, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n");
        for (0..count) |_| {
            try writeAllToStream(io, stream, "6\r\nchunk\n\r\n");
            clock.sleep(100 * std.time.ns_per_ms);
        }
        try writeAllToStream(io, stream, "0\r\n\r\n");
    }

    fn sendResponse(io: Io, stream: net.Stream, status: u16, status_text: []const u8, content_type: []const u8, body: []const u8) !void {
        var response_buf: [8192]u8 = undefined;
        const response = std.fmt.bufPrint(&response_buf, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\nX-Test-Header: test-value\r\n\r\n{s}", .{ status, status_text, content_type, body.len, body }) catch return error.ResponseTooLarge;

        try writeAllToStream(io, stream, response);
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
