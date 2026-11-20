//! The WebSocket Protocol's framing (RFC 6455 section 5), for kit/curl's
//! WebSocket transport: the frames a client sends (always masked, 5.3) and
//! the frames it receives (never masked, 5.1), over HTTP/1.1 and over an
//! HTTP/2 extended CONNECT stream (RFC 8441 section 5: "the peers should
//! proceed with the WebSocket Protocol ... using the HTTP/2 stream ... as if
//! it were the TCP connection") alike. Every browser frames its WebSockets
//! itself (Chromium net/websockets/websocket_frame.cc and
//! websocket_frame_parser.cc, Firefox netwerk/protocol/websocket/
//! WebSocketChannel.cpp); libcurl's framing (curl_ws_send/curl_ws_recv)
//! works only on the HTTP/1.1 connection curl upgraded itself (lib/ws.c
//! forces HTTP/1.x), so the transport owns the protocol and curl only makes
//! the connection.
//!
//! No extension is ever negotiated (the handshake offers none), so every
//! RSV bit must be 0 (5.2).

const std = @import("std");

/// What one frame carries, as the platform protocol names it
/// (platform.WebSocketFrameKind, whose order this keeps).
pub const Kind = enum(u8) { text, binary, close, ping, pong };

/// RFC 6455 5.2 opcodes.
pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
    _,

    fn of(kind: Kind) Opcode {
        return switch (kind) {
            .text => .text,
            .binary => .binary,
            .close => .close,
            .ping => .ping,
            .pong => .pong,
        };
    }

    fn isControl(op: Opcode) bool {
        return @backingInt(op) & 0x8 != 0;
    }
};

/// The longest frame header: two bytes, a 64-bit extended length, a mask key.
pub const max_header_len = 2 + 8 + 4;

/// 5.5: "All control frames MUST have a payload length of 125 bytes or less".
pub const max_control_payload = 125;

/// A client frame's header (5.2): FIN, the opcode, MASK set, the payload
/// length in its shortest form (7 bits, 16 or 64), and the mask key. The
/// number of bytes written to `out`.
pub fn encodeHeader(out: *[max_header_len]u8, opcode: Opcode, fin: bool, payload_len: u64, mask_key: [4]u8) usize {
    out[0] = (if (fin) @as(u8, 0x80) else 0) | @as(u8, @backingInt(opcode));
    var n: usize = 2;
    if (payload_len <= 125) {
        out[1] = 0x80 | @as(u8, @intCast(payload_len));
    } else if (payload_len <= 0xFFFF) {
        out[1] = 0x80 | 126;
        std.mem.writeInt(u16, out[2..4], @intCast(payload_len), .big);
        n = 4;
    } else {
        out[1] = 0x80 | 127;
        std.mem.writeInt(u64, out[2..10], payload_len, .big);
        n = 10;
    }
    @memcpy(out[n..][0..4], &mask_key);
    return n + 4;
}

/// 5.3: XOR `bytes` - the payload bytes from `offset` on - with the mask key,
/// in place. The same call unmasks.
pub fn mask(bytes: []u8, key: [4]u8, offset: u64) void {
    for (bytes, 0..) |*byte, i| byte.* ^= key[@intCast((offset + i) % 4)];
}

/// One outgoing frame, sent in as many parts as the connection takes: the
/// platform protocol's send ("retry the remainder with the same kind").
pub const Encoder = struct {
    /// The frame being sent, or null between frames.
    frame: ?Frame = null,

    pub const Frame = struct {
        kind: Kind,
        key: [4]u8,
        /// The payload's length, in the header.
        len: u64,
        /// How much of it has been accepted.
        done: u64 = 0,
    };

    /// Append to `out` what the next `payload.len`-or-fewer payload bytes of a
    /// `kind` frame make - the header first when a frame starts, then the
    /// masked bytes - taking at most `budget` payload bytes. A call between
    /// frames starts one of `payload.len` bytes; a call during one continues
    /// it, and `kind` must be the frame's. Returns how many payload bytes it
    /// took. `random_key` makes a fresh mask key (5.3: "MUST be unpredictable").
    pub fn write(
        self: *Encoder,
        allocator: std.mem.Allocator,
        out: *std.ArrayList(u8),
        kind: Kind,
        payload: []const u8,
        budget: usize,
        random_key: *const fn (*[4]u8) void,
    ) error{ OutOfMemory, FrameKindChanged }!usize {
        if (self.frame) |frame| {
            if (frame.kind != kind) return error.FrameKindChanged;
        } else {
            var key: [4]u8 = undefined;
            random_key(&key);
            var header: [max_header_len]u8 = undefined;
            const n = encodeHeader(&header, Opcode.of(kind), true, payload.len, key);
            try out.appendSlice(allocator, header[0..n]);
            self.frame = .{ .kind = kind, .key = key, .len = payload.len };
        }
        const frame = &self.frame.?;
        const take: usize = @intCast(@min(@min(payload.len, budget), frame.len - frame.done));
        const start = out.items.len;
        try out.appendSlice(allocator, payload[0..take]);
        mask(out.items[start..], frame.key, frame.done);
        frame.done += take;
        if (frame.done == frame.len) self.frame = null;
        return take;
    }

    /// Whether a frame is part-way through.
    pub fn busy(self: *const Encoder) bool {
        return self.frame != null;
    }
};

/// The frames a server sends, decoded as they arrive (5.2), in chunks the
/// size of the caller's buffer: the platform protocol's receive. A control
/// frame (at most 125 bytes, never fragmented: 5.5) is handed over whole.
pub const Decoder = struct {
    /// Bytes of the frame header read so far.
    header: [max_header_len]u8 = undefined,
    header_len: usize = 0,
    /// The frame whose payload is being read, or null while reading a header.
    frame: ?Frame = null,
    /// The kind of the data message in progress (5.4: its first frame's
    /// opcode, continued by continuation frames), or null between messages.
    message: ?Kind = null,
    /// A control frame's payload, gathered whole.
    control: [max_control_payload]u8 = undefined,
    control_len: usize = 0,

    const Frame = struct {
        kind: Kind,
        fin: bool,
        remaining: u64,
    };

    pub const Chunk = struct {
        kind: Kind,
        /// How many bytes of the caller's buffer it filled.
        len: usize,
        /// How much of this frame is still to come.
        bytes_left: u64,
        /// Whether more frames of this message follow (a data frame without
        /// FIN).
        more_fragments: bool,
    };

    pub const Result = struct {
        /// How many bytes of the input were used.
        consumed: usize,
        /// The chunk the input made, or null when it was not enough for one.
        chunk: ?Chunk,
    };

    /// 7.1.7: what the client must fail the connection for.
    pub const Error = error{ProtocolError};

    /// Decode from `input` into `out` (which must hold at least
    /// `max_control_payload` bytes): at most one chunk per call.
    pub fn decode(self: *Decoder, input: []const u8, out: []u8) Error!Result {
        std.debug.assert(out.len >= max_control_payload);
        var used: usize = 0;
        if (self.frame == null) {
            used = try self.readHeader(input);
            if (self.frame == null) return .{ .consumed = used, .chunk = null };
        }
        const frame = &self.frame.?;
        const rest = input[used..];
        if (isControl(frame.kind)) {
            // Gathered whole: 5.5 keeps it within 125 bytes and one frame.
            const take: usize = @intCast(@min(frame.remaining, rest.len));
            @memcpy(self.control[self.control_len..][0..take], rest[0..take]);
            self.control_len += take;
            frame.remaining -= take;
            used += take;
            if (frame.remaining > 0) return .{ .consumed = used, .chunk = null };
            @memcpy(out[0..self.control_len], self.control[0..self.control_len]);
            const chunk: Chunk = .{ .kind = frame.kind, .len = self.control_len, .bytes_left = 0, .more_fragments = false };
            self.control_len = 0;
            self.frame = null;
            return .{ .consumed = used, .chunk = chunk };
        }
        const take: usize = @intCast(@min(@min(frame.remaining, rest.len), out.len));
        if (take == 0 and frame.remaining > 0) return .{ .consumed = used, .chunk = null };
        @memcpy(out[0..take], rest[0..take]);
        frame.remaining -= take;
        used += take;
        const chunk: Chunk = .{
            .kind = frame.kind,
            .len = take,
            .bytes_left = frame.remaining,
            .more_fragments = !frame.fin,
        };
        if (frame.remaining == 0) {
            if (frame.fin) self.message = null;
            self.frame = null;
        }
        return .{ .consumed = used, .chunk = chunk };
    }

    fn isControl(kind: Kind) bool {
        return switch (kind) {
            .close, .ping, .pong => true,
            .text, .binary => false,
        };
    }

    /// Read header bytes from `input`; when the header is whole, check it and
    /// start its frame. How many bytes it used.
    fn readHeader(self: *Decoder, input: []const u8) Error!usize {
        var used: usize = 0;
        while (used < input.len) {
            const need = self.headerNeed();
            if (self.header_len == need) break;
            const take = @min(need - self.header_len, input.len - used);
            @memcpy(self.header[self.header_len..][0..take], input[used..][0..take]);
            self.header_len += take;
            used += take;
        }
        if (self.header_len < 2 or self.header_len < self.headerNeed()) return used;
        try self.startFrame();
        self.header_len = 0;
        return used;
    }

    /// How long the header in hand is, as far as its first two bytes say.
    fn headerNeed(self: *const Decoder) usize {
        if (self.header_len < 2) return 2;
        const masked = self.header[1] & 0x80 != 0;
        const len7 = self.header[1] & 0x7F;
        const ext: usize = if (len7 == 126) 2 else if (len7 == 127) 8 else 0;
        return 2 + ext + (if (masked) @as(usize, 4) else 0);
    }

    fn startFrame(self: *Decoder) Error!void {
        const b0 = self.header[0];
        const b1 = self.header[1];
        const fin = b0 & 0x80 != 0;
        // 5.2: RSV1-3 "MUST be 0 unless an extension is negotiated".
        if (b0 & 0x70 != 0) return error.ProtocolError;
        // 5.1: "A client MUST close a connection if it detects a masked frame."
        if (b1 & 0x80 != 0) return error.ProtocolError;
        const len7 = b1 & 0x7F;
        const len: u64 = switch (len7) {
            126 => std.mem.readInt(u16, self.header[2..4], .big),
            // 5.2: "the most significant bit MUST be 0".
            127 => blk: {
                const value = std.mem.readInt(u64, self.header[2..10], .big);
                if (value >> 63 != 0) return error.ProtocolError;
                break :blk value;
            },
            else => len7,
        };
        const opcode: Opcode = @fromBackingInt(@intCast(@as(u4, @truncate(b0))));
        const kind: Kind = switch (opcode) {
            .continuation => self.message orelse return error.ProtocolError,
            .text, .binary => blk: {
                // 5.4: a new message may not start inside a fragmented one.
                if (self.message != null) return error.ProtocolError;
                const kind: Kind = if (opcode == .text) .text else .binary;
                if (!fin) self.message = kind;
                break :blk kind;
            },
            .close => .close,
            .ping => .ping,
            .pong => .pong,
            // 5.2: "If an unknown opcode is received, the receiving endpoint
            // MUST _Fail the WebSocket Connection_."
            _ => return error.ProtocolError,
        };
        if (opcode.isControl() and (!fin or len > max_control_payload)) return error.ProtocolError;
        self.frame = .{ .kind = kind, .fin = fin, .remaining = len };
    }
};
