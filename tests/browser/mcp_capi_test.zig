//! Lane mcp-http1, batch 3: Host C ABI MCP start/stop
//! (`crane_browser_start_mcp`, `crane_browser_stop_mcp`, `crane_mcp_info_free`;
//! include/crane.h, src/browser/capi.zig, src/devtools/mcp/http.zig).

const std = @import("std");
const testing = std.testing;
const capi = @import("browser").capi;
const devtools = @import("devtools");

fn postMcp(allocator: std.mem.Allocator, port: u16, token: []const u8, body: []const u8) ![]u8 {
    const fd = std.c.socket(std.c.AF.INET, std.c.SOCK.STREAM, 0);
    if (fd < 0) return error.SocketFailed;
    defer _ = std.c.close(fd);
    var addr: std.c.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
    if (std.c.connect(fd, @ptrCast(&addr), @sizeOf(std.c.sockaddr.in)) != 0) return error.ConnectFailed;
    const req = try std.fmt.allocPrint(allocator, "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nAuthorization: Bearer {s}\r\nMCP-Protocol-Version: 2026-07-28\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ port, token, body.len, body });
    defer allocator.free(req);
    var rest = req;
    while (rest.len > 0) {
        const n = std.c.send(fd, rest.ptr, rest.len, 0);
        if (n <= 0) return error.SendFailed;
        rest = rest[@intCast(n)..];
    }
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    var chunk: [4096]u8 = undefined;
    while (true) {
        var pfd = [_]std.c.pollfd{.{ .fd = fd, .events = std.c.POLL.IN, .revents = 0 }};
        if (std.c.poll(&pfd, 1, 5_000) <= 0) return error.ReadTimeout;
        const n = std.c.recv(fd, &chunk, chunk.len, 0);
        if (n <= 0) break;
        try buf.appendSlice(allocator, chunk[0..@intCast(n)]);
    }
    return buf.toOwnedSlice(allocator);
}

test "C ABI: crane_browser_start_mcp serves Streamable HTTP with bearer token and crane_browser_stop_mcp stops cleanly" {
    if (!devtools.enabled) return error.SkipZigTest;
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));

    var browser: ?*capi.Handle = null;
    try testing.expectEqual(capi.Status.ok, capi.crane_browser_create(null, &browser));
    defer capi.crane_browser_destroy(browser);

    var info: capi.McpInfo = .{};
    try testing.expectEqual(capi.Status.ok, devtools.capi.crane_browser_start_mcp(browser, null, &info));
    defer devtools.capi.crane_mcp_info_free(&info);

    try testing.expect(info.port != 0);
    try testing.expect(!info.tls);
    try testing.expect(info.cert_fingerprint == null);
    const token = std.mem.span(info.bearer_token.?);
    try testing.expectEqual(@as(usize, 64), token.len);

    // Double start on the same browser is refused.
    var dup_info: capi.McpInfo = .{};
    try testing.expectEqual(capi.Status.invalid_argument, devtools.capi.crane_browser_start_mcp(browser, null, &dup_info));

    // Real HTTP POST /mcp call using the returned port and bearer token.
    const body = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"list_pages\",\"arguments\":{},\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}";
    const resp = try postMcp(testing.allocator, info.port, token, body);
    defer testing.allocator.free(resp);
    try testing.expect(std.mem.indexOf(u8, resp, "200 OK") != null);
    try testing.expect(std.mem.indexOf(u8, resp, "about:blank") != null);

    // Stop and confirm idempotency.
    try testing.expectEqual(capi.Status.ok, devtools.capi.crane_browser_stop_mcp(browser));
    try testing.expectEqual(capi.Status.ok, devtools.capi.crane_browser_stop_mcp(browser));
}

test "C ABI: crane_browser_start_mcp with TLS returns SHA-256 fingerprint, validates args, and auto-stops on crane_browser_destroy" {
    if (!devtools.enabled) return error.SkipZigTest;
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));

    var browser: ?*capi.Handle = null;
    try testing.expectEqual(capi.Status.ok, capi.crane_browser_create(null, &browser));
    defer capi.crane_browser_destroy(browser);

    // Invalid arguments: null browser, null out, cert without key.
    var info: capi.McpInfo = .{};
    try testing.expectEqual(capi.Status.invalid_argument, devtools.capi.crane_browser_start_mcp(null, null, &info));
    try testing.expectEqual(capi.Status.invalid_argument, devtools.capi.crane_browser_start_mcp(browser, null, null));
    const bad_tls: capi.McpOptions = .{ .struct_size = @sizeOf(capi.McpOptions), .tls = true, .cert_pem = "-----BEGIN CERTIFICATE-----\n" };
    try testing.expectEqual(capi.Status.invalid_argument, devtools.capi.crane_browser_start_mcp(browser, &bad_tls, &info));

    // Start with TLS, memory_debugging, and filesystem_roots; let crane_browser_destroy stop it.
    const roots = [_][*:0]const u8{"/tmp"};
    const opts: capi.McpOptions = .{
        .struct_size = @sizeOf(capi.McpOptions),
        .host = "127.0.0.1",
        .port = 0,
        .tls = true,
        .memory_debugging = true,
        .filesystem_roots = &roots,
        .filesystem_root_count = roots.len,
    };
    try testing.expectEqual(capi.Status.ok, devtools.capi.crane_browser_start_mcp(browser, &opts, &info));
    defer devtools.capi.crane_mcp_info_free(&info);

    try testing.expect(info.port != 0);
    try testing.expect(info.tls);
    const fp = std.mem.span(info.cert_fingerprint.?);
    try testing.expectEqual(@as(usize, 95), fp.len);
    try testing.expectEqual(@as(u8, ':'), fp[2]);
    // Deliberately do NOT call crane_browser_stop_mcp: defer crane_browser_destroy must stop it cleanly.
}
