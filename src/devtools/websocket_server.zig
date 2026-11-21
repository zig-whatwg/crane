//! The WebSocket protocol's server role (RFC 6455, specs/rfc/rfc6455.md), as
//! the remote end needs it: the opening handshake's response (4.2.2), frames
//! read from a client (5.2-5.5: masked, possibly fragmented, with control
//! frames between the fragments) and frames written to it (unmasked).
//!
//! Crane's WebSocket client is curl's (src/platform/kit/curl); a server is
//! only this. Chromium's is net/server/web_socket.cc and
//! web_socket_encoder.cc (BSD-3), which DevToolsHttpHandler uses; the rules
//! below are the RFC's, in its section order. No extension is negotiated
//! (permessage-deflate is optional, 9.1; Puppeteer and Playwright offer none
//! on their CDP connections).

const std = @import("std");
const Allocator = std.mem.Allocator;

/// RFC 6455 1.3: the GUID the accept key is made with.
const accept_guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

/// The largest message the remote end takes (a client that sends more is
/// failed with 1009, "message too big", 7.4.1). Chrome's DevTools server
/// buffers 256 MiB (net/server/http_connection.cc kMaxBufferSize grows to
/// it); a CDP message is never near.
pub const max_message_bytes: usize = 256 * 1024 * 1024;

pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
    _,

    fn isControl(op: Opcode) bool {
        return @intFromEnum(op) & 0x8 != 0;
    }
};

/// RFC 6455 7.4.1 status codes the server sends.
pub const CloseCode = enum(u16) {
    normal = 1000,
    going_away = 1001,
    protocol_error = 1002,
    unsupported_data = 1003,
    invalid_payload = 1007,
    message_too_big = 1009,
};

/// `Sec-WebSocket-Accept` for a client's `Sec-WebSocket-Key` (4.2.2 step
/// 5.4): base64(SHA-1(key ++ GUID)).
pub fn acceptKey(key: []const u8) [28]u8 {
    var sha = std.crypto.hash.Sha1.init(.{});
    sha.update(key);
    sha.update(accept_guid);
    var digest: [20]u8 = undefined;
    sha.final(&digest);
    var out: [28]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &digest);
    return out;
}

/// Whether a `Sec-WebSocket-Key` is valid (4.2.1 item 5): base64 of 16 bytes.
pub fn validKey(key: []const u8) bool {
    if (key.len != 24) return false;
    var decoded: [18]u8 = undefined;
    const size = std.base64.standard.Decoder.calcSizeForSlice(key) catch return false;
    if (size != 16) return false;
    std.base64.standard.Decoder.decode(decoded[0..16], key) catch return false;
    return true;
}

/// The handshake's response (4.2.2 step 5). OWNED by the caller.
pub fn handshakeResponse(allocator: Allocator, key: []const u8) Allocator.Error![]u8 {
    const accept = acceptKey(key);
    return std.fmt.allocPrint(allocator, "HTTP/1.1 101 WebSocket Protocol Handshake\r\n" ++
        "Upgrade: WebSocket\r\n" ++
        "Connection: Upgrade\r\n" ++
        "Sec-WebSocket-Accept: {s}\r\n\r\n", .{&accept});
}

/// A frame from the server (5.2): FIN set, unmasked (5.1: "A server MUST NOT
/// mask any frames that it sends to the client"). OWNED by the caller.
pub fn encodeFrame(allocator: Allocator, opcode: Opcode, payload: []const u8) Allocator.Error![]u8 {
    var header: [10]u8 = undefined;
    header[0] = 0x80 | @as(u8, @intFromEnum(opcode));
    var header_len: usize = 2;
    if (payload.len < 126) {
        header[1] = @intCast(payload.len);
    } else if (payload.len <= std.math.maxInt(u16)) {
        header[1] = 126;
        std.mem.writeInt(u16, header[2..4], @intCast(payload.len), .big);
        header_len = 4;
    } else {
        header[1] = 127;
        std.mem.writeInt(u64, header[2..10], payload.len, .big);
        header_len = 10;
    }
    const frame = try allocator.alloc(u8, header_len + payload.len);
    @memcpy(frame[0..header_len], header[0..header_len]);
    @memcpy(frame[header_len..], payload);
    return frame;
}

/// A close frame with `code` and no reason (5.5.1). OWNED by the caller.
pub fn encodeClose(allocator: Allocator, code: CloseCode) Allocator.Error![]u8 {
    var body: [2]u8 = undefined;
    std.mem.writeInt(u16, &body, @intFromEnum(code), .big);
    return encodeFrame(allocator, .close, &body);
}

/// What the decoder found in the bytes it was given.
pub const Event = union(enum) {
    /// A whole text message, its bytes BORROWED until the next `next` call.
    text: []const u8,
    /// A whole binary message (CDP clients send none; the remote end fails
    /// the connection with 1003, as Chrome's server ignores... see caller).
    binary: []const u8,
    /// Ping's application data, BORROWED: answer with a pong carrying it
    /// (5.5.2).
    ping: []const u8,
    pong,
    /// The client's close (5.5.1): its status code, if it gave one.
    close: ?u16,
    /// The client broke the protocol: close with this code (7.1.7, "Fail
    /// the WebSocket Connection").
    fail: CloseCode,
};

/// Reads frames from a client, incrementally: `feed` the bytes as they
/// arrive, then take events with `next` until it answers null.
pub const Decoder = struct {
    allocator: Allocator,
    /// Bytes received and not yet consumed.
    buffer: std.ArrayList(u8) = .empty,
    consumed: usize = 0,
    /// The message being assembled from fragments (5.4).
    message: std.ArrayList(u8) = .empty,
    message_opcode: ?Opcode = null,
    /// What `next` handed out last, kept until the following call.
    control_payload: std.ArrayList(u8) = .empty,
    failed: bool = false,

    pub fn init(allocator: Allocator) Decoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Decoder) void {
        self.buffer.deinit(self.allocator);
        self.message.deinit(self.allocator);
        self.control_payload.deinit(self.allocator);
    }

    pub fn feed(self: *Decoder, bytes: []const u8) Allocator.Error!void {
        // Drop what was consumed before growing.
        if (self.consumed > 0) {
            const rest = self.buffer.items.len - self.consumed;
            std.mem.copyForwards(u8, self.buffer.items[0..rest], self.buffer.items[self.consumed..]);
            self.buffer.shrinkRetainingCapacity(rest);
            self.consumed = 0;
        }
        try self.buffer.appendSlice(self.allocator, bytes);
    }

    /// The next event, or null when more bytes are needed.
    pub fn next(self: *Decoder) Allocator.Error!?Event {
        if (self.failed) return null;
        while (true) {
            const data = self.buffer.items[self.consumed..];
            if (data.len < 2) return null;
            const fin = data[0] & 0x80 != 0;
            const rsv = data[0] & 0x70;
            const opcode: Opcode = @enumFromInt(@as(u4, @truncate(data[0])));
            const masked = data[1] & 0x80 != 0;
            var length: u64 = data[1] & 0x7F;
            var at: usize = 2;
            // 5.2: RSV1-3 MUST be 0 unless an extension says otherwise.
            if (rsv != 0) return self.failWith(.protocol_error);
            // 5.1: "The server MUST close the connection upon receiving a
            // frame that is not masked."
            if (!masked) return self.failWith(.protocol_error);
            switch (opcode) {
                .continuation, .text, .binary, .close, .ping, .pong => {},
                // 5.2: an unknown opcode fails the connection.
                _ => return self.failWith(.protocol_error),
            }
            if (opcode.isControl()) {
                // 5.5: control frames are never fragmented and carry at
                // most 125 bytes.
                if (!fin or length > 125) return self.failWith(.protocol_error);
            }
            if (length == 126) {
                if (data.len < at + 2) return null;
                length = std.mem.readInt(u16, data[at..][0..2], .big);
                at += 2;
            } else if (length == 127) {
                if (data.len < at + 8) return null;
                length = std.mem.readInt(u64, data[at..][0..8], .big);
                // 5.2: the most significant bit MUST be 0.
                if (length >> 63 != 0) return self.failWith(.protocol_error);
                at += 8;
            }
            if (length > max_message_bytes or self.message.items.len + length > max_message_bytes) return self.failWith(.message_too_big);
            if (data.len < at + 4) return null;
            const mask = data[at..][0..4].*;
            at += 4;
            const len: usize = @intCast(length);
            if (data.len < at + len) return null;
            const payload = data[at .. at + len];
            // 5.3: unmask in place.
            for (payload, 0..) |*byte, i| byte.* ^= mask[i % 4];
            self.consumed += at + len;

            switch (opcode) {
                .ping => {
                    self.control_payload.clearRetainingCapacity();
                    try self.control_payload.appendSlice(self.allocator, payload);
                    return .{ .ping = self.control_payload.items };
                },
                .pong => return .pong,
                .close => {
                    // 5.5.1: a body, if any, starts with a two-byte code;
                    // one byte is a protocol error.
                    if (payload.len == 1) return self.failWith(.protocol_error);
                    if (payload.len >= 2) {
                        // 8.1: the reason must be UTF-8.
                        if (!std.unicode.utf8ValidateSlice(payload[2..])) return self.failWith(.invalid_payload);
                        return .{ .close = std.mem.readInt(u16, payload[0..2], .big) };
                    }
                    return .{ .close = null };
                },
                .text, .binary => {
                    // 5.4: a new data frame while a fragmented message is
                    // open is a protocol error.
                    if (self.message_opcode != null) return self.failWith(.protocol_error);
                    if (fin) {
                        self.message.clearRetainingCapacity();
                        try self.message.appendSlice(self.allocator, payload);
                        return self.finish(opcode);
                    }
                    self.message.clearRetainingCapacity();
                    try self.message.appendSlice(self.allocator, payload);
                    self.message_opcode = opcode;
                },
                .continuation => {
                    const op = self.message_opcode orelse return self.failWith(.protocol_error);
                    try self.message.appendSlice(self.allocator, payload);
                    if (fin) {
                        self.message_opcode = null;
                        return self.finish(op);
                    }
                },
                _ => unreachable,
            }
        }
    }

    fn finish(self: *Decoder, opcode: Opcode) ?Event {
        if (opcode == .text) {
            // 8.1: a text message that is not UTF-8 fails the connection
            // with 1007.
            if (!std.unicode.utf8ValidateSlice(self.message.items)) return self.failWith(.invalid_payload);
            return .{ .text = self.message.items };
        }
        return .{ .binary = self.message.items };
    }

    fn failWith(self: *Decoder, code: CloseCode) ?Event {
        self.failed = true;
        return .{ .fail = code };
    }
};

// ============================================================================
// Tests: the RFC's own vectors
// ============================================================================

/// A client frame: masked with `mask`.
fn clientFrame(allocator: Allocator, first_byte: u8, mask: [4]u8, payload: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, first_byte);
    if (payload.len < 126) {
        try out.append(allocator, 0x80 | @as(u8, @intCast(payload.len)));
    } else if (payload.len <= 0xFFFF) {
        try out.append(allocator, 0x80 | 126);
        var len: [2]u8 = undefined;
        std.mem.writeInt(u16, &len, @intCast(payload.len), .big);
        try out.appendSlice(allocator, &len);
    } else {
        try out.append(allocator, 0x80 | 127);
        var len: [8]u8 = undefined;
        std.mem.writeInt(u64, &len, payload.len, .big);
        try out.appendSlice(allocator, &len);
    }
    try out.appendSlice(allocator, &mask);
    for (payload, 0..) |byte, i| try out.append(allocator, byte ^ mask[i % 4]);
    return out.toOwnedSlice(allocator);
}

test "acceptKey: RFC 6455 1.3's example" {
    const accept = acceptKey("dGhlIHNhbXBsZSBub25jZQ==");
    try std.testing.expectEqualStrings("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", &accept);
    try std.testing.expect(validKey("dGhlIHNhbXBsZSBub25jZQ=="));
    try std.testing.expect(!validKey("short"));
}

test "decode: RFC 6455 5.7's masked \"Hello\"" {
    var d = Decoder.init(std.testing.allocator);
    defer d.deinit();
    try d.feed(&.{ 0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58 });
    const event = (try d.next()).?;
    try std.testing.expectEqualStrings("Hello", event.text);
    try std.testing.expect((try d.next()) == null);
}

test "decode: an unmasked client frame fails the connection with 1002" {
    var d = Decoder.init(std.testing.allocator);
    defer d.deinit();
    // RFC 6455 5.7's unmasked "Hello" - valid from a server, not a client.
    try d.feed(&.{ 0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f });
    try std.testing.expectEqual(CloseCode.protocol_error, (try d.next()).?.fail);
}

test "decode: a fragmented message with a ping between its fragments (5.4, 5.7)" {
    const a = std.testing.allocator;
    var d = Decoder.init(a);
    defer d.deinit();
    const mask = [4]u8{ 1, 2, 3, 4 };
    const first = try clientFrame(a, 0x01, mask, "Hel");
    defer a.free(first);
    const ping = try clientFrame(a, 0x89, mask, "Hello");
    defer a.free(ping);
    const last = try clientFrame(a, 0x80, mask, "lo");
    defer a.free(last);
    try d.feed(first);
    try std.testing.expect((try d.next()) == null);
    try d.feed(ping);
    try std.testing.expectEqualStrings("Hello", (try d.next()).?.ping);
    // Byte by byte: the decoder waits for the whole frame.
    for (last) |byte| {
        try std.testing.expect((try d.next()) == null);
        try d.feed(&.{byte});
    }
    try std.testing.expectEqualStrings("Hello", (try d.next()).?.text);
}

test "decode: 16-bit and 64-bit lengths (5.7's 256 bytes and 64 KiB)" {
    const a = std.testing.allocator;
    var d = Decoder.init(a);
    defer d.deinit();
    const medium = try a.alloc(u8, 256);
    defer a.free(medium);
    @memset(medium, 'x');
    const big = try a.alloc(u8, 65536);
    defer a.free(big);
    @memset(big, 'y');
    const f1 = try clientFrame(a, 0x82, .{ 9, 8, 7, 6 }, medium);
    defer a.free(f1);
    const f2 = try clientFrame(a, 0x81, .{ 5, 4, 3, 2 }, big);
    defer a.free(f2);
    try d.feed(f1);
    try d.feed(f2);
    try std.testing.expectEqual(@as(usize, 256), (try d.next()).?.binary.len);
    try std.testing.expectEqual(@as(usize, 65536), (try d.next()).?.text.len);
}

test "decode: control frames longer than 125 bytes, invalid UTF-8 text, a stray continuation" {
    const a = std.testing.allocator;
    const mask = [4]u8{ 0, 0, 0, 0 };
    {
        var d = Decoder.init(a);
        defer d.deinit();
        const long = [_]u8{'p'} ** 126;
        const f = try clientFrame(a, 0x89, mask, &long);
        defer a.free(f);
        try d.feed(f);
        try std.testing.expectEqual(CloseCode.protocol_error, (try d.next()).?.fail);
    }
    {
        var d = Decoder.init(a);
        defer d.deinit();
        const f = try clientFrame(a, 0x81, mask, &.{ 0xff, 0xfe });
        defer a.free(f);
        try d.feed(f);
        try std.testing.expectEqual(CloseCode.invalid_payload, (try d.next()).?.fail);
    }
    {
        var d = Decoder.init(a);
        defer d.deinit();
        const f = try clientFrame(a, 0x80, mask, "x");
        defer a.free(f);
        try d.feed(f);
        try std.testing.expectEqual(CloseCode.protocol_error, (try d.next()).?.fail);
    }
}

test "decode: a close with a status code" {
    const a = std.testing.allocator;
    var d = Decoder.init(a);
    defer d.deinit();
    const f = try clientFrame(a, 0x88, .{ 1, 1, 1, 1 }, &.{ 0x03, 0xe8 });
    defer a.free(f);
    try d.feed(f);
    try std.testing.expectEqual(@as(?u16, 1000), (try d.next()).?.close);
}

test "encode: a server frame is unmasked, with the shortest length form" {
    const a = std.testing.allocator;
    const small = try encodeFrame(a, .text, "Hello");
    defer a.free(small);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f }, small);
    const payload = [_]u8{0} ** 300;
    const medium = try encodeFrame(a, .text, &payload);
    defer a.free(medium);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 126, 0x01, 0x2c }, medium[0..4]);
    const close = try encodeClose(a, .normal);
    defer a.free(close);
    try std.testing.expectEqualSlices(u8, &.{ 0x88, 0x02, 0x03, 0xe8 }, close);
}
