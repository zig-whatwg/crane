//! A WebSocket handshake goes out on its Browser's network (instances B3):
//! through the Browser's proxy - the platform kit applies a Browser's
//! network options to the handshake's handle as it does to every fetch's.
//!
//! The "proxy" here is a socket that records the first request it is sent
//! and answers 502: the handshake fails, but the proxy saw it - addressed to
//! a host that does not resolve, which only a proxy could be asked for.
//! Without the Browser's proxy applied, curl looks the host up itself, fails,
//! and the proxy hears nothing.

const std = @import("std");
const testing = std.testing;
const websocket = @import("websocket");
const fetch = @import("fetch");
const net = std.Io.net;

const Connection = websocket.connection.WebSocketConnection;

/// A one-request proxy: accepts one connection, keeps the bytes of its
/// first request, answers 502 and closes.
const RecordingProxy = struct {
    io: std.Io,
    server: net.Server,
    port: u16,
    thread: ?std.Thread = null,
    seen: [4096]u8 = undefined,
    seen_len: std.atomic.Value(usize) = .init(0),
    done: std.atomic.Value(bool) = .init(false),

    fn start(self: *RecordingProxy) !void {
        const io = testing.io;
        const address: net.IpAddress = .{ .ip4 = net.Ip4Address.loopback(0) };
        const server = try address.listen(io, .{ .reuse_address = true });
        self.* = .{ .io = io, .server = server, .port = server.socket.address.getPort() };
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    fn stop(self: *RecordingProxy) void {
        self.server.deinit(self.io);
        if (self.thread) |thread| thread.join();
    }

    fn serve(self: *RecordingProxy) void {
        defer self.done.store(true, .release);
        const stream = self.server.accept(self.io) catch return;
        defer stream.close(self.io);
        var buffer: [4096]u8 = undefined;
        var reader = stream.reader(self.io, &buffer);
        reader.interface.fillMore() catch return;
        const received = reader.interface.buffered();
        const n = @min(received.len, self.seen.len);
        @memcpy(self.seen[0..n], received[0..n]);
        self.seen_len.store(n, .release);
        var out: [0]u8 = .{};
        var writer = stream.writer(self.io, &out);
        writer.interface.writeAll("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n") catch {};
    }

    fn firstRequest(self: *RecordingProxy) []const u8 {
        return self.seen[0..self.seen_len.load(.acquire)];
    }
};

test "a WebSocket handshake goes through its Browser's proxy" {
    var proxy: RecordingProxy = undefined;
    try proxy.start();
    defer proxy.stop();

    var network = fetch.network.NetworkContext.init(testing.allocator);
    defer network.deinit();
    var proxy_url: [64]u8 = undefined;
    try network.configure(.{
        .proxy = .{ .manual = .{ .http = try std.fmt.bufPrint(&proxy_url, "http://127.0.0.1:{d}", .{proxy.port}) } },
        .user_agent = "Mozilla/5.0 (Inst5) ProxyTest/1",
    });

    const connection = try Connection.init(testing.allocator, "ws://inst5-proxied.invalid/echo");
    defer connection.deinit();
    connection.startConnect(.{ .network = &network }) catch {};
    var turns: usize = 0;
    while (turns < 500 and !connection.closed and connection.state == .CONNECTING) : (turns += 1) {
        _ = connection.pollConnect() catch break;
        std.Io.sleep(testing.io, .fromMilliseconds(10), .awake) catch {};
    }

    // The proxy was asked for the host, with the Browser's user agent.
    var waited: usize = 0;
    while (!proxy.done.load(.acquire) and waited < 200) : (waited += 1) std.Io.sleep(testing.io, .fromMilliseconds(10), .awake) catch {};
    const seen = proxy.firstRequest();
    if (std.mem.indexOf(u8, seen, "inst5-proxied.invalid") == null) {
        std.debug.print("the proxy saw: \"{s}\"\n", .{seen});
        return error.HandshakeDidNotGoThroughTheProxy;
    }
    try testing.expect(std.mem.indexOf(u8, seen, "ProxyTest/1") != null);
}
