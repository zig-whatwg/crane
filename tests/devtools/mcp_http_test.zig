//! Lane mcp-http1, batch 3: Streamable HTTP over TCP for Crane's built-in MCP
//! server (devtools.mcp.http; tmp/plans/mcp1-design.md 2.2 & 3).
//!
//! Tests both MCP eras on `/mcp` (2026-07-28 stateless POST + header validation
//! and 2025-11-25 initialize/Mcp-Session-Id/GET SSE/DELETE), security
//! enforcement (Host, Origin, mandatory 256-bit bearer token on loopback,
//! query-string token refusal, per-connection & per-token 429 rate limiting,
//! mandatory TLS on non-loopback, optional TLS on loopback), and clean
//! wakeable shutdown under leak checking.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const browser_mod = @import("browser");
const devtools = @import("devtools");
const http_mcp = devtools.mcp.http;

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const Fixture = struct {
    allocator: std.mem.Allocator,
    host: *browser_mod.BrowserHost,
    devtools_server: *devtools.Server,
    mcp_http: *http_mcp.HttpServer,

    fn start(allocator: std.mem.Allocator, options: http_mcp.Options) !Fixture {
        const host = try browser_mod.BrowserHost.start(allocator, .{});
        errdefer host.stop();
        const dt = try devtools.Server.start(allocator, .{ .default_host = host });
        errdefer dt.stop();
        const srv = try http_mcp.HttpServer.start(allocator, dt, options);
        return .{ .allocator = allocator, .host = host, .devtools_server = dt, .mcp_http = srv };
    }

    fn stop(self: *Fixture) void {
        self.mcp_http.stop();
        self.devtools_server.stop();
        self.host.stop();
    }
};

fn connectV4(port: u16) !std.c.fd_t {
    const fd = std.c.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
    if (fd < 0) return error.SocketFailed;
    errdefer _ = std.c.close(fd);
    var addr: std.c.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
    if (std.c.connect(fd, @ptrCast(&addr), @sizeOf(std.c.sockaddr.in)) != 0) return error.ConnectFailed;
    return fd;
}

fn sendAll(fd: std.c.fd_t, data: []const u8) !void {
    var rest = data;
    while (rest.len > 0) {
        const n = std.c.send(fd, rest.ptr, rest.len, 0);
        if (n <= 0) return error.SendFailed;
        rest = rest[@intCast(n)..];
    }
}

const RawResponse = struct {
    raw: []u8,
    status: u16,
    head: []const u8,
    body: []const u8,

    fn deinit(self: *RawResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.raw);
    }

    fn header(self: *const RawResponse, name: []const u8) ?[]const u8 {
        var lines = std.mem.splitSequence(u8, self.head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " \t"), name)) {
                return std.mem.trim(u8, line[colon + 1 ..], " \t");
            }
        }
        return null;
    }
};

fn readHttpResponse(allocator: std.mem.Allocator, fd: std.c.fd_t) !RawResponse {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    var chunk: [4096]u8 = undefined;
    var head_end: ?usize = null;
    var content_length: ?usize = null;
    while (true) {
        var pfd = [_]std.c.pollfd{.{ .fd = fd, .events = std.c.POLL.IN, .revents = 0 }};
        const ready = std.c.poll(&pfd, 1, 5_000);
        if (ready <= 0) return error.ReadTimeout;
        const n = std.c.recv(fd, &chunk, chunk.len, 0);
        if (n <= 0) break;
        try buf.appendSlice(allocator, chunk[0..@intCast(n)]);
        if (head_end == null) {
            if (std.mem.indexOf(u8, buf.items, "\r\n\r\n")) |idx| {
                head_end = idx + 4;
                var lines = std.mem.splitSequence(u8, buf.items[0..idx], "\r\n");
                _ = lines.next();
                while (lines.next()) |line| {
                    const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
                    if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " \t"), "content-length")) {
                        content_length = std.fmt.parseUnsigned(usize, std.mem.trim(u8, line[colon + 1 ..], " \t"), 10) catch null;
                    }
                }
            }
        }
        if (head_end) |he| {
            if (content_length) |cl| {
                if (buf.items.len >= he + cl) break;
            }
        }
    }
    const he = head_end orelse return error.MalformedResponse;
    const raw = try buf.toOwnedSlice(allocator);
    const first_line_end = std.mem.indexOf(u8, raw[0..he], "\r\n") orelse he;
    var parts = std.mem.tokenizeScalar(u8, raw[0..first_line_end], ' ');
    _ = parts.next();
    const status_str = parts.next() orelse return error.MalformedResponse;
    const status = std.fmt.parseUnsigned(u16, status_str, 10) catch return error.MalformedResponse;
    return .{
        .raw = raw,
        .status = status,
        .head = raw[0 .. he - 4],
        .body = raw[he..],
    };
}

fn sendRequest(allocator: std.mem.Allocator, port: u16, raw_req: []const u8) !RawResponse {
    const fd = try connectV4(port);
    defer _ = std.c.close(fd);
    try sendAll(fd, raw_req);
    return readHttpResponse(allocator, fd);
}

test "mcp http 2026-07-28: discover, tools/list, tools/call, header mismatch -32020, unsupported -32022, base64 Mcp-Name, GET/DELETE 405" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{});
    defer fx.stop();
    const port = fx.mcp_http.boundPort();
    const token = fx.mcp_http.bearerToken();
    try testing.expectEqual(@as(usize, 64), token.len);
    try testing.expect(!fx.mcp_http.isTls());
    try testing.expect(fx.mcp_http.certFingerprint() == null);

    // 1. server/discover
    const discover_body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"server/discover\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";
    const req1 = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nAccept: application/json, text/event-stream\r\nContent-Type: application/json\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: server/discover\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, discover_body.len, discover_body });
    defer allocator.free(req1);
    var res1 = try sendRequest(allocator, port, req1);
    defer res1.deinit(allocator);
    try testing.expectEqual(@as(u16, 200), res1.status);
    try testing.expect(res1.header("mcp-session-id") == null);
    try testing.expect(std.mem.indexOf(u8, res1.body, "\"supportedVersions\":[\"2026-07-28\",\"2025-11-25\"") != null);

    // 2. tools/call list_pages with RFC =?base64?...?= encoded Mcp-Name ("bGlzdF9wYWdlcw==")
    const call_body = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"list_pages\",\"arguments\":{},\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";
    const req2 = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: localhost:{d}\r\nAuthorization: Bearer {s}\r\nContent-Type: application/json\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: tools/call\r\nMcp-Name: =?base64?bGlzdF9wYWdlcw==?=\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, call_body.len, call_body });
    defer allocator.free(req2);
    var res2 = try sendRequest(allocator, port, req2);
    defer res2.deinit(allocator);
    try testing.expectEqual(@as(u16, 200), res2.status);
    try testing.expect(std.mem.indexOf(u8, res2.body, "\"resultType\":\"complete\"") != null);
    try testing.expect(std.mem.indexOf(u8, res2.body, "about:blank") != null);

    // 3. MCP-Protocol-Version header mismatch against _meta -> 400 / -32020
    const req3 = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nContent-Type: application/json\r\nMCP-Protocol-Version: 2025-11-25\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, discover_body.len, discover_body });
    defer allocator.free(req3);
    var res3 = try sendRequest(allocator, port, req3);
    defer res3.deinit(allocator);
    try testing.expectEqual(@as(u16, 400), res3.status);
    try testing.expect(std.mem.indexOf(u8, res3.body, "\"code\":-32020") != null);

    // 4. Unsupported protocol version -> 400 / -32022 listing supported versions
    const bad_ver_body = "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"1999-01-01\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";
    const req4 = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nContent-Type: application/json\r\nMCP-Protocol-Version: 1999-01-01\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, bad_ver_body.len, bad_ver_body });
    defer allocator.free(req4);
    var res4 = try sendRequest(allocator, port, req4);
    defer res4.deinit(allocator);
    try testing.expectEqual(@as(u16, 400), res4.status);
    try testing.expect(std.mem.indexOf(u8, res4.body, "\"code\":-32022") != null);
    try testing.expect(std.mem.indexOf(u8, res4.body, "\"supported\":") != null);

    // 5. Mcp-Method mismatch -> 400 / -32020
    const req5 = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nContent-Type: application/json\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: tools/list\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, call_body.len, call_body });
    defer allocator.free(req5);
    var res5 = try sendRequest(allocator, port, req5);
    defer res5.deinit(allocator);
    try testing.expectEqual(@as(u16, 400), res5.status);
    try testing.expect(std.mem.indexOf(u8, res5.body, "\"code\":-32020") != null);

    // 6. Mcp-Name mismatch -> 400 / -32020
    const req6 = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nContent-Type: application/json\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: tools/call\r\nMcp-Name: other_tool\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, call_body.len, call_body });
    defer allocator.free(req6);
    var res6 = try sendRequest(allocator, port, req6);
    defer res6.deinit(allocator);
    try testing.expectEqual(@as(u16, 400), res6.status);
    try testing.expect(std.mem.indexOf(u8, res6.body, "\"code\":-32020") != null);

    // 7. GET and DELETE in 2026-07-28 era -> 405 Method Not Allowed
    const req_get = try std.fmt.allocPrint(allocator, "GET /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nAccept: text/event-stream\r\nConnection: close\r\n\r\n", .{ port, token });
    defer allocator.free(req_get);
    var res_get = try sendRequest(allocator, port, req_get);
    defer res_get.deinit(allocator);
    try testing.expectEqual(@as(u16, 405), res_get.status);

    const req_del = try std.fmt.allocPrint(allocator, "DELETE /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nConnection: close\r\n\r\n", .{ port, token });
    defer allocator.free(req_del);
    var res_del = try sendRequest(allocator, port, req_del);
    defer res_del.deinit(allocator);
    try testing.expectEqual(@as(u16, 405), res_del.status);
}

test "mcp http 2025-11-25: initialize mints Mcp-Session-Id, GET SSE stream primes and closes on DELETE, deleted session returns 404" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{});
    defer fx.stop();
    const port = fx.mcp_http.boundPort();
    const token = fx.mcp_http.bearerToken();

    // 1. initialize
    const init_body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{}}}";
    const req_init = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, init_body.len, init_body });
    defer allocator.free(req_init);
    var res_init = try sendRequest(allocator, port, req_init);
    defer res_init.deinit(allocator);
    try testing.expectEqual(@as(u16, 200), res_init.status);
    const session_id = res_init.header("mcp-session-id") orelse return error.MissingSessionId;
    try testing.expect(session_id.len >= 16);

    // 2. notifications/initialized -> 202 Accepted
    const notif_body = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}";
    const req_notif = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2025-11-25\r\nMcp-Session-Id: {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, session_id, notif_body.len, notif_body });
    defer allocator.free(req_notif);
    var res_notif = try sendRequest(allocator, port, req_notif);
    defer res_notif.deinit(allocator);
    try testing.expectEqual(@as(u16, 202), res_notif.status);

    // 3. Open GET SSE stream on the session and confirm priming event arrives.
    const sse_fd = try connectV4(port);
    defer _ = std.c.close(sse_fd);
    const req_sse = try std.fmt.allocPrint(allocator, "GET /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2025-11-25\r\nMcp-Session-Id: {s}\r\nAccept: text/event-stream\r\n\r\n", .{ port, token, session_id });
    defer allocator.free(req_sse);
    try sendAll(sse_fd, req_sse);

    var sse_buf: [1024]u8 = undefined;
    var sse_len: usize = 0;
    while (std.mem.indexOf(u8, sse_buf[0..sse_len], "\n\n") == null) {
        var pfd = [_]std.c.pollfd{.{ .fd = sse_fd, .events = std.c.POLL.IN, .revents = 0 }};
        try testing.expect(std.c.poll(&pfd, 1, 3_000) > 0);
        const n = std.c.recv(sse_fd, sse_buf[sse_len..].ptr, sse_buf.len - sse_len, 0);
        try testing.expect(n > 0);
        sse_len += @intCast(n);
    }
    const sse_head = sse_buf[0..sse_len];
    try testing.expect(std.mem.indexOf(u8, sse_head, "200 OK") != null);
    try testing.expect(std.mem.indexOf(u8, sse_head, "text/event-stream") != null);
    try testing.expect(std.mem.indexOf(u8, sse_head, "id: ") != null);

    // 4. DELETE session -> 200 OK, closes SSE stream, and subsequent request returns 404.
    const req_del = try std.fmt.allocPrint(allocator, "DELETE /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2025-11-25\r\nMcp-Session-Id: {s}\r\nConnection: close\r\n\r\n", .{ port, token, session_id });
    defer allocator.free(req_del);
    var res_del = try sendRequest(allocator, port, req_del);
    defer res_del.deinit(allocator);
    try testing.expectEqual(@as(u16, 200), res_del.status);

    // SSE stream should reach EOF promptly after DELETE.
    var pfd = [_]std.c.pollfd{.{ .fd = sse_fd, .events = std.c.POLL.IN, .revents = 0 }};
    try testing.expect(std.c.poll(&pfd, 1, 3_000) > 0);
    var eof_buf: [64]u8 = undefined;
    try testing.expectEqual(@as(isize, 0), std.c.recv(sse_fd, &eof_buf, eof_buf.len, 0));

    // Subsequent POST with deleted session ID -> 404.
    const list_body = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}";
    const req_after = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2025-11-25\r\nMcp-Session-Id: {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, session_id, list_body.len, list_body });
    defer allocator.free(req_after);
    var res_after = try sendRequest(allocator, port, req_after);
    defer res_after.deinit(allocator);
    try testing.expectEqual(@as(u16, 404), res_after.status);
}

test "mcp http security: Host, Origin, mandatory Bearer token, query token refusal, 429 rate limiting, and non-loopback TLS requirement" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    // Non-loopback without TLS must be refused at start.
    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const dt = try devtools.Server.start(allocator, .{ .default_host = host });
    defer dt.stop();
    try testing.expectError(error.TlsRequired, http_mcp.HttpServer.start(allocator, dt, .{
        .host = "0.0.0.0",
        .port = 0,
        .tls = .disabled,
    }));

    // Start loopback server with tight rate limit (3 requests per token window) and one allowed origin.
    const allowed = [_][]const u8{"http://localhost:3000"};
    const srv = try http_mcp.HttpServer.start(allocator, dt, .{
        .allowed_origins = &allowed,
        .max_requests_per_connection = 10,
        .max_requests_per_token = 3,
        .rate_limit_window_ms = 60_000,
    });
    defer srv.stop();
    const port = srv.boundPort();
    const token = srv.bearerToken();
    const body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";

    // Bad Host -> 403
    {
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: evil.example:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, body.len, body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 403), res.status);
    }

    // Disallowed Origin -> 403
    {
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nOrigin: https://attacker.example\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, body.len, body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 403), res.status);
    }

    // Missing token on loopback -> 401
    {
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nMCP-Protocol-Version: 2026-07-28\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, body.len, body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 401), res.status);
    }

    // Wrong token -> 401
    {
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer deadbeef\r\nMCP-Protocol-Version: 2026-07-28\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, body.len, body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 401), res.status);
    }

    // Token in query string -> never accepted (400/401)
    {
        const req = try std.fmt.allocPrint(allocator, "POST /mcp?token={s} HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nMCP-Protocol-Version: 2026-07-28\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ token, port, body.len, body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expect(res.status == 400 or res.status == 401);
    }

    // Allowed Origin + valid token: first 3 succeed, 4th hits 429 Too Many Requests
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nOrigin: http://localhost:3000\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, body.len, body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(if (i < 3) @as(u16, 200) else @as(u16, 429), res.status);
    }
}

test "mcp http tls: loopback TLS server exposes 95-char SHA-256 fingerprint and stops cleanly" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{ .host = "127.0.0.1", .port = 0, .tls = .required });
    defer fx.stop();
    try testing.expect(fx.mcp_http.isTls());
    const fp = fx.mcp_http.certFingerprint() orelse return error.ExpectedFingerprint;
    try testing.expectEqual(@as(usize, 95), fp.len);
    try testing.expectEqual(@as(u8, ':'), fp[2]);
}

test "mcp http options: --slim and --categoryNetworkMocks forward into McpServer tool list" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    const list_body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";

    // --slim exposes only navigate, evaluate, screenshot (not list_pages).
    {
        var fx = try Fixture.start(allocator, .{
            .host = "127.0.0.1",
            .port = 0,
            .mcp = .{ .slim = true },
        });
        defer fx.stop();
        const port = fx.mcp_http.boundPort();
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: tools/list\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, fx.mcp_http.bearerToken(), list_body.len, list_body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 200), res.status);
        try testing.expect(std.mem.indexOf(u8, res.body, "\"name\":\"navigate\"") != null);
        try testing.expect(std.mem.indexOf(u8, res.body, "\"name\":\"evaluate\"") != null);
        try testing.expect(std.mem.indexOf(u8, res.body, "\"name\":\"list_pages\"") == null);
    }

    // --categoryNetworkMocks exposes mock_network and remove_network_mock.
    {
        var fx = try Fixture.start(allocator, .{
            .host = "127.0.0.1",
            .port = 0,
            .mcp = .{ .category_network_mocks = true },
        });
        defer fx.stop();
        const port = fx.mcp_http.boundPort();
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: tools/list\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, fx.mcp_http.bearerToken(), list_body.len, list_body });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 200), res.status);
        try testing.expect(std.mem.indexOf(u8, res.body, "\"name\":\"mock_network\"") != null);
        try testing.expect(std.mem.indexOf(u8, res.body, "\"name\":\"remove_network_mock\"") != null);
    }
}
