//! permessage-deflate (RFC 7692) for kit/curl's WebSocket transport: the
//! offer, the response's agreed parameters (sections 5 and 7.1), and the
//! message transformation (7.2) on zlib's deflate and inflate.
//!
//! Every browser offers it and compresses with zlib: Chromium sends
//! "permessage-deflate; client_max_window_bits" (net/websockets/
//! websocket_deflate_parameters.cc, websocket_deflater.cc and
//! websocket_inflater.cc: raw DEFLATE, Z_SYNC_FLUSH, the 00 00 ff ff tail
//! dropped and put back), Firefox "permessage-deflate"
//! (netwerk/protocol/websocket/WebSocketChannel.cpp, PMCECompression).
//! libcurl's WebSocket never offered it. A server that answers with it
//! decides the bytes on the wire: WPT's wpt serve does, and its HTTP/2 server
//! never opens its flow-control window (it does not acknowledge received
//! data), so a message bigger than 65,535 bytes reaches it only compressed.
//!
//! zlib is declared here as kit/inflate/zlib.zig declares it - the zlib
//! build.zig.zon pins and the bundled libcurl links - so no build-graph line
//! names it: deflateInit2_ and inflateInit2_ are given sizeof(z_stream) and
//! fail (Z_VERSION_ERROR) when it is not zlib's, and every allocation zlib
//! makes is the caller's allocator's. The symbols are referenced only when a
//! Deflater or an Inflater is made, which the transport does only with the
//! bundled libcurl (trust.enabled).

const std = @import("std");

/// The client's offer: Chromium's, which also lets the server limit the
/// client's window (client_max_window_bits, 7.1.2.2).
pub const offer = "permessage-deflate; client_max_window_bits";

/// The agreed parameters (7.1) of a response that accepted the offer.
pub const Params = struct {
    server_no_context_takeover: bool = false,
    client_no_context_takeover: bool = false,
    /// 8-15, or null: 15.
    server_max_window_bits: ?u4 = null,
    client_max_window_bits: ?u4 = null,
};

/// What the response's Sec-WebSocket-Extensions says.
pub const Agreed = union(enum) {
    /// No extension: messages go uncompressed.
    none,
    deflate: Params,
};

/// RFC 7692 5 and 7, and RFC 6455 4.1 step 5: the response's
/// Sec-WebSocket-Extensions values (each occurrence of the field; empty:
/// absent), or error.Invalid - fail the WebSocket connection - for an
/// extension that was not offered, more than one, or permessage-deflate with
/// an unknown, repeated or invalid parameter (7: "A client MUST _Fail the
/// WebSocket Connection_ if ...").
pub fn agree(values: []const []const u8) error{Invalid}!Agreed {
    var result: Agreed = .none;
    for (values) |value| {
        var elements = std.mem.splitScalar(u8, value, ',');
        while (elements.next()) |raw_element| {
            const element = trim(raw_element);
            if (element.len == 0) continue;
            // One element at most: only one was offered.
            if (result != .none) return error.Invalid;
            var parts = std.mem.splitScalar(u8, element, ';');
            const name = trim(parts.first());
            if (!std.mem.eql(u8, name, "permessage-deflate")) return error.Invalid;
            var params: Params = .{};
            var seen: [4]bool = .{ false, false, false, false };
            while (parts.next()) |raw_param| {
                const param = trim(raw_param);
                const eq = std.mem.indexOfScalar(u8, param, '=');
                const key = trim(if (eq) |i| param[0..i] else param);
                const raw_value: ?[]const u8 = if (eq) |i| unquote(trim(param[i + 1 ..])) orelse return error.Invalid else null;
                const index: usize = if (std.mem.eql(u8, key, "server_no_context_takeover"))
                    0
                else if (std.mem.eql(u8, key, "client_no_context_takeover"))
                    1
                else if (std.mem.eql(u8, key, "server_max_window_bits"))
                    2
                else if (std.mem.eql(u8, key, "client_max_window_bits"))
                    3
                else
                    return error.Invalid;
                if (seen[index]) return error.Invalid;
                seen[index] = true;
                switch (index) {
                    0, 1 => {
                        // These parameters have no value (7.1.1).
                        if (raw_value != null) return error.Invalid;
                        if (index == 0) params.server_no_context_takeover = true else params.client_no_context_takeover = true;
                    },
                    else => {
                        // In a response both carry a value, 8-15, without
                        // leading zeroes (7.1.2.1, 7.1.2.2).
                        const bits = windowBits(raw_value orelse return error.Invalid) orelse return error.Invalid;
                        if (index == 2) params.server_max_window_bits = bits else params.client_max_window_bits = bits;
                    },
                }
            }
            result = .{ .deflate = params };
        }
    }
    return result;
}

fn trim(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t");
}

/// RFC 6455 9.1: a parameter value is a token or a quoted-string whose
/// content is a token. Null when it is neither.
fn unquote(value: []const u8) ?[]const u8 {
    if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
        const inner = value[1 .. value.len - 1];
        if (std.mem.indexOfScalar(u8, inner, '\\') != null) return null;
        return inner;
    }
    return value;
}

fn windowBits(value: []const u8) ?u4 {
    if (value.len == 0 or value.len > 2 or value[0] == '0') return null;
    for (value) |d| if (!std.ascii.isDigit(d)) return null;
    const n = std.fmt.parseInt(u8, value, 10) catch return null;
    if (n < 8 or n > 15) return null;
    return @intCast(n);
}

// ---------------------------------------------------------------------------
// zlib, as kit/inflate/zlib.zig declares it (z_stream from zlib.h 1.3.x).

const ZStream = extern struct {
    next_in: ?[*]const u8,
    avail_in: c_uint,
    total_in: c_ulong,
    next_out: ?[*]u8,
    avail_out: c_uint,
    total_out: c_ulong,
    msg: ?[*:0]const u8,
    state: ?*anyopaque,
    zalloc: ?*const fn (?*anyopaque, c_uint, c_uint) callconv(.c) ?*anyopaque,
    zfree: ?*const fn (?*anyopaque, ?*anyopaque) callconv(.c) void,
    @"opaque": ?*anyopaque,
    data_type: c_int,
    adler: c_ulong,
    reserved: c_ulong,
};

extern fn deflateInit2_(strm: *ZStream, level: c_int, method: c_int, window_bits: c_int, mem_level: c_int, strategy: c_int, version: [*:0]const u8, stream_size: c_int) c_int;
extern fn deflate(strm: *ZStream, flush: c_int) c_int;
extern fn deflateReset(strm: *ZStream) c_int;
extern fn deflateEnd(strm: *ZStream) c_int;
extern fn inflateInit2_(strm: *ZStream, window_bits: c_int, version: [*:0]const u8, stream_size: c_int) c_int;
extern fn inflate(strm: *ZStream, flush: c_int) c_int;
extern fn inflateReset(strm: *ZStream) c_int;
extern fn inflateEnd(strm: *ZStream) c_int;

const Z_OK = 0;
const Z_STREAM_END = 1;
const Z_MEM_ERROR = -4;
const Z_BUF_ERROR = -5;
const Z_NO_FLUSH = 0;
const Z_SYNC_FLUSH = 2;
const Z_DEFLATED = 8;
const Z_DEFAULT_COMPRESSION = -1;
const Z_DEFAULT_STRATEGY = 0;
/// deflateInit2's memLevel: zlib's default (Chromium's deflater uses it).
const mem_level = 8;
const declared_version = "1.3.2";

/// 7.2.1 step 3 and 7.2.2 step 1: the empty stored block's tail.
const tail = [_]u8{ 0x00, 0x00, 0xff, 0xff };

pub const Error = error{ OutOfMemory, InvalidData, NotSupported };

/// zlib's allocator callbacks over the caller's allocator, with a 16-byte
/// prefix for each block's length (kit/inflate/zlib.zig's Memory, which
/// says why rawAlloc).
const Memory = struct {
    allocator: std.mem.Allocator,
    failed: bool = false,

    fn alloc(raw: ?*anyopaque, items: c_uint, size: c_uint) callconv(.c) ?*anyopaque {
        const self: *Memory = @ptrCast(@alignCast(raw.?));
        const wanted = std.math.mul(usize, items, size) catch {
            self.failed = true;
            return null;
        };
        const total = std.math.add(usize, wanted, 16) catch {
            self.failed = true;
            return null;
        };
        const bytes = self.allocator.rawAlloc(total, .@"16", @returnAddress()) orelse {
            self.failed = true;
            return null;
        };
        const header: *usize = @ptrCast(@alignCast(bytes));
        header.* = total;
        return bytes + 16;
    }

    fn free(raw: ?*anyopaque, address: ?*anyopaque) callconv(.c) void {
        const ptr = address orelse return;
        const self: *Memory = @ptrCast(@alignCast(raw.?));
        const bytes: [*]align(16) u8 = @alignCast(@as([*]u8, @ptrCast(ptr)) - 16);
        const header: *const usize = @ptrCast(bytes);
        self.allocator.rawFree(bytes[0..header.*], .@"16", @returnAddress());
    }
};

/// The client's compressor (7.2.1). Heap-allocated and never moved: zlib's
/// state points back at its z_stream and checks that it does.
pub const Deflater = struct {
    memory: Memory,
    stream: ZStream,
    /// client_no_context_takeover: each message starts from an empty window.
    no_context_takeover: bool,

    /// `window_bits` 9-15 (client_max_window_bits; zlib's raw deflate takes
    /// no 8 - the transport sends uncompressed then).
    pub fn create(allocator: std.mem.Allocator, window_bits: u4, no_context_takeover: bool) Error!*Deflater {
        std.debug.assert(window_bits >= 9);
        const self = try allocator.create(Deflater);
        errdefer allocator.destroy(self);
        self.* = .{ .memory = .{ .allocator = allocator }, .stream = std.mem.zeroes(ZStream), .no_context_takeover = no_context_takeover };
        self.stream.zalloc = Memory.alloc;
        self.stream.zfree = Memory.free;
        self.stream.@"opaque" = &self.memory;
        return switch (deflateInit2_(&self.stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -@as(c_int, window_bits), mem_level, Z_DEFAULT_STRATEGY, declared_version, @sizeOf(ZStream))) {
            Z_OK => self,
            Z_MEM_ERROR => error.OutOfMemory,
            else => error.NotSupported,
        };
    }

    pub fn destroy(self: *Deflater) void {
        _ = deflateEnd(&self.stream);
        self.memory.allocator.destroy(self);
    }

    /// Append `message` compressed (7.2.1: DEFLATE, flushed with an empty
    /// stored block - Z_SYNC_FLUSH - whose 00 00 ff ff is dropped) to `out`.
    pub fn compress(self: *Deflater, message: []const u8, out: *std.ArrayList(u8)) Error!void {
        const allocator = self.memory.allocator;
        const start = out.items.len;
        self.stream.next_in = message.ptr;
        self.stream.avail_in = @intCast(message.len);
        while (true) {
            try out.ensureUnusedCapacity(allocator, @max(64, message.len / 2 + 16));
            const room = out.unusedCapacitySlice();
            const room_len: c_uint = @intCast(@min(room.len, std.math.maxInt(c_uint)));
            self.stream.next_out = room.ptr;
            self.stream.avail_out = room_len;
            const result = deflate(&self.stream, Z_SYNC_FLUSH);
            out.items.len += room_len - self.stream.avail_out;
            if (self.memory.failed) return error.OutOfMemory;
            switch (result) {
                Z_OK, Z_BUF_ERROR => {},
                else => return error.InvalidData,
            }
            // Z_SYNC_FLUSH is done when it left output room unused.
            if (self.stream.avail_in == 0 and self.stream.avail_out > 0) break;
        }
        self.stream.next_in = null;
        self.stream.next_out = null;
        const produced = out.items[start..];
        std.debug.assert(std.mem.endsWith(u8, produced, &tail));
        out.items.len -= tail.len;
        if (self.no_context_takeover) _ = deflateReset(&self.stream);
    }
};

/// The client's decompressor (7.2.2): one window for the connection unless
/// the server takes no context over.
pub const Inflater = struct {
    memory: Memory,
    stream: ZStream,
    /// server_no_context_takeover: each message may start from an empty
    /// window (7.2.2: "the client MAY decompress each new message with an
    /// empty LZ77 sliding window").
    no_context_takeover: bool,

    pub fn create(allocator: std.mem.Allocator, no_context_takeover: bool) Error!*Inflater {
        const self = try allocator.create(Inflater);
        errdefer allocator.destroy(self);
        self.* = .{ .memory = .{ .allocator = allocator }, .stream = std.mem.zeroes(ZStream), .no_context_takeover = no_context_takeover };
        self.stream.zalloc = Memory.alloc;
        self.stream.zfree = Memory.free;
        self.stream.@"opaque" = &self.memory;
        // A 32 KiB window decodes any server_max_window_bits (7.2.2: the
        // client MAY reduce it).
        return switch (inflateInit2_(&self.stream, -15, declared_version, @sizeOf(ZStream))) {
            Z_OK => self,
            Z_MEM_ERROR => error.OutOfMemory,
            else => error.NotSupported,
        };
    }

    pub fn destroy(self: *Inflater) void {
        _ = inflateEnd(&self.stream);
        self.memory.allocator.destroy(self);
    }

    /// Append the message whose compressed payload is `compressed` (all of
    /// its frames' payloads, concatenated: 6.2 step 1) to `out`, at most
    /// `limit` bytes of it (a message bigger than that is error.InvalidData).
    pub fn decompress(self: *Inflater, compressed: []const u8, out: *std.ArrayList(u8), limit: usize) Error!void {
        // 7.2.2 step 1: the tail goes back on, then step 2.
        for ([2][]const u8{ compressed, &tail }) |input| {
            self.stream.next_in = input.ptr;
            self.stream.avail_in = @intCast(input.len);
            while (true) {
                if (out.items.len >= limit) return error.InvalidData;
                try out.ensureUnusedCapacity(self.memory.allocator, @min(@max(4096, input.len * 2), limit - out.items.len));
                const room = out.unusedCapacitySlice();
                const room_len: c_uint = @intCast(@min(@min(room.len, limit - out.items.len), std.math.maxInt(c_uint)));
                self.stream.next_out = room.ptr;
                self.stream.avail_out = room_len;
                const result = inflate(&self.stream, Z_NO_FLUSH);
                out.items.len += room_len - self.stream.avail_out;
                if (self.memory.failed) return error.OutOfMemory;
                switch (result) {
                    Z_OK => {},
                    // A block with BFINAL set (7.2.1 allows one, 7.2.3.4):
                    // zlib ends its stream there, and the blocks that follow
                    // are decoded by a reset one - as Chromium's
                    // WebSocketInflater does (websocket_inflater.cc, Inflate:
                    // inflateReset on Z_STREAM_END).
                    Z_STREAM_END => _ = inflateReset(&self.stream),
                    // No progress was possible: with output room left, the
                    // input is all taken.
                    Z_BUF_ERROR => if (self.stream.avail_out != 0) break,
                    Z_MEM_ERROR => return error.OutOfMemory,
                    else => return error.InvalidData,
                }
                // Done with this input once it is all taken and the output
                // was not filled (a full output may hide more).
                if (self.stream.avail_in == 0 and self.stream.avail_out != 0) break;
            }
        }
        self.stream.next_in = null;
        self.stream.next_out = null;
        if (self.no_context_takeover) _ = inflateReset(&self.stream);
    }
};
