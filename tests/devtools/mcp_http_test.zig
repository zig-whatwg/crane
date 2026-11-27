//! Lane mcp-http1, batch 3: Streamable HTTP over TCP for Crane's built-in MCP
//! server (devtools.mcp.http; tmp/plans/mcp1-design.md 2.2 & 3).
//!
//! Tests both MCP eras on `/mcp` (2026-07-28 stateless POST + header validation
//! and 2025-11-25 initialize/Mcp-Session-Id/GET SSE/DELETE), security
//! enforcement (Host, Origin, mandatory 256-bit bearer token on loopback,
//! query-string token refusal, per-connection & per-token 429 rate limiting,
//! mandatory TLS on non-loopback, optional TLS on loopback), and clean
//! wakeable shutdown under leak checking.
//!
//! Lane mcp3, batch A (audit report C, H1/M3/M4): sessions are freed when
//! they end and bounded while they live; connections that have not
//! authenticated never hold one of the authenticated slots and end at a
//! deadline; kept-alive, stalled and idle connections and idle sessions time
//! out; a session's first tools/call waits for the client's roots as the
//! stdio transport does (chrome-devtools-mcp src/index.ts #getContext).

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const browser_mod = @import("browser");
const devtools = @import("devtools");
const http_mcp = devtools.mcp.http;

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });
/// The same, counting the bytes live (`debug.total_requested_bytes`).
const Counted = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true, .enable_memory_limit = true });

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

// ---------------------------------------------------------------------------
// Lane mcp3, batch A: session lifetime (H1), slots and timeouts (M3), the
// roots wait (M4).
// ---------------------------------------------------------------------------

const legacy_init = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{}}}";
const legacy_init_roots = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{\"roots\":{\"listChanged\":true}}}}";
const initialized_note = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}";
const modern_ping = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";
const list_pages_call = "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"list_pages\",\"arguments\":{}}}";

/// Descriptors open in this process now (0..4095, probed with F_GETFD).
fn openDescriptorCount() usize {
    var count: usize = 0;
    var fd: std.c.fd_t = 0;
    while (fd < 4096) : (fd += 1) {
        if (std.c.fcntl(fd, std.c.F.GETFD) != -1) count += 1;
    }
    return count;
}

/// Wait until the server holds no connection (its workers have closed their
/// sockets): what a descriptor count must wait for.
fn waitForNoConnections(srv: *http_mcp.HttpServer) !void {
    const deadline = platform.monotonicMillis() + 5_000;
    while (srv.connectionCount() != 0) {
        if (platform.monotonicMillis() >= deadline) return error.ConnectionsStayed;
        platform.sleepThread(5 * std.time.ns_per_ms);
    }
}

/// Whether the server closes `fd` within `timeout_ms` (what it sends first is
/// discarded).
fn serverClosed(fd: std.c.fd_t, timeout_ms: i64) bool {
    const deadline = platform.monotonicMillis() + timeout_ms;
    while (true) {
        const left = deadline - platform.monotonicMillis();
        if (left <= 0) return false;
        var pfd = [_]std.c.pollfd{.{ .fd = fd, .events = std.c.POLL.IN, .revents = 0 }};
        if (std.c.poll(&pfd, 1, @intCast(left)) <= 0) return false;
        var chunk: [1024]u8 = undefined;
        if (std.c.recv(fd, &chunk, chunk.len, 0) <= 0) return true;
    }
}

/// One client connection read a little at a time (an event stream, a
/// kept-alive connection).
const Client = struct {
    fd: std.c.fd_t,
    buf: std.ArrayList(u8) = .empty,

    fn open(port: u16) !Client {
        return .{ .fd = try connectV4(port) };
    }

    fn close(self: *Client, allocator: std.mem.Allocator) void {
        _ = std.c.close(self.fd);
        self.buf.deinit(allocator);
    }

    fn send(self: *Client, data: []const u8) !void {
        try sendAll(self.fd, data);
    }

    /// Read until `needle` is in what was read from `from` on; the index just
    /// past it. error.ReadTimeout after `timeout_ms`; error.Closed when the
    /// server ends the connection first.
    fn readUntil(self: *Client, allocator: std.mem.Allocator, needle: []const u8, from: usize, timeout_ms: i64) !usize {
        const deadline = platform.monotonicMillis() + timeout_ms;
        while (true) {
            if (from <= self.buf.items.len) {
                if (std.mem.indexOf(u8, self.buf.items[from..], needle)) |at| return from + at + needle.len;
            }
            const left = deadline - platform.monotonicMillis();
            if (left <= 0) return error.ReadTimeout;
            var pfd = [_]std.c.pollfd{.{ .fd = self.fd, .events = std.c.POLL.IN, .revents = 0 }};
            if (std.c.poll(&pfd, 1, @intCast(left)) <= 0) return error.ReadTimeout;
            var chunk: [4096]u8 = undefined;
            const n = std.c.recv(self.fd, &chunk, chunk.len, 0);
            if (n <= 0) return error.Closed;
            try self.buf.appendSlice(allocator, chunk[0..@intCast(n)]);
        }
    }

    /// Whether the server closes the connection within `timeout_ms` (what it
    /// sends first is kept).
    fn closedWithin(self: *Client, allocator: std.mem.Allocator, timeout_ms: i64) !bool {
        _ = self.readUntil(allocator, "\x00never sent\x00", self.buf.items.len, timeout_ms) catch |err| switch (err) {
            error.Closed => return true,
            error.ReadTimeout => return false,
            else => return err,
        };
        return false;
    }
};

/// A POST /mcp: `session` adds its Mcp-Session-Id and the legacy version
/// header; `extra` adds header lines (each ending in CRLF).
fn postRequest(allocator: std.mem.Allocator, port: u16, token: []const u8, session: ?[]const u8, extra: []const u8, body: []const u8, close_conn: bool) ![]u8 {
    const session_lines = if (session) |sid|
        try std.fmt.allocPrint(allocator, "Mcp-Session-Id: {s}\r\nMCP-Protocol-Version: 2025-11-25\r\n", .{sid})
    else
        try allocator.dupe(u8, "");
    defer allocator.free(session_lines);
    return std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nContent-Type: application/json\r\n{s}{s}Content-Length: {d}\r\n{s}\r\n{s}", .{
        port,
        token,
        session_lines,
        extra,
        body.len,
        if (close_conn) "Connection: close\r\n" else "",
        body,
    });
}

/// Initialize a legacy session; its id (allocated).
fn initSession(allocator: std.mem.Allocator, port: u16, token: []const u8, body: []const u8) ![]u8 {
    const req = try postRequest(allocator, port, token, null, "", body, true);
    defer allocator.free(req);
    var res = try sendRequest(allocator, port, req);
    defer res.deinit(allocator);
    if (res.status != 200) return error.InitializeFailed;
    return allocator.dupe(u8, res.header("mcp-session-id") orelse return error.MissingSessionId);
}

/// POST `body` on session `sid`; the status.
fn sessionPost(allocator: std.mem.Allocator, port: u16, token: []const u8, sid: []const u8, body: []const u8) !u16 {
    const req = try postRequest(allocator, port, token, sid, "", body, true);
    defer allocator.free(req);
    var res = try sendRequest(allocator, port, req);
    defer res.deinit(allocator);
    return res.status;
}

/// DELETE session `sid`; the status.
fn sessionDelete(allocator: std.mem.Allocator, port: u16, token: []const u8, sid: []const u8) !u16 {
    const req = try std.fmt.allocPrint(allocator, "DELETE /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2025-11-25\r\nMcp-Session-Id: {s}\r\nConnection: close\r\n\r\n", .{ port, token, sid });
    defer allocator.free(req);
    var res = try sendRequest(allocator, port, req);
    defer res.deinit(allocator);
    return res.status;
}

/// Open session `sid`'s GET event stream and read its priming event; the
/// index just past it.
fn openStream(allocator: std.mem.Allocator, client: *Client, port: u16, token: []const u8, sid: []const u8) !usize {
    const req = try std.fmt.allocPrint(allocator, "GET /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2025-11-25\r\nMcp-Session-Id: {s}\r\nAccept: text/event-stream\r\n\r\n", .{ port, token, sid });
    defer allocator.free(req);
    try client.send(req);
    const head_end = try client.readUntil(allocator, "\r\n\r\n", 0, 3_000);
    if (std.mem.indexOf(u8, client.buf.items[0..head_end], "text/event-stream") == null) return error.NotAnEventStream;
    return client.readUntil(allocator, "\n\n", head_end, 3_000);
}

/// The JSON of the first `data:` line in `bytes`.
fn firstEventData(bytes: []const u8) ?[]const u8 {
    const at = std.mem.indexOf(u8, bytes, "data: ") orelse return null;
    const rest = bytes[at + "data: ".len ..];
    const end = std.mem.indexOfScalar(u8, rest, '\n') orelse return null;
    return rest[0..end];
}

test "mcp http sessions: 300 initialize cycles - ended by DELETE, by DELETE after a GET stream, or by the client leaving - leave descriptors, sessions and memory where they were (audit H1)" {
    var debug_alloc: Counted = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{ .max_connections = 4, .max_requests_per_connection = 0, .max_requests_per_token = 0 });
    defer fx.stop();
    const srv = fx.mcp_http;
    const port = srv.boundPort();
    const token = srv.bearerToken();

    const Cycle = struct {
        fn run(a: std.mem.Allocator, p: u16, t: []const u8, i: usize) !void {
            const sid = try initSession(a, p, t, legacy_init);
            defer a.free(sid);
            try testing.expectEqual(@as(u16, 202), try sessionPost(a, p, t, sid, initialized_note));
            switch (i % 3) {
                0 => try testing.expectEqual(@as(u16, 200), try sessionDelete(a, p, t, sid)),
                1 => {
                    var stream = try Client.open(p);
                    defer stream.close(a);
                    _ = try openStream(a, &stream, p, t, sid);
                    try testing.expectEqual(@as(u16, 200), try sessionDelete(a, p, t, sid));
                    // DELETE ends the session's stream.
                    try testing.expect(try stream.closedWithin(a, 3_000));
                },
                // The client leaves without a DELETE.
                else => {},
            }
        }
    };
    // Warm up past the session cap (2 x max_connections), so the list and
    // the buffers have their size.
    var i: usize = 0;
    while (i < 12) : (i += 1) try Cycle.run(allocator, port, token, i);
    try waitForNoConnections(srv);
    const descriptors_before = openDescriptorCount();
    const bytes_before = debug_alloc.debug.total_requested_bytes;

    while (i < 312) : (i += 1) try Cycle.run(allocator, port, token, i);
    try waitForNoConnections(srv);

    const descriptors_after = openDescriptorCount();
    const bytes_after = debug_alloc.debug.total_requested_bytes;
    const sessions_after = srv.sessionCount();
    if (sessions_after > 8 or descriptors_after > descriptors_before or bytes_after > bytes_before + 16 * 1024) {
        std.debug.print("after 300 cycles: {d} sessions (cap 8), descriptors {d} -> {d}, live bytes {d} -> {d}\n", .{ sessions_after, descriptors_before, descriptors_after, bytes_before, bytes_after });
        return error.SessionsNotFreed;
    }
}

test "mcp http slots: twelve idle sockets that never authenticate cannot lock the agent out of 2 slots, and each ends by the auth deadline, TLS handshakes included (audit M3)" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    {
        var fx = try Fixture.start(allocator, .{ .max_connections = 2, .max_pending_connections = 4, .auth_timeout_ms = 300, .reap_interval_ms = 20 });
        defer fx.stop();
        const port = fx.mcp_http.boundPort();
        var idle: [12]std.c.fd_t = undefined;
        var opened: usize = 0;
        defer for (idle[0..opened]) |fd| {
            _ = std.c.close(fd);
        };
        while (opened < idle.len) : (opened += 1) idle[opened] = try connectV4(port);

        // The agent's own request, while all twelve sit idle.
        const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: ping\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, fx.mcp_http.bearerToken(), modern_ping.len, modern_ping });
        defer allocator.free(req);
        var res = try sendRequest(allocator, port, req);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 200), res.status);

        // The server closes every idle socket (300 ms deadline; it looks every 20 ms).
        for (idle) |fd| try testing.expect(serverClosed(fd, 3_000));
    }

    // A TLS handshake that never starts ends at the same deadline.
    {
        var fx = try Fixture.start(allocator, .{ .tls = .required, .max_connections = 2, .max_pending_connections = 4, .auth_timeout_ms = 300, .reap_interval_ms = 20 });
        defer fx.stop();
        const port = fx.mcp_http.boundPort();
        var idle: [3]std.c.fd_t = undefined;
        var opened: usize = 0;
        defer for (idle[0..opened]) |fd| {
            _ = std.c.close(fd);
        };
        while (opened < idle.len) : (opened += 1) idle[opened] = try connectV4(port);
        for (idle) |fd| try testing.expect(serverClosed(fd, 3_000));
    }
}

test "mcp http timeouts: a kept-alive connection gone idle, a request head that stalls, a wrong token with a body never sent, and a session gone idle all end (audit M3)" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{ .keep_alive_timeout_ms = 200, .request_timeout_ms = 300, .session_idle_timeout_ms = 300, .reap_interval_ms = 20 });
    defer fx.stop();
    const port = fx.mcp_http.boundPort();
    const token = fx.mcp_http.bearerToken();
    const ping = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: ping\r\nContent-Length: {d}\r\n\r\n{s}", .{ port, token, modern_ping.len, modern_ping });
    defer allocator.free(ping);

    // 1. Kept alive (Node's http.Server answers Keep-Alive: timeout=), then idle.
    {
        var c = try Client.open(port);
        defer c.close(allocator);
        try c.send(ping);
        _ = try c.readUntil(allocator, "\"resultType\":\"complete\"", 0, 3_000);
        try testing.expect(std.mem.indexOf(u8, c.buf.items, "Connection: keep-alive") != null);
        try testing.expect(std.mem.indexOf(u8, c.buf.items, "Keep-Alive: timeout=") != null);
        try testing.expect(try c.closedWithin(allocator, 3_000));
    }

    // 2. A second request whose head stops halfway.
    {
        var c = try Client.open(port);
        defer c.close(allocator);
        try c.send(ping);
        _ = try c.readUntil(allocator, "\"resultType\":\"complete\"", 0, 3_000);
        try c.send("POST /mcp HTTP/1.1\r\nHost: 127.0.0.1\r\n");
        try testing.expect(try c.closedWithin(allocator, 3_000));
    }

    // 3. A wrong token is refused from the head alone: the 4 MB body it
    //    announces is never waited for.
    {
        var c = try Client.open(port);
        defer c.close(allocator);
        try c.send("POST /mcp HTTP/1.1\r\nHost: 127.0.0.1\r\nAuthorization: Bearer wrong\r\nContent-Length: 4000000\r\n\r\n");
        _ = try c.readUntil(allocator, "401 Unauthorized", 0, 2_000);
    }

    // 4. A session left idle past its timeout answers 404 ("The server MAY
    //    terminate the session at any time, after which it MUST respond to
    //    requests containing that session ID with HTTP 404 Not Found").
    {
        const sid = try initSession(allocator, port, token, legacy_init);
        defer allocator.free(sid);
        try testing.expectEqual(@as(u16, 202), try sessionPost(allocator, port, token, sid, initialized_note));
        platform.sleepThread(800 * std.time.ns_per_ms);
        try testing.expectEqual(@as(u16, 404), try sessionPost(allocator, port, token, sid, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}"));
    }
}

test "mcp http roots: a session's first tools/call asks for the client's roots on its own event stream and answers once they come; a later call does not wait (audit M4; chrome-devtools-mcp src/index.ts #getContext)" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{ .mcp = .{ .roots_timeout_ms = 10_000 } });
    defer fx.stop();
    const port = fx.mcp_http.boundPort();
    const token = fx.mcp_http.bearerToken();
    const sid = try initSession(allocator, port, token, legacy_init_roots);
    defer allocator.free(sid);
    try testing.expectEqual(@as(u16, 202), try sessionPost(allocator, port, token, sid, initialized_note));

    var call = try Client.open(port);
    defer call.close(allocator);
    const req = try postRequest(allocator, port, token, sid, "Accept: application/json, text/event-stream\r\n", list_pages_call, false);
    defer allocator.free(req);
    try call.send(req);
    const head_end = try call.readUntil(allocator, "\r\n\r\n", 0, 3_000);
    const head = call.buf.items[0..head_end];
    try testing.expect(std.mem.indexOf(u8, head, "200 OK") != null);
    try testing.expect(std.mem.indexOf(u8, head, "Content-Type: text/event-stream") != null);
    const first_end = try call.readUntil(allocator, "\n\n", head_end, 3_000);
    const data = firstEventData(call.buf.items[head_end..first_end]) orelse return error.NoEvent;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const request = try std.json.parseFromSliceLeaky(std.json.Value, arena_state.allocator(), data, .{});
    try testing.expectEqualStrings("roots/list", request.object.get("method").?.string);
    const roots_id = request.object.get("id").?.integer;

    // The client answers on a connection of its own; the call goes on.
    const answered_at = platform.monotonicMillis();
    const answer = try std.fmt.allocPrint(allocator, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":{{\"roots\":[{{\"uri\":\"file:///tmp\",\"name\":\"tmp\"}}]}}}}", .{roots_id});
    defer allocator.free(answer);
    try testing.expectEqual(@as(u16, 202), try sessionPost(allocator, port, token, sid, answer));
    const result_end = try call.readUntil(allocator, "## Pages", first_end, 5_000);
    try testing.expect(platform.monotonicMillis() - answered_at < 5_000);
    try testing.expect(std.mem.indexOf(u8, call.buf.items[first_end..result_end], "\"id\":7") != null);
    // The final response ends the stream.
    try testing.expect(try call.closedWithin(allocator, 3_000));

    // The roots came: a later call is answered at once, as JSON.
    const again = try postRequest(allocator, port, token, sid, "Accept: application/json, text/event-stream\r\n", list_pages_call, true);
    defer allocator.free(again);
    var res = try sendRequest(allocator, port, again);
    defer res.deinit(allocator);
    try testing.expectEqual(@as(u16, 200), res.status);
    try testing.expect(std.mem.startsWith(u8, res.header("content-type") orelse "", "application/json"));
    try testing.expect(std.mem.indexOf(u8, res.body, "## Pages") != null);
}

test "mcp http roots: a client that never answers delays only its first tools/call, by the roots timeout" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{ .mcp = .{ .roots_timeout_ms = 400 } });
    defer fx.stop();
    const port = fx.mcp_http.boundPort();
    const token = fx.mcp_http.bearerToken();
    const sid = try initSession(allocator, port, token, legacy_init_roots);
    defer allocator.free(sid);
    try testing.expectEqual(@as(u16, 202), try sessionPost(allocator, port, token, sid, initialized_note));

    var call = try Client.open(port);
    defer call.close(allocator);
    const req = try postRequest(allocator, port, token, sid, "Accept: application/json, text/event-stream\r\n", list_pages_call, false);
    defer allocator.free(req);
    const sent_at = platform.monotonicMillis();
    try call.send(req);
    const asked_end = try call.readUntil(allocator, "roots/list", 0, 3_000);
    _ = try call.readUntil(allocator, "## Pages", asked_end, 5_000);
    const waited = platform.monotonicMillis() - sent_at;
    try testing.expect(waited >= 350);

    // The wait is over for good: the next call does not wait.
    const again = try postRequest(allocator, port, token, sid, "Accept: application/json, text/event-stream\r\n", list_pages_call, true);
    defer allocator.free(again);
    var res = try sendRequest(allocator, port, again);
    defer res.deinit(allocator);
    try testing.expectEqual(@as(u16, 200), res.status);
    try testing.expect(std.mem.startsWith(u8, res.header("content-type") orelse "", "application/json"));
}

test "mcp http GET stream: a server message queued while the session's stream waits reaches it; a second GET stream on the session is 409 (the MCP TypeScript SDK's StreamableHTTPServerTransport allows one)" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    var fx = try Fixture.start(allocator, .{});
    defer fx.stop();
    const port = fx.mcp_http.boundPort();
    const token = fx.mcp_http.bearerToken();
    const sid = try initSession(allocator, port, token, legacy_init_roots);
    defer allocator.free(sid);

    var stream = try Client.open(port);
    defer stream.close(allocator);
    const primed_end = try openStream(allocator, &stream, port, token, sid);
    // Let the stream settle into its wait.
    platform.sleepThread(100 * std.time.ns_per_ms);
    // notifications/initialized asks the client for its roots (#updateRoots),
    // on the stream.
    try testing.expectEqual(@as(u16, 202), try sessionPost(allocator, port, token, sid, initialized_note));
    _ = try stream.readUntil(allocator, "\"method\":\"roots/list\"", primed_end, 3_000);

    const second = try std.fmt.allocPrint(allocator, "GET /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2025-11-25\r\nMcp-Session-Id: {s}\r\nAccept: text/event-stream\r\nConnection: close\r\n\r\n", .{ port, token, sid });
    defer allocator.free(second);
    var res = try sendRequest(allocator, port, second);
    defer res.deinit(allocator);
    try testing.expectEqual(@as(u16, 409), res.status);
}

test "mcp http options: --categoryExperimentalThirdParty and --experimentalVision forward into McpServer's tool list and calls (audit M2)" {
    var debug_alloc: LeakChecked = .init;
    defer testing.expect(debug_alloc.deinit() == .ok) catch {};
    const allocator = debug_alloc.allocator();

    const list_body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";
    const call_body = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"list_3p_developer_tools\",\"arguments\":{\"pageId\":1},\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";
    inline for (.{ false, true }) |on| {
        var fx = try Fixture.start(allocator, .{ .mcp = .{ .category_experimental_third_party = on, .experimental_vision = on } });
        defer fx.stop();
        const port = fx.mcp_http.boundPort();
        const list = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: tools/list\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, fx.mcp_http.bearerToken(), list_body.len, list_body });
        defer allocator.free(list);
        var res = try sendRequest(allocator, port, list);
        defer res.deinit(allocator);
        try testing.expectEqual(@as(u16, 200), res.status);
        for ([_][]const u8{ "\"name\":\"list_3p_developer_tools\"", "\"name\":\"execute_3p_developer_tool\"", "\"name\":\"click_at\"" }) |name| {
            try testing.expectEqual(on, std.mem.indexOf(u8, res.body, name) != null);
        }
        // Off, a call is "Tool <name> disabled"; on, the tool answers.
        const call = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nMcp-Method: tools/call\r\nMcp-Name: list_3p_developer_tools\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, fx.mcp_http.bearerToken(), call_body.len, call_body });
        defer allocator.free(call);
        var answered = try sendRequest(allocator, port, call);
        defer answered.deinit(allocator);
        try testing.expectEqual(!on, std.mem.indexOf(u8, answered.body, "Tool list_3p_developer_tools disabled") != null);
    }
}
