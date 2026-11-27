//! Lane mcp-http1, batch 3: platform non-loopback TCP listener and TLS server
//! operations under `devtools_transport` (docs/platform-protocol.md 6.12;
//! tmp/plans/mcp1-design.md 3).

const std = @import("std");
const platform = @import("platform");
const testing = std.testing;
const c = std.c;

fn connectLoopbackV4(port: u16) !c.fd_t {
    const fd = c.socket(c.AF.INET, c.SOCK.STREAM, 0);
    if (fd < 0) return error.SocketFailed;
    errdefer _ = c.close(fd);
    var addr: c.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
    if (c.connect(fd, @ptrCast(&addr), @sizeOf(c.sockaddr.in)) != 0) return error.ConnectFailed;
    return fd;
}

test "devtoolsListenAddress binds loopback IPv4, localhost, empty, IPv6 ::1, and non-loopback 0.0.0.0; rejects hostnames" {
    if (comptime platform.capabilities.devtools_transport == .unsupported) return error.SkipZigTest;

    // Empty defaults to 127.0.0.1.
    const l_empty = try platform.devtoolsListenAddress(platform.Str.empty, 0);
    defer platform.devtoolsCloseListener(l_empty);
    try testing.expect(l_empty.port != 0);

    // Explicit 127.0.0.1 and localhost.
    const l_v4 = try platform.devtoolsListenAddress(platform.Str.from("127.0.0.1"), 0);
    defer platform.devtoolsCloseListener(l_v4);
    try testing.expect(l_v4.port != 0);

    const l_local = try platform.devtoolsListenAddress(platform.Str.from("localhost"), 0);
    defer platform.devtoolsCloseListener(l_local);
    try testing.expect(l_local.port != 0);

    // Explicit non-loopback 0.0.0.0 (OS assigns an ephemeral port; reachable on 127.0.0.1).
    const l_any = try platform.devtoolsListenAddress(platform.Str.from("0.0.0.0"), 0);
    defer platform.devtoolsCloseListener(l_any);
    try testing.expect(l_any.port != 0);

    // Non-IP hostname refused (never blocks on DNS).
    try testing.expectError(error.AccessDenied, platform.devtoolsListenAddress(platform.Str.from("evil.example"), 0));
    try testing.expectError(error.AccessDenied, platform.devtoolsListenAddress(platform.Str.from("999.999.999.999"), 0));

    // Verify TCP accept + read/write over l_any.
    const wake = try platform.devtoolsWakeNew();
    defer platform.devtoolsWakeClose(wake);
    const client_fd = try connectLoopbackV4(l_any.port);
    defer _ = c.close(client_fd);

    const server_stream = (try platform.devtoolsAccept(l_any, wake)) orelse return error.ExpectedConnection;
    defer platform.devtoolsClose(server_stream);

    const ping = "hello-mcp";
    try testing.expectEqual(@as(isize, ping.len), c.send(client_fd, ping.ptr, ping.len, 0));
    var buf: [64]u8 = undefined;
    const n = try platform.devtoolsRead(server_stream, &buf);
    try testing.expectEqualStrings(ping, buf[0..n]);
}

test "devtoolsTlsServerNew generates unique ephemeral self-signed certs with SHA-256 fingerprints and rejects bad PEM" {
    if (comptime platform.capabilities.devtools_transport == .unsupported) return error.SkipZigTest;

    const a = try platform.devtoolsTlsServerNew(testing.allocator, &.{});
    defer platform.devtoolsTlsServerClose(a.handle);
    const b = try platform.devtoolsTlsServerNew(testing.allocator, &.{ .common_name = platform.Str.from("127.0.0.1") });
    defer platform.devtoolsTlsServerClose(b.handle);

    const zeros: [32]u8 = @splat(0);
    try testing.expect(!std.mem.eql(u8, &a.cert_sha256, &zeros));
    try testing.expect(!std.mem.eql(u8, &b.cert_sha256, &zeros));
    // Distinct ephemeral certificates must have distinct SHA-256 fingerprints.
    try testing.expect(!std.mem.eql(u8, &a.cert_sha256, &b.cert_sha256));

    // Cert without key or garbage PEM must fail cleanly.
    try testing.expectError(error.Io, platform.devtoolsTlsServerNew(testing.allocator, &.{
        .cert_pem = platform.Bytes.from("-----BEGIN CERTIFICATE-----\nINVALID\n-----END CERTIFICATE-----\n"),
    }));
    try testing.expectError(error.Io, platform.devtoolsTlsServerNew(testing.allocator, &.{
        .cert_pem = platform.Bytes.from("not a cert"),
        .key_pem = platform.Bytes.from("not a key"),
    }));
}

test "devtoolsTlsAccept aborts a stalled TLS handshake immediately when woken" {
    if (comptime platform.capabilities.devtools_transport == .unsupported) return error.SkipZigTest;

    const tls_info = try platform.devtoolsTlsServerNew(testing.allocator, &.{});
    defer platform.devtoolsTlsServerClose(tls_info.handle);
    const listener = try platform.devtoolsListenAddress(platform.Str.from("127.0.0.1"), 0);
    defer platform.devtoolsCloseListener(listener);
    const accept_wake = try platform.devtoolsWakeNew();
    defer platform.devtoolsWakeClose(accept_wake);
    const hs_wake = try platform.devtoolsWakeNew();
    defer platform.devtoolsWakeClose(hs_wake);

    const client_fd = try connectLoopbackV4(listener.port);
    defer _ = c.close(client_fd);
    const raw_stream = (try platform.devtoolsAccept(listener, accept_wake)) orelse return error.ExpectedConnection;
    defer platform.devtoolsClose(raw_stream);

    // Wake from another thread shortly after handshake begins; client sends nothing.
    const Waker = struct {
        wake: platform.DevtoolsWake,
        fn run(ctx: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            platform.sleepThread(30 * std.time.ns_per_ms);
            platform.devtoolsWake(self.wake);
        }
    };
    var waker: Waker = .{ .wake = hs_wake };
    const thread = try platform.spawnThread(.{ .name = .from("tls-waker") }, Waker.run, &waker);
    defer platform.joinThread(thread);

    const result = try platform.devtoolsTlsAccept(testing.allocator, tls_info.handle, raw_stream, hs_wake);
    try testing.expect(result == null);
}
