//! Stateful, engine-free Compression Streams codecs (Compression §§3–5).
//! DEFLATE is std.compress; container validation is stricter than the stdlib
//! reader, which only records trailer checksums. No native codec is linked.
const std = @import("std");
const flate = std.compress.flate;
const Allocator = std.mem.Allocator;

/// CompressionFormat's three DEFLATE formats.
pub const Format = enum {
    deflate,
    deflate_raw,
    gzip,

    fn container(self: Format) flate.Container {
        return switch (self) {
            .deflate => .zlib,
            .deflate_raw => .raw,
            .gzip => .gzip,
        };
    }
};

pub const Error = error{ OutOfMemory, InvalidData };

/// An incremental compressor. Its address is stable: std.compress's writer
/// refers to the output member and the history buffer. The caller owns it.
pub const Encoder = struct {
    allocator: Allocator,
    output: std.Io.Writer.Allocating,
    history: [flate.max_window_len]u8 = undefined,
    compressor: flate.Compress,
    finished: bool = false,

    pub fn create(allocator: Allocator, format: Format) Error!*Encoder {
        const self = try allocator.create(Encoder);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .output = try .initCapacity(allocator, 4096),
            .compressor = undefined,
        };
        errdefer self.output.deinit();
        self.compressor = flate.Compress.init(&self.output.writer, &self.history, format.container(), .default) catch return error.OutOfMemory;
        return self;
    }

    pub fn destroy(self: *Encoder) void {
        self.output.deinit();
        self.allocator.destroy(self);
    }

    /// Compress a chunk, optionally finishing the single stream. Returned
    /// bytes belong to the caller, including when the result is empty.
    pub fn push(self: *Encoder, input: []const u8, final: bool) Error![]u8 {
        if (self.finished) return error.InvalidData;
        errdefer self.finished = true;
        self.compressor.writer.writeAll(input) catch return error.OutOfMemory;
        if (final) {
            self.compressor.finish() catch return error.OutOfMemory;
            self.finished = true;
        }
        const output = try self.allocator.dupe(u8, self.output.written());
        self.output.writer.end = 0;
        return output;
    }
};

/// A push adapter around std.compress's pull inflater. Each decode call is
/// bounded to two maximum DEFLATE matches. An incomplete call rolls back its
/// own input/output and decoder state; already committed output is never
/// replayed. Only the last 32 KiB of output is retained as DEFLATE history.
/// Headers and trailers are validated separately, including gzip FHCRC.
pub const Decoder = struct {
    allocator: Allocator,
    format: Format,
    pending: std.ArrayListUnmanaged(u8) = .empty,
    input: std.Io.Reader,
    inflater: flate.Decompress,
    history: [flate.max_window_len]u8 = undefined,
    history_end: usize = 0,
    phase: enum { header, deflate, footer, end } = .header,
    hasher: flate.Container.Hasher,
    finished: bool = false,
    header_stage: enum { fixed, extra_length, extra, name, comment, crc, done } = .fixed,
    header_flags: u8 = 0,
    extra_remaining: usize = 0,
    header_crc: std.hash.Crc32 = .init(),
    valid_prefix: []u8 = &.{},

    pub fn create(allocator: Allocator, format: Format) Error!*Decoder {
        const self = try allocator.create(Decoder);
        self.* = .{
            .allocator = allocator,
            .format = format,
            .input = .fixed(&.{}),
            .inflater = undefined,
            .hasher = .init(format.container()),
        };
        self.inflater = .init(&self.input, .raw, &.{});
        return self;
    }

    pub fn destroy(self: *Decoder) void {
        self.pending.deinit(self.allocator);
        self.allocator.free(self.valid_prefix);
        self.allocator.destroy(self);
    }

    /// Transfer output from a complete stream whose trailing data errors.
    /// Compression's enqueue step precedes its trailing-data check. The
    /// caller owns these bytes; ordinary decoding errors produce no prefix.
    pub fn takeValidPrefix(self: *Decoder) []u8 {
        const prefix = self.valid_prefix;
        self.valid_prefix = &.{};
        return prefix;
    }

    /// Decompress available bytes. A complete input emits before `final`;
    /// `final` rejects a missing trailer or incomplete DEFLATE block. Errors
    /// permanently fail this codec, as they error both sides of the stream.
    pub fn push(self: *Decoder, bytes: []const u8, final: bool) Error![]u8 {
        if (self.finished) return error.InvalidData;
        errdefer self.finished = true;
        try self.pending.appendSlice(self.allocator, bytes);
        const input_end = self.pending.items.len;
        // std's Huffman lookup peeks four bytes. Its short-input fallback in
        // Zig 0.16 adds consumed_bits when checking availability, which can
        // toss beyond a chunk's end. Supply bounded lookahead, but commit a
        // step only when every consumed bit belongs to the real input.
        try self.pending.appendNTimes(self.allocator, 0, 8);
        self.input = .fixed(self.pending.items[0..input_end]);
        var output: std.Io.Writer.Allocating = .init(self.allocator);
        defer output.deinit();
        work: while (true) switch (self.phase) {
            .header => {
                if (!try self.readHeader()) break :work;
                self.phase = .deflate;
            },
            .deflate => {
                self.input.buffer = self.pending.items;
                self.input.end = self.pending.items.len;
                self.input.vtable = &.{ .stream = needInput, .readVec = needInputVec, .rebase = needInputRebase };
                // Rebase before the checkpoint so its history cannot be
                // overwritten by output produced during an incomplete step.
                if (self.history_end + 516 > self.history.len) {
                    @memmove(self.history[0..flate.history_len], self.history[self.history_end - flate.history_len .. self.history_end]);
                    self.history_end = flate.history_len;
                }
                const checkpoint = self.inflater;
                const input_seek = self.input.seek;
                var writer: std.Io.Writer = .fixed(&self.history);
                writer.end = self.history_end;
                var incomplete = false;
                // Zig 0.16's compressed-to-stored transition uses the original
                // limit for the stored block, after already producing bytes.
                // It can therefore return up to twice that limit. Reserve that
                // bound and call its vtable without Reader.stream's stronger
                // assertion; writer.end is the actual committed byte count.
                _ = self.inflater.reader.vtable.stream(&self.inflater.reader, &writer, .limited(258)) catch |err| blk: {
                    switch (err) {
                        error.ReadFailed => {
                            const cause = self.inflater.err orelse return error.InvalidData;
                            if (cause != error.ReadFailed and cause != error.EndOfStream and self.input.seek + 4 < input_end)
                                return error.InvalidData;
                            incomplete = true;
                        },
                        error.EndOfStream => {},
                        error.WriteFailed => unreachable, // at least 516 free bytes
                    }
                    break :blk 0;
                };
                if (incomplete or self.input.seek * 8 + self.inflater.consumed_bits > input_end * 8) {
                    self.inflater = checkpoint;
                    self.input.seek = input_seek;
                    break :work;
                }
                const produced = self.history[self.history_end..writer.end];
                self.hasher.update(produced);
                output.writer.writeAll(produced) catch return error.OutOfMemory;
                self.history_end = writer.end;
                if (self.inflater.state == .end) self.phase = .footer;
            },
            .footer => {
                const tail = self.pending.items[self.input.seek..input_end];
                const n = self.format.container().footerSize();
                if (tail.len < n) break :work;
                switch (self.hasher) {
                    .raw => {},
                    .zlib => |hash| if (std.mem.readInt(u32, tail[0..4], .big) != hash.adler) return error.InvalidData,
                    .gzip => |hash| {
                        if (std.mem.readInt(u32, tail[0..4], .little) != hash.crc.final()) return error.InvalidData;
                        if (std.mem.readInt(u32, tail[4..8], .little) != hash.count) return error.InvalidData;
                    },
                }
                self.input.seek += n;
                self.phase = .end;
            },
            .end => {
                // Compression §3: exactly one stream/member. Empty later
                // chunks are valid; any byte after the trailer is an error.
                if (self.input.seek != input_end) {
                    // Decompression's enqueue step 5 precedes step 6's
                    // trailing-data error. Preserve the completed prefix for
                    // the native transformer, even though this push fails.
                    self.valid_prefix = output.toOwnedSlice() catch return error.OutOfMemory;
                    return error.InvalidData;
                }
                break :work;
            },
        };
        if (final and self.phase != .end) return error.InvalidData;
        const remaining = self.pending.items[self.input.seek..input_end];
        @memmove(self.pending.items[0..remaining.len], remaining);
        self.pending.items.len = remaining.len;
        self.finished = final;
        return output.toOwnedSlice() catch return error.OutOfMemory;
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

    fn headerBytes(self: *Decoder, n: usize) void {
        self.header_crc.update(self.input.buffer[self.input.seek..][0..n]);
        self.input.seek += n;
    }

    // Optional gzip fields are consumed incrementally: arbitrary-length names
    // and comments never accumulate in pending or get rescanned on each push.
    fn readHeader(self: *Decoder) Error!bool {
        while (true) {
            const bytes = self.input.buffer[self.input.seek..];
            switch (self.header_stage) {
                .fixed => switch (self.format) {
                    .deflate_raw => return true,
                    .deflate => {
                        if (bytes.len < 2) return false;
                        if (bytes[0] & 15 != 8 or bytes[0] >> 4 > 7 or bytes[1] & 32 != 0) return error.InvalidData;
                        if (std.mem.readInt(u16, bytes[0..2], .big) % 31 != 0) return error.InvalidData;
                        self.input.seek += 2;
                        return true;
                    },
                    .gzip => {
                        if (bytes.len < 10) return false;
                        if (bytes[0] != 0x1f or bytes[1] != 0x8b or bytes[2] != 8 or bytes[3] & 0xe0 != 0) return error.InvalidData;
                        self.header_flags = bytes[3];
                        self.headerBytes(10);
                        self.header_stage = .extra_length;
                    },
                },
                .extra_length => {
                    if (self.header_flags & 4 != 0) {
                        if (bytes.len < 2) return false;
                        self.extra_remaining = std.mem.readInt(u16, bytes[0..2], .little);
                        self.headerBytes(2);
                    }
                    self.header_stage = .extra;
                },
                .extra => {
                    const n = @min(self.extra_remaining, bytes.len);
                    self.headerBytes(n);
                    self.extra_remaining -= n;
                    if (self.extra_remaining != 0) return false;
                    self.header_stage = .name;
                },
                .name, .comment => {
                    const flag: u8 = if (self.header_stage == .name) 8 else 16;
                    if (self.header_flags & flag != 0) {
                        if (std.mem.indexOfScalar(u8, bytes, 0)) |n| {
                            self.headerBytes(n + 1);
                        } else {
                            self.headerBytes(bytes.len);
                            return false;
                        }
                    }
                    self.header_stage = if (self.header_stage == .name) .comment else .crc;
                },
                .crc => {
                    if (self.header_flags & 2 != 0) {
                        if (bytes.len < 2) return false;
                        const expected: u16 = @truncate(self.header_crc.final());
                        if (std.mem.readInt(u16, bytes[0..2], .little) != expected) return error.InvalidData;
                        self.input.seek += 2;
                    }
                    self.header_stage = .done;
                },
                .done => return true,
            }
        }
    }
};
