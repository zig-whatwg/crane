//! HTTP Mock Server for V8 Fetch Integration Tests
//!
//! This module wraps the existing MockServer (tests/fetch/mock_server.zig)
//! and exposes it over HTTP on localhost:8080 for V8 JavaScript tests.
//!
//! It translates HTTP requests → MockRequest → MockResponse → HTTP responses.
//!
//! Also supports WebSocket upgrades for testing cookie sharing between
//! Fetch API and WebSocket connections.
//!
//! Run standalone: zig build run-mock-server
//! Or import and use programmatically in test runners.

const std = @import("std");
const mock_server = @import("mock_server");
const MockServer = mock_server.MockServer;
const MockRequest = mock_server.MockRequest;
const MockResponse = mock_server.MockResponse;
const base64 = std.base64;
const Sha1 = std.crypto.hash.Sha1;

/// WebSocket magic GUID per RFC 6455
const WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

/// HTTP wrapper around MockServer
pub const HttpMockServer = struct {
    allocator: std.mem.Allocator,
    mock: MockServer,
    server: std.net.Server,
    should_stop: std.atomic.Value(bool),
    large_content: ?[]u8,
    /// Dynamically allocated paths that need to be freed on deinit
    allocated_paths: std.ArrayListUnmanaged([]const u8),
    /// Expected cookie value for WebSocket cookie validation
    expected_ws_cookie: ?[]const u8 = null,

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
            .allocated_paths = .{},
        };

        // Setup default routes for fetch tests
        try self.setupDefaultRoutes();

        return self;
    }

    pub fn deinit(self: *HttpMockServer) void {
        if (self.large_content) |lc| {
            self.allocator.free(lc);
        }
        if (self.expected_ws_cookie) |cookie| {
            self.allocator.free(cookie);
        }
        // Free dynamically allocated paths
        for (self.allocated_paths.items) |path| {
            self.allocator.free(path);
        }
        self.allocated_paths.deinit(self.allocator);
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

        // /api/users/1 - specific route for user 1 (used in sequential test)
        try self.mock.addRoute("/api/users/1", .{
            .status = 200,
            .body = "{\"id\": 1, \"name\": \"Alice\", \"email\": \"alice@example.com\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/users/:id - fallback for other user IDs
        try self.mock.addPrefixRoute("/api/users/", .{
            .status = 200,
            .body = "{\"id\": 123, \"name\": \"User 123\", \"email\": \"user123@example.com\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/posts (POST) - must be before GET to ensure method matching
        try self.mock.addRouteWithMethod("POST", "/api/posts", .{
            .status = 201,
            .body = "{\"id\": 1, \"message\": \"Post created\", \"title\": \"Test Post\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/posts (GET)
        try self.mock.addRouteWithMethod("GET", "/api/posts", .{
            .status = 200,
            .body = "[{\"id\": 1, \"title\": \"First Post\"}]",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/posts/:id (DELETE) - specific route for DELETE
        try self.mock.addRouteWithMethod("DELETE", "/api/posts/1", .{
            .status = 204,
            .body = null,
        });

        // /api/posts/:id (GET) - specific route for verifying created posts
        try self.mock.addRouteWithMethod("GET", "/api/posts/1", .{
            .status = 200,
            .body = "{\"id\": 1, \"title\": \"Test Post\", \"content\": \"Content\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/posts/:id (PUT/PATCH) - prefix route for updates
        try self.mock.addPrefixRoute("/api/posts/", .{
            .status = 200,
            .body = "{\"message\": \"Post updated\"}",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // /api/comments (GET)
        try self.mock.addRoute("/api/comments", .{
            .status = 200,
            .body = "[{\"id\": 1, \"body\": \"Great post!\"}]",
            .headers = &.{.{ "Content-Type", "application/json" }},
        });

        // Status codes
        const status_codes = [_]u16{ 200, 201, 204, 400, 401, 403, 404, 500, 503 };
        for (status_codes) |code| {
            const path = try std.fmt.allocPrint(self.allocator, "/status/{d}", .{code});
            // Track allocated path for cleanup in deinit
            try self.allocated_paths.append(self.allocator, path);

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

        // Cookie endpoints for Fetch/WebSocket cookie sharing tests
        // /cookies/set - Sets a session cookie that WebSocket should receive
        // Note: The actual Set-Cookie header is handled specially in handleCookieRequest
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

            // Handle request in a detached thread to allow concurrent connections
            const thread = std.Thread.spawn(.{}, handleConnectionThread, .{ self, conn }) catch |err| {
                std.debug.print("Error spawning thread: {}\n", .{err});
                conn.stream.close();
                continue;
            };
            thread.detach();
        }
    }

    fn handleConnectionThread(self: *HttpMockServer, conn: std.net.Server.Connection) void {
        self.handleHttpRequest(conn) catch |err| {
            std.debug.print("Error handling request: {}\n", .{err});
        };
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

        // Check for WebSocket upgrade request
        if (self.isWebSocketUpgrade(parsed)) {
            try self.handleWebSocketUpgrade(conn.stream, parsed);
            return;
        }

        // Handle echo endpoints specially
        // Track dynamically allocated response data for cleanup
        var allocated_body: ?[]const u8 = null;
        var allocated_headers: ?[]const [2][]const u8 = null;
        var allocated_header_strings: [2][]const u8 = .{ &.{}, &.{} };
        var allocated_header_strings2: [2][]const u8 = .{ &.{}, &.{} };
        defer {
            if (allocated_body) |b| self.allocator.free(b);
            if (allocated_headers) |h| self.allocator.free(h);
            if (allocated_header_strings[0].len > 0) self.allocator.free(allocated_header_strings[0]);
            if (allocated_header_strings[1].len > 0) self.allocator.free(allocated_header_strings[1]);
            if (allocated_header_strings2[0].len > 0) self.allocator.free(allocated_header_strings2[0]);
            if (allocated_header_strings2[1].len > 0) self.allocator.free(allocated_header_strings2[1]);
        }

        var response: MockResponse = undefined;
        if (std.mem.startsWith(u8, parsed.path, "/echo/")) {
            const echo_result = try self.handleEchoRequest(parsed);
            response = echo_result.response;
            allocated_body = echo_result.allocated_body;
            allocated_headers = echo_result.allocated_headers;
            allocated_header_strings = echo_result.allocated_header_strings;
            allocated_header_strings2 = echo_result.allocated_header_strings2;
        } else if (std.mem.startsWith(u8, parsed.path, "/delay/")) {
            response = try self.handleDelayRequest(parsed);
        } else if (std.mem.startsWith(u8, parsed.path, "/cookies/")) {
            const cookie_result = try self.handleCookieRequest(parsed);
            response = cookie_result.response;
            allocated_body = cookie_result.allocated_body;
            allocated_headers = cookie_result.allocated_headers;
            allocated_header_strings = cookie_result.allocated_header_strings;
            allocated_header_strings2 = cookie_result.allocated_header_strings2;
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

    const EchoResult = struct {
        response: MockResponse,
        allocated_body: ?[]const u8 = null,
        allocated_headers: ?[]const [2][]const u8 = null,
        allocated_header_strings: [2][]const u8 = .{ &.{}, &.{} },
        allocated_header_strings2: [2][]const u8 = .{ &.{}, &.{} },
    };

    fn handleEchoRequest(self: *HttpMockServer, parsed: ParsedRequest) !EchoResult {
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

            const body = try self.allocator.dupe(u8, json.items);
            return .{
                .response = .{
                    .status = 200,
                    .body = body,
                    .headers = &.{.{ "Content-Type", "application/json" }},
                },
                .allocated_body = body,
            };
        } else if (std.mem.eql(u8, parsed.path, "/echo/body")) {
            // Echo body back
            // Find content-type from request headers
            var req_content_type: []const u8 = "text/plain";
            for (parsed.headers) |h| {
                if (std.ascii.eqlIgnoreCase(h[0], "content-type")) {
                    req_content_type = h[1];
                    break;
                }
            }

            // Allocate headers array on heap so it lives long enough
            const headers_arr = try self.allocator.alloc([2][]const u8, 1);
            const header_key = try self.allocator.dupe(u8, "Content-Type");
            const header_val = try self.allocator.dupe(u8, req_content_type);
            headers_arr[0] = .{ header_key, header_val };

            const body = if (parsed.body) |b| try self.allocator.dupe(u8, b) else null;

            return .{
                .response = .{
                    .status = 200,
                    .body = body orelse "",
                    .headers = headers_arr,
                },
                .allocated_body = body,
                .allocated_headers = headers_arr,
                .allocated_header_strings = .{ header_key, header_val },
            };
        } else if (std.mem.eql(u8, parsed.path, "/echo/formdata")) {
            return .{
                .response = .{
                    .status = 200,
                    .body = "{\"received\": \"formdata\"}",
                    .headers = &.{.{ "Content-Type", "application/json" }},
                },
            };
        }

        return .{
            .response = .{ .status = 404, .body = "Not Found" },
        };
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

    /// Handle cookie-related requests for Fetch/WebSocket cookie sharing tests
    fn handleCookieRequest(self: *HttpMockServer, parsed: ParsedRequest) !EchoResult {
        if (std.mem.eql(u8, parsed.path, "/cookies/set")) {
            // Set a cookie that will be shared with WebSocket
            // Generate a unique session token
            const token = "test_session_12345";

            // Store expected cookie for WebSocket validation
            if (self.expected_ws_cookie) |old| {
                self.allocator.free(old);
            }
            self.expected_ws_cookie = try self.allocator.dupe(u8, token);

            // Allocate headers array on heap
            const headers_arr = try self.allocator.alloc([2][]const u8, 2);
            const header_key1 = try self.allocator.dupe(u8, "Set-Cookie");
            // Cookie with Path=/ to ensure it's sent to all paths including WebSocket
            const header_val1 = try self.allocator.dupe(u8, "session=" ++ token ++ "; Path=/; HttpOnly");
            const header_key2 = try self.allocator.dupe(u8, "Content-Type");
            const header_val2 = try self.allocator.dupe(u8, "application/json");
            headers_arr[0] = .{ header_key1, header_val1 };
            headers_arr[1] = .{ header_key2, header_val2 };

            const body = try self.allocator.dupe(u8, "{\"status\": \"cookie_set\", \"token\": \"" ++ token ++ "\"}");

            return .{
                .response = .{
                    .status = 200,
                    .body = body,
                    .headers = headers_arr,
                },
                .allocated_body = body,
                .allocated_headers = headers_arr,
                .allocated_header_strings = .{ header_key1, header_val1 },
                .allocated_header_strings2 = .{ header_key2, header_val2 },
            };
        } else if (std.mem.eql(u8, parsed.path, "/cookies/check")) {
            // Check if the expected cookie was received
            var cookie_value: ?[]const u8 = null;
            for (parsed.headers) |h| {
                if (std.ascii.eqlIgnoreCase(h[0], "cookie")) {
                    cookie_value = h[1];
                    break;
                }
            }

            if (cookie_value) |cv| {
                // Parse cookie string to find session cookie
                var has_session = false;
                var iter = std.mem.splitSequence(u8, cv, "; ");
                while (iter.next()) |cookie| {
                    if (std.mem.startsWith(u8, cookie, "session=")) {
                        const value = cookie[8..];
                        if (self.expected_ws_cookie) |expected| {
                            if (std.mem.eql(u8, value, expected)) {
                                has_session = true;
                                break;
                            }
                        }
                    }
                }

                if (has_session) {
                    return .{
                        .response = .{
                            .status = 200,
                            .body = "{\"cookie_valid\": true}",
                            .headers = &.{.{ "Content-Type", "application/json" }},
                        },
                    };
                }
            }

            return .{
                .response = .{
                    .status = 401,
                    .body = "{\"cookie_valid\": false, \"error\": \"missing or invalid session cookie\"}",
                    .headers = &.{.{ "Content-Type", "application/json" }},
                },
            };
        }

        return .{
            .response = .{ .status = 404, .body = "Not Found" },
        };
    }

    /// Check if request is a WebSocket upgrade request
    fn isWebSocketUpgrade(self: *HttpMockServer, parsed: ParsedRequest) bool {
        _ = self;
        var has_upgrade = false;
        var has_websocket = false;

        for (parsed.headers) |h| {
            if (std.ascii.eqlIgnoreCase(h[0], "upgrade")) {
                if (std.ascii.eqlIgnoreCase(h[1], "websocket")) {
                    has_upgrade = true;
                }
            }
            if (std.ascii.eqlIgnoreCase(h[0], "connection")) {
                // Connection header may contain multiple values
                if (std.ascii.indexOfIgnoreCase(h[1], "upgrade") != null) {
                    has_websocket = true;
                }
            }
        }

        return has_upgrade and has_websocket;
    }

    /// Handle WebSocket upgrade and manage the WebSocket connection
    fn handleWebSocketUpgrade(self: *HttpMockServer, stream: std.net.Stream, parsed: ParsedRequest) !void {
        // Get Sec-WebSocket-Key
        var ws_key: ?[]const u8 = null;
        var cookie_header: ?[]const u8 = null;

        for (parsed.headers) |h| {
            if (std.ascii.eqlIgnoreCase(h[0], "sec-websocket-key")) {
                ws_key = h[1];
            }
            if (std.ascii.eqlIgnoreCase(h[0], "cookie")) {
                cookie_header = h[1];
            }
        }

        // For /ws/cookies endpoint, validate the cookie
        if (std.mem.eql(u8, parsed.path, "/ws/cookies")) {
            const cookie_valid = self.validateWebSocketCookie(cookie_header);
            if (!cookie_valid) {
                // Reject the WebSocket connection with 401
                const reject_response = "HTTP/1.1 401 Unauthorized\r\n" ++
                    "Content-Type: text/plain\r\n" ++
                    "Content-Length: 29\r\n" ++
                    "\r\n" ++
                    "Missing or invalid cookie";
                try stream.writeAll(reject_response);
                return;
            }
        }

        const key = ws_key orelse {
            // Missing WebSocket key - reject
            const reject_response = "HTTP/1.1 400 Bad Request\r\n" ++
                "Content-Type: text/plain\r\n" ++
                "Content-Length: 24\r\n" ++
                "\r\n" ++
                "Missing WebSocket key";
            try stream.writeAll(reject_response);
            return;
        };

        // Calculate Sec-WebSocket-Accept
        const accept_value = try self.calculateWebSocketAccept(key);
        defer self.allocator.free(accept_value);

        // Send upgrade response
        var response_buf: std.ArrayList(u8) = .{};
        defer response_buf.deinit(self.allocator);

        const writer = response_buf.writer(self.allocator);
        try writer.writeAll("HTTP/1.1 101 Switching Protocols\r\n");
        try writer.writeAll("Upgrade: websocket\r\n");
        try writer.writeAll("Connection: Upgrade\r\n");
        try std.fmt.format(writer, "Sec-WebSocket-Accept: {s}\r\n", .{accept_value});
        try writer.writeAll("\r\n");

        try stream.writeAll(response_buf.items);

        // Handle WebSocket frames (simple echo for testing)
        try self.handleWebSocketFrames(stream, parsed.path);
    }

    /// Validate that the WebSocket request contains the expected cookie
    fn validateWebSocketCookie(self: *HttpMockServer, cookie_header: ?[]const u8) bool {
        const expected = self.expected_ws_cookie orelse return false;
        const cookies = cookie_header orelse return false;

        // Parse cookie string
        var iter = std.mem.splitSequence(u8, cookies, "; ");
        while (iter.next()) |cookie| {
            if (std.mem.startsWith(u8, cookie, "session=")) {
                const value = cookie[8..];
                if (std.mem.eql(u8, value, expected)) {
                    return true;
                }
            }
        }

        return false;
    }

    /// Calculate Sec-WebSocket-Accept value per RFC 6455
    fn calculateWebSocketAccept(self: *HttpMockServer, key: []const u8) ![]u8 {
        // Concatenate key with GUID
        var concat_buf: [256]u8 = undefined;
        const concat_len = key.len + WEBSOCKET_GUID.len;
        if (concat_len > concat_buf.len) return error.KeyTooLong;

        @memcpy(concat_buf[0..key.len], key);
        @memcpy(concat_buf[key.len..][0..WEBSOCKET_GUID.len], WEBSOCKET_GUID);

        // SHA-1 hash
        var hash: [Sha1.digest_length]u8 = undefined;
        Sha1.hash(concat_buf[0..concat_len], &hash, .{});

        // Base64 encode - Zig 0.15 API
        const Encoder = base64.standard.Encoder;
        const encoded_len = Encoder.calcSize(hash.len);
        const result = try self.allocator.alloc(u8, encoded_len);
        _ = Encoder.encode(result, &hash);

        return result;
    }

    /// Handle WebSocket frames after upgrade
    fn handleWebSocketFrames(self: *HttpMockServer, stream: std.net.Stream, path: []const u8) !void {
        _ = self;

        var buf: [4096]u8 = undefined;

        // Simple frame handling - just echo or respond based on path
        while (true) {
            const bytes_read = stream.read(&buf) catch |err| {
                if (err == error.ConnectionResetByPeer or err == error.BrokenPipe) {
                    return;
                }
                return err;
            };

            if (bytes_read == 0) return; // Connection closed

            // Parse WebSocket frame (simplified)
            if (bytes_read < 2) continue;

            const opcode = buf[0] & 0x0F;
            const is_masked = (buf[1] & 0x80) != 0;
            var payload_len: usize = buf[1] & 0x7F;
            var offset: usize = 2;

            if (payload_len == 126) {
                if (bytes_read < 4) continue;
                payload_len = (@as(usize, buf[2]) << 8) | @as(usize, buf[3]);
                offset = 4;
            } else if (payload_len == 127) {
                // 64-bit length - skip for simplicity
                continue;
            }

            // Get masking key if present
            var mask: [4]u8 = undefined;
            if (is_masked) {
                if (bytes_read < offset + 4) continue;
                @memcpy(&mask, buf[offset..][0..4]);
                offset += 4;
            }

            // Handle close frame (opcode 8)
            if (opcode == 8) {
                // Send close frame back
                const close_frame = [_]u8{ 0x88, 0x00 }; // Close frame, no payload
                stream.writeAll(&close_frame) catch {};
                return;
            }

            // Handle ping (opcode 9) - respond with pong
            if (opcode == 9) {
                // Send pong with same payload
                var pong_frame: [128]u8 = undefined;
                pong_frame[0] = 0x8A; // Pong, FIN
                pong_frame[1] = @intCast(payload_len);
                if (payload_len > 0 and bytes_read >= offset + payload_len) {
                    @memcpy(pong_frame[2..][0..payload_len], buf[offset..][0..payload_len]);
                    // Unmask if needed
                    if (is_masked) {
                        for (0..payload_len) |i| {
                            pong_frame[2 + i] ^= mask[i % 4];
                        }
                    }
                }
                stream.writeAll(pong_frame[0 .. 2 + payload_len]) catch {};
                continue;
            }

            // Handle text/binary frame (opcode 1 or 2)
            if (opcode == 1 or opcode == 2) {
                if (bytes_read < offset + payload_len) continue;

                // Unmask payload
                var payload: [4096]u8 = undefined;
                if (payload_len > payload.len) continue;

                @memcpy(payload[0..payload_len], buf[offset..][0..payload_len]);
                if (is_masked) {
                    for (0..payload_len) |i| {
                        payload[i] ^= mask[i % 4];
                    }
                }

                // For /ws/cookies path, send success message
                if (std.mem.eql(u8, path, "/ws/cookies")) {
                    const success_msg = "{\"cookie_shared\": true}";
                    var response_frame: [128]u8 = undefined;
                    response_frame[0] = 0x81; // Text frame, FIN
                    response_frame[1] = @intCast(success_msg.len);
                    @memcpy(response_frame[2..][0..success_msg.len], success_msg);
                    stream.writeAll(response_frame[0 .. 2 + success_msg.len]) catch {};
                } else {
                    // Echo back for /ws/echo
                    var response_frame: [4096]u8 = undefined;
                    response_frame[0] = 0x81; // Text frame, FIN
                    response_frame[1] = @intCast(payload_len);
                    @memcpy(response_frame[2..][0..payload_len], payload[0..payload_len]);
                    stream.writeAll(response_frame[0 .. 2 + payload_len]) catch {};
                }
            }
        }
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
