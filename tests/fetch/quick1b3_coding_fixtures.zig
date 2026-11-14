//! Content-coding fixtures for the quick1b3 tests: the plaintexts, made
//! here, and their encodings, made by other implementations than the ones
//! Crane decodes with - gzip(1) -n -9, Python's zlib (level 9, zlib and raw
//! DEFLATE), brotli(1) -q 11, zstd(1) -19 with and without --check - from
//! the same formulas (tests/fetch/fixtures/content_coding/; the generator
//! was lane quick1 b3's tmp/quick1b3/gen.py).
const std = @import("std");

pub const small_gz = @embedFile("fixtures/content_coding/small.gz");
pub const small_zlib = @embedFile("fixtures/content_coding/small.zlib");
pub const small_deflate = @embedFile("fixtures/content_coding/small.deflate");
pub const small_br = @embedFile("fixtures/content_coding/small.br");
pub const small_zst = @embedFile("fixtures/content_coding/small.zst");
pub const small_check_zst = @embedFile("fixtures/content_coding/small.check.zst");
/// "Content-Encoding: gzip, br": brotli(1) over gzip(1)'s output.
pub const small_gz_br = @embedFile("fixtures/content_coding/small.gz.br");
/// "Content-Encoding: gzip, gzip".
pub const small_gz_gz = @embedFile("fixtures/content_coding/small.gz.gz");
pub const big_gz = @embedFile("fixtures/content_coding/big.gz");
pub const big_br = @embedFile("fixtures/content_coding/big.br");
/// One frame of two blocks (the text is over 128 KiB), Window_Size 8 MiB
/// (zstd(1) reading a pipe), with a Content_Checksum.
pub const big_check_zst = @embedFile("fixtures/content_coding/big.check.zst");

/// 40 lines, 2,519 bytes.
pub fn small(allocator: std.mem.Allocator) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    for (0..40) |i| {
        try out.print(allocator, "line {d}: the quick brown fox jumps over the lazy dog, {d} times.\n", .{ i, (i * 7) % 13 });
    }
    return out.toOwnedSlice(allocator);
}

const words = [64][]const u8{
    "alpha",  "bravo",  "charlie", "delta",  "echo",    "foxtrot",  "golf",    "hotel",
    "india",  "juliet", "kilo",    "lima",   "mike",    "november", "oscar",   "papa",
    "quebec", "romeo",  "sierra",  "tango",  "uniform", "victor",   "whiskey", "xray",
    "yankee", "zulu",   "red",     "orange", "yellow",  "green",    "blue",    "indigo",
    "violet", "black",  "white",   "grey",   "silver",  "gold",     "copper",  "iron",
    "tin",    "lead",   "zinc",    "nickel", "cobalt",  "carbon",   "oxygen",  "helium",
    "neon",   "argon",  "radon",   "xenon",  "krypton", "north",    "south",   "east",
    "west",   "up",     "down",    "left",   "right",   "fast",     "slow",    "near",
};

/// 25,000 words from a 64-word list (a linear congruential choice), 12 to a
/// line: 150,146 bytes.
pub fn big(allocator: std.mem.Allocator) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var state: u64 = 1;
    for (0..25000) |i| {
        state = (state * 1103515245 + 12345) % (1 << 31);
        try out.appendSlice(allocator, words[(state >> 16) % 64]);
        try out.append(allocator, if (i % 12 == 11) '\n' else ' ');
    }
    return out.toOwnedSlice(allocator);
}

/// A loopback HTTP server that answers every connection with `response`,
/// whole, and keeps the last request's bytes.
pub const Canned = struct {
    listener: @import("loopback_listener").LoopbackListener = undefined,
    thread: std.Thread = undefined,
    response: []const u8,
    request_buf: [8192]u8 = undefined,
    request_len: std.atomic.Value(usize) = .init(0),

    pub fn start(self: *Canned) !void {
        self.listener = try .open(.{});
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    pub fn stop(self: *Canned) void {
        self.listener.stop();
        self.thread.join();
        self.listener.close();
    }

    pub fn url(self: *const Canned, buf: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    /// The last request as it arrived (its header block).
    pub fn request(self: *const Canned) []const u8 {
        return self.request_buf[0..self.request_len.load(.acquire)];
    }

    fn serve(self: *Canned) void {
        while (self.listener.accept()) |stream| {
            self.answer(stream);
            stream.close(std.testing.io);
        }
    }

    fn answer(self: *Canned, stream: std.Io.net.Stream) void {
        var buf: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &buf);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            reader.interface.fillMore() catch return;
        }
        const seen = reader.interface.buffered();
        const n = @min(seen.len, self.request_buf.len);
        @memcpy(self.request_buf[0..n], seen[0..n]);
        self.request_len.store(n, .release);
        var no_buffer: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &no_buffer);
        writer.interface.writeAll(self.response) catch return;
        writer.interface.flush() catch return;
    }
};

/// `head` (a status line and header fields, each ended by CRLF, without
/// the empty line) and `body`, with its Content-Length: OWNED.
pub fn httpResponse(allocator: std.mem.Allocator, head: []const u8, body: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}Content-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ head, body.len, body });
}
