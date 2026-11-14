//! The "gzip" (RFC 1952) and "deflate" (RFC 9110 8.4.1.2: RFC 1950's zlib
//! around RFC 1951's DEFLATE) content codings, decoded as they arrive.
//!
//! DEFLATE itself is zlib's inflate where the platform has it (the
//! `zlib_inflate` capability, kit/inflate/zlib.zig), as Chromium's
//! GzipSourceStream and Firefox's nsHTTPCompressConv run it: raw DEFLATE
//! behind the container parsed here, fed each chunk as it comes, with no
//! roll-back. Zig's std.compress.flate took 1.317x zlib's instructions on a
//! 1 MB gzip body (perf pair fetch.loopback-gzip, chat.local, 2026-11-14).
//!
//! Without the capability - a -Dsystem-curl build, whose zlib is the system
//! libcurl's and not Crane's to call - gzip and deflate still decode, with
//! the same leniency, through std.compress.flate (`Inflater.zig`), driven
//! as follows. std.compress.flate's inflater is a pull decoder: it reads
//! from a std.Io.Reader and cannot stop in the middle of a symbol when its
//! input runs out. It is driven as src/compression/root.zig drives it for
//! Compression Streams: the input it sees is followed by a few zero bytes
//! of lookahead, each call is bounded, and a call that ran out of input or
//! read into the lookahead is rolled back - its decoder state restored, its
//! output dropped - to be redone when more input has come. Each call asks
//! for as much output as the input left can surely make (`stepFor`: at the
//! stream's compression ratio so far, halved), up to `max_step`, so a call
//! seldom runs out and is redone: only the last few hundred bytes of each
//! chunk go in 258-byte calls, not the whole body.
//!
//! The containers are parsed here, the way the browsers do, which is more
//! lenient than the RFCs:
//!
//! - gzip: the header is checked (magic, method 8, no reserved flag) and
//!   its optional fields skipped; the header CRC and the 8-byte trailer
//!   (CRC-32, ISIZE) are NOT checked. Chromium (net/filter/
//!   gzip_source_stream.cc) inflates raw DEFLATE after its GZipHeader and
//!   only skips the footer (STATE_GZIP_FOOTER: "gzip_footer_bytes_left_ -=
//!   to_read"); Firefox (nsHTTPCompressConv.cpp) parses the header in
//!   check_header, inflates with inflateInit2(-MAX_WBITS) and never reads
//!   the trailer back.
//! - Bytes after the stream's end are ignored - a second gzip member
//!   included: Chromium's STATE_IGNORING_EXTRA_BYTES, Firefox's mStreamEnded
//!   ("what's left is either metadata or padding of some sort").
//! - deflate: a zlib stream, or raw DEFLATE. RFC 9110 8.4.1.2's note: "Some
//!   non-conformant implementations send the "deflate" compressed data
//!   without the zlib wrapper." Chromium inflates as zlib and, when that
//!   fails before any output within the first kMaxZlibHeaderSniffBytes
//!   (1000) bytes, replays the bytes as raw DEFLATE behind a dummy zlib
//!   header (STATE_SNIFFING_DEFLATE_HEADER, InsertZlibHeader); Firefox the
//!   same on Z_DATA_ERROR (dummy_head, "some servers (notably Apache with
//!   mod_deflate) don't generate zlib headers"). Behind either header zlib
//!   checks the Adler-32 when it arrives: a mismatch fails, a missing one
//!   does not.
//! - A stream that stops early is not an error (root.zig `Stage`).
const std = @import("std");
const Allocator = std.mem.Allocator;
const flate = std.compress.flate;
const platform = @import("platform");
const root = @import("root.zig");
const Error = root.Error;
const Sink = root.Sink;

pub const Container = enum { gzip, zlib };

/// Whether the platform decodes raw DEFLATE with zlib (`zlib_inflate`).
pub const zlib_supported = platform.capabilities.zlib_inflate != .unsupported;

/// Which DEFLATE decoder a Decoder runs.
pub const Inflater = enum {
    /// zlib's, through the platform (`zlib_inflate`).
    zlib,
    /// Zig's std.compress.flate, driven with roll-backs (this file's
    /// comment).
    zig,

    /// zlib's where the platform has it.
    pub const preferred: Inflater = if (zlib_supported) .zlib else .zig;
};

/// Output each zlib call may make (Chromium's GzipSourceStream writes into
/// its 32 KiB read buffer the same way).
const native_step = 32 * 1024;

/// Output one call may make: it may write up to twice this (Zig's stored
/// block after compressed output in the same call - src/compression/root.zig
/// "returns up to twice that limit").
const max_step = 32 * 1024;
/// The smallest call: one longest DEFLATE match.
const min_step = 258;
/// Zero bytes after the real input, so that the inflater's four-byte
/// lookahead never meets the end of its buffer inside the real input.
const lookahead = 8;
/// The window: the last 32 KiB of output (DEFLATE's history), then room for
/// a call's output.
const window_len = flate.history_len + 2 * max_step + 2 * min_step;
/// Chromium's kMaxZlibHeaderSniffBytes.
const max_sniff_bytes = 1000;
/// Input kept back from a call's estimate for a dynamic block header that
/// may start inside it (at most about 300 bytes, RFC 1951 3.2.7).
const header_margin = 640;

pub const Decoder = struct {
    allocator: Allocator,
    container: Container,
    /// zlib's raw inflate (Inflater.zlib); null for Zig's.
    native: ?*platform.InflateDecoder = null,
    /// Input not consumed yet; while sniffing, every byte since the
    /// stream's start (to replay as raw DEFLATE).
    pending: std.ArrayListUnmanaged(u8) = .empty,
    /// Where in `pending` the next unread byte is (outside the inflater's
    /// calls, which move `input.seek`).
    start: usize = 0,
    input: std.Io.Reader,
    inflater: flate.Decompress,
    window: []u8,
    window_end: usize = 0,
    phase: enum { header, deflate, trailer, done } = .header,
    // gzip's header, field by field (RFC 1952 2.3).
    header_stage: enum { fixed, extra_length, extra, name, comment, crc, done } = .fixed,
    header_flags: u8 = 0,
    extra_remaining: usize = 0,
    /// zlib's Adler-32 of the output so far (RFC 1950 2.2).
    adler: std.hash.Adler32 = .{},
    /// The trailer's bytes still to come; for zlib, those that came.
    trailer_left: u8 = 0,
    trailer: [4]u8 = undefined,
    /// "deflate": no output yet behind what was taken for a zlib header -
    /// a failure now means raw DEFLATE (Chromium's sniffing state).
    sniffing: bool = false,
    /// DEFLATE input consumed and output made so far: the stream's ratio,
    /// which sizes each call (`stepFor`).
    total_in: u64 = 0,
    total_out: u64 = 0,

    pub fn create(allocator: Allocator, container: Container) Error!*Decoder {
        return createWith(allocator, container, .preferred);
    }

    pub fn createWith(allocator: Allocator, container: Container, inflater: Inflater) Error!*Decoder {
        const self = try allocator.create(Decoder);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .container = container,
            .input = .fixed(&.{}),
            .inflater = undefined,
            .window = &.{},
        };
        switch (inflater) {
            .zlib => self.native = try createNative(allocator),
            .zig => {
                self.window = try allocator.alloc(u8, window_len);
                self.inflater = .init(&self.input, .raw, &.{});
            },
        }
        return self;
    }

    pub fn destroy(self: *Decoder) void {
        if (self.native) |native| destroyNative(native);
        self.pending.deinit(self.allocator);
        self.allocator.free(self.window);
        self.allocator.destroy(self);
    }

    fn createNative(allocator: Allocator) Error!*platform.InflateDecoder {
        if (comptime !zlib_supported) unreachable;
        return platform.createInflateDecoder(allocator) catch |err| switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            // A zlib that is not the one kit/inflate declares: no decoder.
            error.InvalidData, error.NotSupported => error.InvalidData,
        };
    }

    fn destroyNative(native: *platform.InflateDecoder) void {
        if (comptime !zlib_supported) unreachable;
        platform.destroyInflateDecoder(native);
    }

    pub fn push(self: *Decoder, bytes: []const u8, sink: Sink) Error!void {
        // After the stream's end everything is ignored (see the file's
        // comment).
        if (self.phase == .done) return;
        try self.pending.appendSlice(self.allocator, bytes);
        work: while (true) switch (self.phase) {
            .header => if (!try self.header()) break :work,
            .deflate => if (!try (if (self.native != null) self.deflateNative(sink) else self.deflate(sink))) break :work,
            .trailer => if (!try self.trailerBytes()) break :work,
            .done => break :work,
        };
        if (self.phase == .done) {
            self.pending.clearAndFree(self.allocator);
            self.start = 0;
            return;
        }
        // What was read goes, unless it may be replayed.
        if (!self.sniffing and self.start > 0) {
            const rest = self.pending.items[self.start..];
            std.mem.copyForwards(u8, self.pending.items[0..rest.len], rest);
            self.pending.items.len = rest.len;
            self.start = 0;
        }
    }

    fn unread(self: *const Decoder) []const u8 {
        return self.pending.items[self.start..];
    }

    /// The container's header. False: more input is needed.
    fn header(self: *Decoder) Error!bool {
        switch (self.container) {
            .zlib => {
                const bytes = self.unread();
                if (bytes.len < 2) return false;
                // RFC 1950 2.2: CM 8, CINFO at most 7 (a window of at most
                // 32 KiB), FCHECK, and no preset dictionary - zlib's inflate
                // refuses anything else (Z_DATA_ERROR, Z_NEED_DICT), which is
                // where Chromium and Firefox take the bytes as raw DEFLATE.
                const cmf = bytes[0];
                const flg = bytes[1];
                const zlib = cmf & 0x0f == 8 and cmf >> 4 <= 7 and (@as(u16, cmf) << 8 | flg) % 31 == 0 and flg & 0x20 == 0;
                if (zlib) {
                    self.start += 2;
                    self.sniffing = true;
                }
                self.phase = .deflate;
                return true;
            },
            .gzip => {
                if (!try self.gzipHeader()) return false;
                self.phase = .deflate;
                return true;
            },
        }
    }

    /// RFC 1952 2.3: ID1 ID2 CM FLG MTIME(4) XFL OS, then FEXTRA, FNAME,
    /// FCOMMENT and FHCRC as FLG says - each read as it arrives, so a long
    /// name is never rescanned.
    fn gzipHeader(self: *Decoder) Error!bool {
        while (true) {
            const bytes = self.unread();
            switch (self.header_stage) {
                .fixed => {
                    if (bytes.len < 10) return false;
                    // 2.3.1: ID1 31, ID2 139, CM 8; FLG's reserved bits
                    // (5-7) zero - "a compliant decompressor must give an
                    // error indication if any reserved bit is non-zero"
                    // (Firefox's check_header refuses them too).
                    if (bytes[0] != 0x1f or bytes[1] != 0x8b or bytes[2] != 8 or bytes[3] & 0xe0 != 0) return error.InvalidData;
                    self.header_flags = bytes[3];
                    self.start += 10;
                    self.header_stage = .extra_length;
                },
                .extra_length => {
                    if (self.header_flags & 0x04 != 0) {
                        if (bytes.len < 2) return false;
                        self.extra_remaining = std.mem.readInt(u16, bytes[0..2], .little);
                        self.start += 2;
                    }
                    self.header_stage = .extra;
                },
                .extra => {
                    const n = @min(self.extra_remaining, bytes.len);
                    self.start += n;
                    self.extra_remaining -= n;
                    if (self.extra_remaining != 0) return false;
                    self.header_stage = .name;
                },
                .name, .comment => {
                    const flag: u8 = if (self.header_stage == .name) 0x08 else 0x10;
                    if (self.header_flags & flag != 0) {
                        const end = std.mem.indexOfScalar(u8, bytes, 0) orelse {
                            self.start += bytes.len;
                            return false;
                        };
                        self.start += end + 1;
                    }
                    self.header_stage = if (self.header_stage == .name) .comment else .crc;
                },
                .crc => {
                    // FHCRC: skipped, not checked (Firefox reads its two
                    // bytes and checks nothing).
                    if (self.header_flags & 0x02 != 0) {
                        if (bytes.len < 2) return false;
                        self.start += 2;
                    }
                    self.header_stage = .done;
                },
                .done => return true,
            }
        }
    }

    /// DEFLATE blocks through zlib, as far as the input goes. False: more
    /// input is needed. zlib keeps what it has read of a symbol, so every
    /// byte it takes is gone from `pending`; it stops at the final block's
    /// end with the bytes after it untaken (the trailer).
    fn deflateNative(self: *Decoder, sink: Sink) Error!bool {
        if (comptime !zlib_supported) unreachable;
        const native = self.native.?;
        while (true) {
            var buffer: [native_step]u8 = undefined;
            const progress = platform.inflateChunk(native, .from(self.unread()), &buffer) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.InvalidData, error.NotSupported => {
                    if (self.sniffing) return self.replayNativeAsRaw();
                    return error.InvalidData;
                },
            };
            self.start += progress.consumed;
            if (progress.produced > 0) {
                // Output: the zlib header was a zlib header.
                self.sniffing = false;
                const produced = buffer[0..progress.produced];
                if (self.container == .zlib) self.adler.update(produced);
                try sink.write(sink.context, produced);
            }
            switch (progress.status) {
                .need_output => continue,
                .need_input => {
                    // Chromium stops sniffing once enough has come without
                    // a failure.
                    if (self.sniffing and self.pending.items.len >= max_sniff_bytes) self.sniffing = false;
                    return false;
                },
                .finished => {
                    self.sniffing = false;
                    self.trailer_left = switch (self.container) {
                        .gzip => 8,
                        .zlib => 4,
                    };
                    self.phase = .trailer;
                    return true;
                },
            }
        }
    }

    /// As `replayAsRaw`, for zlib's inflater: a new raw context fed the
    /// stream from its first byte.
    fn replayNativeAsRaw(self: *Decoder) Error!bool {
        if (comptime !zlib_supported) unreachable;
        self.sniffing = false;
        destroyNative(self.native.?);
        self.native = null;
        self.native = try createNative(self.allocator);
        self.start = 0;
        self.adler = .{};
        return true;
    }

    /// DEFLATE blocks, as far as the input goes. False: more input is
    /// needed.
    fn deflate(self: *Decoder, sink: Sink) Error!bool {
        const input_end = self.pending.items.len;
        try self.pending.appendNTimes(self.allocator, 0, lookahead);
        defer self.pending.items.len = input_end;
        self.input = .{
            .vtable = &.{ .stream = needInput, .readVec = needInputVec, .rebase = needInputRebase },
            .buffer = self.pending.items,
            .seek = self.start,
            .end = self.pending.items.len,
        };
        defer self.start = self.input.seek;
        // A call that ran out of input is redone smaller: no larger call
        // in this push after it.
        var cap: usize = max_step;
        while (true) {
            const step = @min(cap, self.stepFor(input_end - self.input.seek));
            // Room for the call's output, the last 32 KiB kept as history.
            if (self.window.len - self.window_end < 2 * step + 2 * min_step) {
                const keep = @min(self.window_end, flate.history_len);
                std.mem.copyForwards(u8, self.window[0..keep], self.window[self.window_end - keep .. self.window_end]);
                self.window_end = keep;
            }
            const checkpoint = self.inflater;
            const seek = self.input.seek;
            var writer: std.Io.Writer = .fixed(self.window);
            writer.end = self.window_end;
            var incomplete = false;
            // The vtable's stream, not Reader.stream: a call may return more
            // than its limit (see max_step), which Reader.stream asserts it
            // does not.
            _ = self.inflater.reader.vtable.stream(&self.inflater.reader, &writer, .limited(step)) catch |err| switch (err) {
                error.ReadFailed => {
                    const cause = self.inflater.err orelse error.ReadFailed;
                    // Out of input - or an error close enough to its end
                    // that the zero lookahead may have caused it.
                    if (cause == error.ReadFailed or cause == error.EndOfStream or self.input.seek + 4 >= input_end) {
                        incomplete = true;
                    } else if (self.sniffing) {
                        return self.replayAsRaw();
                    } else {
                        return error.InvalidData;
                    }
                },
                // The final block ended earlier (not reached: the phase
                // moves on at the end).
                error.EndOfStream => {},
                // The room above is always enough; a call that still runs
                // out of it is refused rather than trusted.
                error.WriteFailed => return error.InvalidData,
            };
            if (incomplete or self.input.seek * 8 + self.inflater.consumed_bits > input_end * 8) {
                // Rolled back: its decoder state, input and output go.
                self.inflater = checkpoint;
                self.input.seek = seek;
                if (step == min_step) {
                    // Chromium stops sniffing once enough has come without
                    // a failure.
                    if (self.sniffing and input_end >= max_sniff_bytes) self.sniffing = false;
                    return false;
                }
                cap = @max(min_step, step / 4);
                continue;
            }
            const produced = self.window[self.window_end..writer.end];
            self.window_end = writer.end;
            self.total_in += self.input.seek - seek;
            self.total_out += produced.len;
            if (produced.len > 0) {
                // Output: the zlib header was a zlib header.
                self.sniffing = false;
                if (self.container == .zlib) self.adler.update(produced);
                try sink.write(sink.context, produced);
            }
            if (self.inflater.state == .end) {
                self.sniffing = false;
                self.trailer_left = switch (self.container) {
                    .gzip => 8,
                    .zlib => 4,
                };
                self.phase = .trailer;
                return true;
            }
            // A call that read nothing and wrote nothing is out of input.
            if (produced.len == 0 and self.input.seek == seek and self.inflater.consumed_bits == checkpoint.consumed_bits) return false;
        }
    }

    /// The output to ask of a call with `available` bytes of input left: as
    /// much as they can surely make at the stream's ratio so far (each
    /// output byte costs at most about two input bytes: a 15-bit literal
    /// code; RFC 1951 3.2.5-3.2.6), short of a block header's margin.
    fn stepFor(self: *const Decoder, available: usize) usize {
        if (available <= header_margin) return min_step;
        const ratio: u64 = if (self.total_in > 0) @max(1, self.total_out / self.total_in) else 1;
        const surely: u64 = (available - header_margin) * ratio / 2;
        return @intCast(std.math.clamp(surely, min_step, max_step));
    }

    /// The zlib header was not one: the stream is raw DEFLATE from its
    /// first byte (Chromium's STATE_REPLAY_DATA; nothing has been output).
    fn replayAsRaw(self: *Decoder) Error!bool {
        self.sniffing = false;
        self.inflater = .init(&self.input, .raw, &.{});
        self.input.seek = 0;
        self.window_end = 0;
        self.adler = .{};
        return true;
    }

    /// The trailer: gzip's 8 bytes skipped, zlib's Adler-32 checked.
    fn trailerBytes(self: *Decoder) Error!bool {
        const bytes = self.unread();
        const n = @min(self.trailer_left, bytes.len);
        if (self.container == .zlib) {
            const have = 4 - self.trailer_left;
            @memcpy(self.trailer[have..][0..n], bytes[0..n]);
        }
        self.start += n;
        self.trailer_left -= @intCast(n);
        if (self.trailer_left != 0) return false;
        if (self.container == .zlib and std.mem.readInt(u32, &self.trailer, .big) != self.adler.adler) return error.InvalidData;
        self.phase = .done;
        return true;
    }

    fn needInput(_: *std.Io.Reader, _: *std.Io.Writer, _: std.Io.Limit) std.Io.Reader.StreamError!usize {
        return error.ReadFailed;
    }

    fn needInputVec(_: *std.Io.Reader, _: [][]u8) std.Io.Reader.Error!usize {
        return error.ReadFailed;
    }

    fn needInputRebase(_: *std.Io.Reader, _: usize) std.Io.Reader.RebaseError!void {
        return error.ReadFailed;
    }
};
