//! The WebSocket transport speaks the WebSocket Protocol itself on the
//! connection curl makes (lane net3): its HTTP/1.1 opening handshake is the
//! one RFC 6455 4.1 describes and the browsers check - a 101 whose
//! Sec-WebSocket-Accept is not the key's fails (libcurl's upgrade checked
//! no Accept at all: lib/ws.c Curl_ws_accept only comments on it) - and its
//! frames are decoded from whatever reads the network gives, a Ping answered
//! with a Pong of the same payload (RFC 6455 5.5.2).
const std = @import("std");
const testing = std.testing;
const io = testing.io;
const websocket = @import("websocket");
const fetch = @import("fetch");
const LoopbackListener = @import("loopback_listener").LoopbackListener;
const Transport = websocket.transport.WebSocketTransport;

/// One connection: reads the opening handshake, answers it with a 101
/// (whose Accept is right or not), writes `after` in the given pieces, then
/// reads `want` bytes of client frames and unmasks the first frame's payload.
const Scripted = struct {
    listener: LoopbackListener = undefined,
    thread: ?std.Thread = null,
    right_accept: bool = true,
    after: []const []const u8 = &.{},
    want: usize = 0,
    request: [4096]u8 = undefined,
    request_len: std.atomic.Value(usize) = .init(0),
    client: [256]u8 = undefined,
    client_len: std.atomic.Value(usize) = .init(0),

    fn start(self: *Scripted) !void {
        self.listener = try LoopbackListener.open(.{});
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    fn stop(self: *Scripted) void {
        self.listener.stop();
        if (self.thread) |thread| thread.join();
        self.listener.close();
    }

    fn url(self: *const Scripted, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "ws://127.0.0.1:{d}/chat?room=1", .{self.listener.port()});
    }

    fn serve(self: *Scripted) void {
        self.answer() catch {};
    }

    fn answer(self: *Scripted) !void {
        const stream = self.listener.accept() orelse return;
        defer stream.close(io);
        var input: [8192]u8 = undefined;
        var reader = stream.reader(io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const end = std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n").? + 4;
        const head = try reader.interface.take(end);
        @memcpy(self.request[0..head.len], head);
        self.request_len.store(head.len, .release);
        var key: []const u8 = "";
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(line[0..colon], "Sec-WebSocket-Key")) key = std.mem.trim(u8, line[colon + 1 ..], " \t");
        }
        var hash = std.crypto.hash.Sha1.init(.{});
        hash.update(key);
        hash.update(if (self.right_accept) "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" else "not the GUID");
        var digest: [20]u8 = undefined;
        hash.final(&digest);
        var encoded: [28]u8 = undefined;
        const accept = std.base64.standard.Encoder.encode(&encoded, &digest);
        var output: [0]u8 = .{};
        var writer = stream.writer(io, &output);
        try writer.interface.print("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n", .{accept});
        try writer.interface.flush();
        for (self.after) |piece| {
            try writer.interface.writeAll(piece);
            try writer.interface.flush();
            std.Io.sleep(io, .fromMilliseconds(20), .awake) catch {};
        }
        if (self.want == 0) {
            // Hold the connection until the client goes.
            _ = reader.interface.takeByte() catch {};
            return;
        }
        const got = try reader.interface.take(self.want);
        @memcpy(self.client[0..got.len], got);
        self.client_len.store(got.len, .release);
    }
};

fn connect(transport: *Transport) !void {
    try transport.startConnect();
    var turns: usize = 0;
    while (!try transport.pollConnect()) : (turns += 1) {
        if (turns > 1000) return error.Timeout;
        std.Io.sleep(io, .fromMilliseconds(5), .awake) catch {};
    }
}

fn next(transport: *Transport, buffer: []u8) !Transport.ReceivedChunk {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        return transport.receive(buffer) catch |err| switch (err) {
            error.WouldBlock => {
                std.Io.sleep(io, .fromMilliseconds(5), .awake) catch {};
                continue;
            },
            else => return err,
        };
    }
    return error.Timeout;
}

test "the opening handshake request is RFC 6455 4.1's, with the caller's fields" {
    var server: Scripted = .{};
    try server.start();
    defer server.stop();
    var network = fetch.network.NetworkContext.init(testing.allocator);
    defer network.deinit();
    try network.configure(.{ .user_agent = "Mozilla/5.0 Net3Test/1" });
    var buffer: [64]u8 = undefined;
    const transport = try Transport.initWithOptions(testing.allocator, try server.url(&buffer), .{
        .network = &network,
        .origin = "http://example.test",
        .protocols = &.{ "chat", "superchat" },
    });
    defer transport.deinit();
    // The server answers no subprotocol, so the handshake itself fails above
    // the platform (WebSockets 2.2 step 11.2); the request is what is checked.
    _ = connect(transport) catch {};
    var waited: usize = 0;
    while (server.request_len.load(.acquire) == 0 and waited < 400) : (waited += 1) std.Io.sleep(io, .fromMilliseconds(5), .awake) catch {};
    const request = server.request[0..server.request_len.load(.acquire)];
    try testing.expect(std.mem.startsWith(u8, request, "GET /chat?room=1 HTTP/1.1\r\n"));
    var host: [64]u8 = undefined;
    try testing.expect(std.mem.indexOf(u8, request, try std.fmt.bufPrint(&host, "\r\nHost: 127.0.0.1:{d}\r\n", .{server.listener.port()})) != null);
    for ([_][]const u8{
        "\r\nUser-Agent: Mozilla/5.0 Net3Test/1\r\n",
        "\r\nUpgrade: websocket\r\n",
        "\r\nConnection: Upgrade\r\n",
        "\r\nSec-WebSocket-Version: 13\r\n",
        "\r\nOrigin: http://example.test\r\n",
        "\r\nSec-WebSocket-Protocol: chat, superchat\r\n",
    }) |field| try testing.expect(std.mem.indexOf(u8, request, field) != null);
    // A 16-byte nonce, base64: 24 characters (4.1, client step 7).
    const key_at = std.mem.indexOf(u8, request, "\r\nSec-WebSocket-Key: ").? + "\r\nSec-WebSocket-Key: ".len;
    const key_end = std.mem.indexOfPos(u8, request, key_at, "\r\n").?;
    try testing.expectEqual(@as(usize, 24), key_end - key_at);
    var decoded: [16]u8 = undefined;
    try std.base64.standard.Decoder.decode(&decoded, request[key_at..key_end]);
}

test "a 101 whose Sec-WebSocket-Accept is not the key's fails the handshake" {
    var server: Scripted = .{ .right_accept = false };
    try server.start();
    defer server.stop();
    var buffer: [64]u8 = undefined;
    const transport = try Transport.init(testing.allocator, try server.url(&buffer), null);
    defer transport.deinit();
    try testing.expectError(error.HandshakeFailed, connect(transport));
}

test "frames are decoded from any split of the reads, and a Ping is answered with its Pong" {
    var server: Scripted = .{
        .after = &.{
            // A ping "abc", then a text message in two fragments, the first
            // frame's header split across two writes.
            &.{ 0x89, 0x03, 'a', 'b', 'c', 0x01 },
            &.{ 0x02, 'h', 'e' },
            &.{ 0x80, 0x03, 'l', 'l', 'o' },
        },
        // The Pong: two header bytes, the mask key, three payload bytes.
        .want = 2 + 4 + 3,
    };
    try server.start();
    defer server.stop();
    var url: [64]u8 = undefined;
    const transport = try Transport.init(testing.allocator, try server.url(&url), null);
    defer transport.deinit();
    try connect(transport);

    var buffer: [256]u8 = undefined;
    const ping = try next(transport, &buffer);
    try testing.expectEqual(websocket.transport.FrameKind.ping, ping.kind);
    try testing.expectEqualStrings("abc", ping.data);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    while (true) {
        const chunk = try next(transport, &buffer);
        try testing.expectEqual(websocket.transport.FrameKind.text, chunk.kind);
        try text.appendSlice(testing.allocator, chunk.data);
        if (chunk.bytes_left == 0 and !chunk.more_fragments) break;
    }
    try testing.expectEqualStrings("hello", text.items);

    var waited: usize = 0;
    while (server.client_len.load(.acquire) == 0 and waited < 400) : (waited += 1) std.Io.sleep(io, .fromMilliseconds(5), .awake) catch {};
    const pong = server.client[0..server.client_len.load(.acquire)];
    try testing.expectEqual(@as(usize, 9), pong.len);
    try testing.expectEqual(@as(u8, 0x8A), pong[0]); // FIN, Pong
    try testing.expectEqual(@as(u8, 0x80 | 3), pong[1]); // masked, 3 bytes
    var payload: [3]u8 = pong[6..9].*;
    for (&payload, 0..) |*byte, i| byte.* ^= pong[2 + i % 4];
    try testing.expectEqualStrings("abc", &payload);
}
