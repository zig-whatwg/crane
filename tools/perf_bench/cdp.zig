//! Lightpanda through its CDP server (the user's rule: Lightpanda is driven
//! the way its users drive it, over the Chrome DevTools Protocol). A minimal
//! WebSocket client (RFC 6455: client frames masked, server frames not) and
//! the four commands puppeteer sends to open a page: a browser context, a
//! target in it, a flat session attached to the target, and Page.navigate.
//! The page then reports through the runner's mark endpoint like every
//! other engine's; the connection only has to stay open until it is done.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const WsError = error{ HandshakeFailed, ConnectionClosed, MessageTooLarge, BadFrame };

pub const WebSocket = struct {
    io: Io,
    stream: Io.net.Stream,
    reader: Io.net.Stream.Reader,
    writer: Io.net.Stream.Writer,
    in_buf: [64 * 1024]u8 = undefined,
    out_buf: [16 * 1024]u8 = undefined,
    /// The masking keys' source: a counter is enough (the mask defends
    /// proxies from cache poisoning, not secrets).
    next_mask: u32 = 0x5eed1234,

    /// Connect to ws://127.0.0.1:<port><path> and complete the handshake.
    pub fn connect(self: *WebSocket, io: Io, port: u16, path: []const u8) !void {
        const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(port) };
        self.io = io;
        self.next_mask = 0x5eed1234;
        self.stream = try address.connect(io, .{ .mode = .stream });
        errdefer self.stream.close(io);
        self.reader = self.stream.reader(io, &self.in_buf);
        self.writer = self.stream.writer(io, &self.out_buf);
        const key = "dGhlIHNhbXBsZSBub25jZQ=="; // RFC 6455's sample nonce
        try self.writer.interface.print("GET {s} HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {s}\r\nSec-WebSocket-Version: 13\r\n\r\n", .{ path, port, key });
        try self.writer.interface.flush();
        // The response head.
        while (std.mem.indexOf(u8, self.reader.interface.buffered(), "\r\n\r\n") == null) {
            self.reader.interface.fillMore() catch return error.HandshakeFailed;
        }
        const buffered = self.reader.interface.buffered();
        const end = std.mem.indexOf(u8, buffered, "\r\n\r\n").? + 4;
        const head = buffered[0..end];
        if (!std.mem.startsWith(u8, head, "HTTP/1.1 101")) return error.HandshakeFailed;
        var accept_buf: [28]u8 = undefined;
        const want = acceptKey(key, &accept_buf);
        // The accept value is base64, so exact; the header's name may be in any case.
        if (std.mem.indexOf(u8, head, want) == null) return error.HandshakeFailed;
        self.reader.interface.toss(end);
    }

    pub fn close(self: *WebSocket) void {
        self.stream.close(self.io);
    }

    /// Send one text message, masked.
    pub fn sendText(self: *WebSocket, data: []const u8) !void {
        var header: [14]u8 = undefined;
        const mask = std.mem.toBytes(self.next_mask);
        self.next_mask = self.next_mask *% 1664525 +% 1013904223;
        const n = encodeHeader(&header, data.len, mask);
        const w = &self.writer.interface;
        try w.writeAll(header[0..n]);
        var chunk: [1024]u8 = undefined;
        var i: usize = 0;
        while (i < data.len) {
            const k = @min(chunk.len, data.len - i);
            for (data[i .. i + k], chunk[0..k], 0..) |b, *o, j| o.* = b ^ mask[(i + j) % 4];
            try w.writeAll(chunk[0..k]);
            i += k;
        }
        try w.flush();
    }

    /// The next text message, owned by `gpa`; pings are answered, pongs and
    /// binary messages skipped, a close ends it.
    pub fn readText(self: *WebSocket, gpa: Allocator) ![]u8 {
        const r = &self.reader.interface;
        while (true) {
            const h = try r.takeArray(2);
            const fin = h[0] & 0x80 != 0;
            const opcode = h[0] & 0x0f;
            const masked = h[1] & 0x80 != 0;
            var len: u64 = h[1] & 0x7f;
            if (len == 126) len = try r.takeInt(u16, .big) else if (len == 127) len = try r.takeInt(u64, .big);
            if (len > max_message) return error.MessageTooLarge;
            var mask: [4]u8 = .{ 0, 0, 0, 0 };
            if (masked) mask = (try r.takeArray(4)).*;
            const payload = try gpa.alloc(u8, @intCast(len));
            errdefer gpa.free(payload);
            try r.readSliceAll(payload);
            if (masked) for (payload, 0..) |*b, i| {
                b.* ^= mask[i % 4];
            };
            switch (opcode) {
                0x1 => {
                    if (!fin) return error.BadFrame; // CDP sends whole messages
                    return payload;
                },
                0x8 => {
                    gpa.free(payload);
                    return error.ConnectionClosed;
                },
                0x9 => {
                    defer gpa.free(payload);
                    try self.sendControl(0xA, payload);
                },
                else => gpa.free(payload),
            }
        }
    }

    fn sendControl(self: *WebSocket, opcode: u8, data: []const u8) !void {
        var header: [14]u8 = undefined;
        const mask = std.mem.toBytes(self.next_mask);
        const n = encodeHeader(&header, data.len, mask);
        header[0] = 0x80 | opcode;
        const w = &self.writer.interface;
        try w.writeAll(header[0..n]);
        for (data, 0..) |b, i| try w.writeByte(b ^ mask[i % 4]);
        try w.flush();
    }
};

pub const max_message = 16 * 1024 * 1024;

/// A masked text frame's header for a payload of `len` bytes; its length.
pub fn encodeHeader(out: *[14]u8, len: usize, mask: [4]u8) usize {
    out[0] = 0x81; // FIN, text
    var n: usize = 2;
    if (len < 126) {
        out[1] = 0x80 | @as(u8, @intCast(len));
    } else if (len <= 0xffff) {
        out[1] = 0x80 | 126;
        std.mem.writeInt(u16, out[2..4], @intCast(len), .big);
        n = 4;
    } else {
        out[1] = 0x80 | 127;
        std.mem.writeInt(u64, out[2..10], len, .big);
        n = 10;
    }
    @memcpy(out[n .. n + 4], &mask);
    return n + 4;
}

/// Sec-WebSocket-Accept for `key`: base64(SHA-1(key ++ the RFC's GUID)).
pub fn acceptKey(key: []const u8, out: *[28]u8) []const u8 {
    var sha1 = std.crypto.hash.Sha1.init(.{});
    sha1.update(key);
    sha1.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
    var digest: [20]u8 = undefined;
    sha1.final(&digest);
    return std.base64.standard.Encoder.encode(out, &digest);
}

/// A CDP session over one WebSocket: commands numbered from 1, each waited
/// for by its id (events in between are skipped).
pub const Session = struct {
    ws: *WebSocket,
    gpa: Allocator,
    next_id: u32 = 1,

    /// Send `method` with `params` (a JSON object's text) - on `session_id`
    /// when given - and return the response's text (owned by `gpa`). A
    /// response with an error fails.
    pub fn call(self: *Session, method: []const u8, params: []const u8, session_id: ?[]const u8) ![]u8 {
        const id = self.next_id;
        self.next_id += 1;
        var msg: Io.Writer.Allocating = .init(self.gpa);
        defer msg.deinit();
        if (session_id) |s| {
            try msg.writer.print("{{\"id\":{d},\"sessionId\":\"{s}\",\"method\":\"{s}\",\"params\":{s}}}", .{ id, s, method, params });
        } else {
            try msg.writer.print("{{\"id\":{d},\"method\":\"{s}\",\"params\":{s}}}", .{ id, method, params });
        }
        try self.ws.sendText(msg.written());
        while (true) {
            const text = try self.ws.readText(self.gpa);
            if (responseId(text) == id) {
                if (std.mem.indexOf(u8, text, "\"error\":") != null and std.mem.indexOf(u8, text, "\"result\":") == null) {
                    self.gpa.free(text);
                    return error.CdpCommandFailed;
                }
                return text;
            }
            self.gpa.free(text);
        }
    }
};

/// The "id" of a CDP response, or null for an event.
pub fn responseId(text: []const u8) ?u32 {
    const at = std.mem.indexOf(u8, text, "\"id\":") orelse return null;
    var i = at + 5;
    while (i < text.len and text[i] == ' ') i += 1;
    var end = i;
    while (end < text.len and std.ascii.isDigit(text[end])) end += 1;
    if (end == i) return null;
    return std.fmt.parseInt(u32, text[i..end], 10) catch null;
}

/// A string field of a CDP response's result ("targetId", "sessionId").
pub fn resultString(arena: Allocator, text: []const u8, field: []const u8) ![]const u8 {
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, text, .{});
    const result = parsed.object.get("result") orelse return error.CdpNoResult;
    const v = result.object.get(field) orelse return error.CdpNoResult;
    if (v != .string) return error.CdpNoResult;
    return v.string;
}

/// Open `url` in a new page, as puppeteer does: a browser context, a target
/// in it, a flat session on the target, then Page.navigate.
pub fn openPage(arena: Allocator, session: *Session, url: []const u8) !void {
    const ctx = try session.call("Target.createBrowserContext", "{}", null);
    const context_id = try resultString(arena, ctx, "browserContextId");
    const target_params = try std.fmt.allocPrint(arena, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{context_id});
    const target = try session.call("Target.createTarget", target_params, null);
    const target_id = try resultString(arena, target, "targetId");
    const attach_params = try std.fmt.allocPrint(arena, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{target_id});
    const attached = try session.call("Target.attachToTarget", attach_params, null);
    const session_id = try resultString(arena, attached, "sessionId");
    const enabled = try session.call("Page.enable", "{}", session_id);
    const nav_params = try std.fmt.allocPrint(arena, "{{\"url\":\"{s}\"}}", .{url});
    const navigated = try session.call("Page.navigate", nav_params, session_id);
    for ([_][]u8{ ctx, target, attached, enabled, navigated }) |t| session.gpa.free(t);
}

const testing = std.testing;

test "frame headers: the three length forms, masked" {
    var h: [14]u8 = undefined;
    const mask = [4]u8{ 1, 2, 3, 4 };
    try testing.expectEqual(@as(usize, 6), encodeHeader(&h, 5, mask));
    try testing.expectEqualSlices(u8, &.{ 0x81, 0x85, 1, 2, 3, 4 }, h[0..6]);
    try testing.expectEqual(@as(usize, 8), encodeHeader(&h, 300, mask));
    try testing.expectEqualSlices(u8, &.{ 0x81, 0x80 | 126, 0x01, 0x2c }, h[0..4]);
    try testing.expectEqual(@as(usize, 14), encodeHeader(&h, 70000, mask));
    try testing.expectEqual(@as(u8, 0x80 | 127), h[1]);
}

test "the accept key of RFC 6455's example" {
    var buf: [28]u8 = undefined;
    try testing.expectEqualStrings("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", acceptKey("dGhlIHNhbXBsZSBub25jZQ==", &buf));
}

test "response ids and result strings" {
    try testing.expectEqual(@as(?u32, 7), responseId("{\"id\":7,\"result\":{}}"));
    try testing.expectEqual(@as(?u32, null), responseId("{\"method\":\"Page.loadEventFired\"}"));
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    try testing.expectEqualStrings("T1", try resultString(arena.allocator(), "{\"id\":2,\"result\":{\"targetId\":\"T1\"}}", "targetId"));
}

/// A WebSocket echo server on std.http.Server's own WebSocket: each text
/// message comes back as it was sent, the second time after a ping.
const EchoServer = struct {
    listener: Io.net.Server,
    thread: std.Thread = undefined,

    fn serve(self: *EchoServer) void {
        const io = testing.io;
        const stream = self.listener.accept(io) catch return;
        defer stream.close(io);
        var in_buf: [8192]u8 = undefined;
        var out_buf: [8192]u8 = undefined;
        var reader = stream.reader(io, &in_buf);
        var writer = stream.writer(io, &out_buf);
        var http: std.http.Server = .init(&reader.interface, &writer.interface);
        var request = http.receiveHead() catch return;
        const key = switch (request.upgradeRequested()) {
            .websocket => |k| k orelse return,
            else => return,
        };
        var ws = request.respondWebSocket(.{ .key = key }) catch return;
        ws.flush() catch return;
        var n: u32 = 0;
        while (true) {
            const msg = ws.readSmallMessage() catch return;
            n += 1;
            if (n == 2) ws.writeMessage("hello?", .ping) catch return;
            ws.writeMessage(msg.data, .text) catch return;
        }
    }
};

test "the client against std's WebSocket server: handshake, masked sends, a ping answered" {
    const io = testing.io;
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(0) };
    var server: EchoServer = .{ .listener = try address.listen(io, .{ .reuse_address = true }) };
    defer server.listener.deinit(io);
    server.thread = try std.Thread.spawn(.{}, EchoServer.serve, .{&server});
    defer server.thread.join();

    var ws: WebSocket = undefined;
    try ws.connect(io, server.listener.socket.address.getPort(), "/");
    defer ws.close();
    try ws.sendText("{\"id\":1}");
    const a = try ws.readText(testing.allocator);
    defer testing.allocator.free(a);
    try testing.expectEqualStrings("{\"id\":1}", a);
    const long = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    try ws.sendText(long);
    const b = try ws.readText(testing.allocator);
    defer testing.allocator.free(b);
    try testing.expectEqualStrings(long, b);
}
