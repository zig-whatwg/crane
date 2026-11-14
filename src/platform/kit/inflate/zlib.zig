//! kit/inflate's second inflater: zlib's own inflate (the zlib that
//! build.zig.zon pins and the bundled libcurl links), for the platform's
//! `zlib_inflate` capability - raw DEFLATE (RFC 1951), a chunk at a time,
//! which Fetch's "gzip" and "deflate" content codings run behind their own
//! container parsing (src/fetch/content_coding/flate.zig).
//!
//! Why two inflaters side by side: root.zig's Zig inflater serves PNG
//! (kit/image_decoding) and WOFF (kit/sfnt), whole buffers whose truncation
//! must stop exactly at the last whole symbol. HTTP content codings are the
//! hot path of every page load, and the browsers decode them with zlib -
//! Chromium's net/filter/gzip_source_stream.cc (inflateInit2(-MAX_WBITS)
//! behind its own GZipHeader) and Firefox's netwerk/streamconv/converters/
//! nsHTTPCompressConv.cpp (inflateInit2(-MAX_WBITS) after check_header).
//! Crane did the same through Zig's std.compress.flate first, and the perf
//! pair measured it: a 1 MB gzip body took 1.317x the instructions and
//! 1.068x the time of libcurl's zlib (fetch.loopback-gzip, chat.local,
//! 2026-11-14), so the C inflater is used where it is in the link.
//!
//! zlib is declared here rather than translated from zlib.h, so that no
//! build-graph line names it (the user, 2026-11-12: no library-specific code
//! in build.zig): the four entry points and z_stream as zlib.h 1.3.x
//! declares them. inflateInit2_ is given sizeof(z_stream) and answers
//! Z_VERSION_ERROR when it differs from its own, so a layout drift fails
//! the decoder's creation (NotSupported) instead of corrupting memory; the
//! layout is pinned by the test below too. The symbols are referenced only
//! when an operation here is called - the platform reports `zlib_inflate`
//! only where the bundled libcurl, and so this zlib, is in the link
//! (adapters/*/protocol.zig), and a binary that never calls it (the kit's
//! own test binary, which links no zlib) links without them.

const std = @import("std");
const platform = @import("platform");

/// zlib.h's z_stream (1.3.x; `uInt` is unsigned int, `uLong` unsigned long).
pub const ZStream = extern struct {
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

extern fn inflateInit2_(strm: *ZStream, window_bits: c_int, version: [*:0]const u8, stream_size: c_int) c_int;
extern fn inflate(strm: *ZStream, flush: c_int) c_int;
extern fn inflateEnd(strm: *ZStream) c_int;
extern fn zlibVersion() [*:0]const u8;

// zlib.h's return codes and flush values.
const Z_OK = 0;
const Z_STREAM_END = 1;
const Z_MEM_ERROR = -4;
const Z_BUF_ERROR = -5;
const Z_NO_FLUSH = 0;
/// inflateInit2's windowBits for raw DEFLATE with a 32 KiB window
/// (-MAX_WBITS), as Chromium and Firefox pass it.
const raw_window_bits = -15;
/// The version this file declares zlib from; inflateInit2_ checks its major
/// digit and sizeof(z_stream) against its own.
const declared_version = "1.3.2";

/// zlib's allocator callbacks over the caller's allocator. Its free callback
/// has no size, so a 16-byte prefix records each allocation's (as
/// kit/brotli's Memory).
const Memory = struct {
    allocator: std.mem.Allocator,
    failed: bool = false,

    fn alloc(raw: ?*anyopaque, items: c_uint, size: c_uint) callconv(.c) ?*anyopaque {
        const self: *Memory = @ptrCast(@alignCast(raw.?));
        const bytes_wanted = std.math.mul(usize, items, size) catch {
            self.failed = true;
            return null;
        };
        const total = std.math.add(usize, bytes_wanted, 16) catch {
            self.failed = true;
            return null;
        };
        const bytes = self.allocator.alignedAlloc(u8, .@"16", total) catch {
            self.failed = true;
            return null;
        };
        const header: *usize = @ptrCast(bytes.ptr);
        header.* = total;
        return bytes.ptr + 16;
    }

    fn free(raw: ?*anyopaque, address: ?*anyopaque) callconv(.c) void {
        const ptr = address orelse return;
        const self: *Memory = @ptrCast(@alignCast(raw.?));
        const bytes: [*]align(16) u8 = @alignCast(@as([*]u8, @ptrCast(ptr)) - 16);
        const header: *const usize = @ptrCast(bytes);
        self.allocator.free(bytes[0..header.*]);
    }
};

/// Heap-allocated and never moved: zlib's state points back at its
/// z_stream and checks that it does (inflateStateCheck).
const Decoder = struct {
    memory: Memory,
    stream: ZStream,
    finished: bool = false,
};

/// All allocations, zlib's own included, belong to allocator.
pub fn createInflateDecoder(allocator: std.mem.Allocator) platform.CodecError!*platform.InflateDecoder {
    const self = try allocator.create(Decoder);
    errdefer allocator.destroy(self);
    self.* = .{ .memory = .{ .allocator = allocator }, .stream = std.mem.zeroes(ZStream) };
    self.stream.zalloc = Memory.alloc;
    self.stream.zfree = Memory.free;
    self.stream.@"opaque" = &self.memory;
    return switch (inflateInit2_(&self.stream, raw_window_bits, declared_version, @sizeOf(ZStream))) {
        Z_OK => @ptrCast(self),
        Z_MEM_ERROR => error.OutOfMemory,
        // Z_VERSION_ERROR (another major version or z_stream size) or
        // Z_STREAM_ERROR: this zlib is not the one declared here.
        else => error.NotSupported,
    };
}

pub fn destroyInflateDecoder(handle: *platform.InflateDecoder) void {
    const self: *Decoder = @ptrCast(@alignCast(handle));
    _ = inflateEnd(&self.stream);
    self.memory.allocator.destroy(self);
}

pub fn inflateChunk(handle: *platform.InflateDecoder, input: platform.Bytes, output: []u8) platform.CodecError!platform.CodecProgress {
    const self: *Decoder = @ptrCast(@alignCast(handle));
    // After the final block nothing more is read: the rest is the caller's
    // (a gzip trailer, or what follows the stream).
    if (self.finished) return .{ .consumed = 0, .produced = 0, .status = .finished };
    // avail_in and avail_out are unsigned int: a larger buffer is taken in
    // part, and the caller calls again with the rest.
    const in_len: c_uint = @intCast(@min(input.len, std.math.maxInt(c_uint)));
    const out_len: c_uint = @intCast(@min(output.len, std.math.maxInt(c_uint)));
    self.stream.next_in = input.ptr;
    self.stream.avail_in = in_len;
    self.stream.next_out = output.ptr;
    self.stream.avail_out = out_len;
    // Z_NO_FLUSH, as Chromium's GzipSourceStream::FilterData and Firefox's
    // nsHTTPCompressConv call it: inflate decodes as far as input and
    // output allow either way.
    const result = inflate(&self.stream, Z_NO_FLUSH);
    const consumed: usize = in_len - self.stream.avail_in;
    const produced: usize = out_len - self.stream.avail_out;
    self.stream.next_in = null;
    self.stream.next_out = null;
    if (self.memory.failed) return error.OutOfMemory;
    const status: platform.CodecStatus = switch (result) {
        Z_STREAM_END => blk: {
            self.finished = true;
            break :blk .finished;
        },
        // Z_OK: progress was made. Z_BUF_ERROR: none was possible - no
        // input, or no room for output. inflate stops only when one of
        // them ran out: a full output asks for more output (zlib may hold
        // more), otherwise the input was all taken.
        Z_OK, Z_BUF_ERROR => if (self.stream.avail_out == 0) .need_output else .need_input,
        Z_MEM_ERROR => return error.OutOfMemory,
        // Z_DATA_ERROR (not DEFLATE), Z_STREAM_ERROR; Z_NEED_DICT is not
        // reached (raw DEFLATE carries no dictionary id).
        else => return error.InvalidData,
    };
    return .{ .consumed = consumed, .produced = produced, .status = status };
}

/// zlib's own version string (zlibVersion()), for a caller that reports it.
pub fn version() []const u8 {
    return std.mem.span(zlibVersion());
}

test "ZStream has zlib.h 1.3.x's layout on LP64 targets" {
    // Static only: the test binary of kit/inflate links no zlib.
    if (@sizeOf(c_ulong) != 8 or @sizeOf(usize) != 8) return error.SkipZigTest;
    try std.testing.expectEqual(@as(usize, 112), @sizeOf(ZStream));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(ZStream, "next_in"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(ZStream, "avail_in"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(ZStream, "total_in"));
    try std.testing.expectEqual(@as(usize, 24), @offsetOf(ZStream, "next_out"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(ZStream, "avail_out"));
    try std.testing.expectEqual(@as(usize, 40), @offsetOf(ZStream, "total_out"));
    try std.testing.expectEqual(@as(usize, 48), @offsetOf(ZStream, "msg"));
    try std.testing.expectEqual(@as(usize, 56), @offsetOf(ZStream, "state"));
    try std.testing.expectEqual(@as(usize, 64), @offsetOf(ZStream, "zalloc"));
    try std.testing.expectEqual(@as(usize, 72), @offsetOf(ZStream, "zfree"));
    try std.testing.expectEqual(@as(usize, 80), @offsetOf(ZStream, "opaque"));
    try std.testing.expectEqual(@as(usize, 88), @offsetOf(ZStream, "data_type"));
    try std.testing.expectEqual(@as(usize, 96), @offsetOf(ZStream, "adler"));
    try std.testing.expectEqual(@as(usize, 104), @offsetOf(ZStream, "reserved"));
}
