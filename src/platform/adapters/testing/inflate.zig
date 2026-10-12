//! The testing platform's zlib inflater (RFC 1950's container around RFC
//! 1951's DEFLATE), for png.zig's image data. It decodes as far as its input
//! goes and stops exactly there: every symbol whose bits are all present is
//! decoded and none is guessed, as zlib's own inflate leaves a truncated
//! stream - which is how libpng, under Gecko, decodes a truncated PNG's
//! rows. std.compress.flate in Zig 0.16 cannot be handed input that simply
//! stops (its short-input paths assert or overflow: tossBitsShort,
//! peekBitsEnding - docs/lessons/debugging-a-pull-inflater-needs-short-input-
//! and-block-transition-tests.md), and with padding in their place it
//! consumes the next symbol before returning the one asked for, so where the
//! real input ends it cannot say.
//!
//! What is invalid is what zlib's inflate rejects: a bad header (method 8,
//! a window of at most 32 KiB, the FCHECK bits, no preset dictionary), block
//! type 3, a stored block whose LEN and NLEN disagree, a dynamic header with
//! more than 286 literal/length or 30 distance codes, a repeat with nothing
//! to repeat or past the end of the lengths, no end-of-block code, an
//! over-subscribed code, an incomplete one other than a single 1-bit code
//! (and an incomplete code-length code), length symbols 286 and 287,
//! distance symbols 30 and 31, and a distance past the start of the output.
//! The Adler-32 check is not read: the caller asks for exactly the bytes it
//! needs, and the stream's end is never reached for a whole image.

const std = @import("std");

/// Why `zlib` stopped.
pub const End = enum {
    /// `out` is full.
    complete,
    /// The input ended first.
    ran_out,
    /// The stream is invalid.
    invalid,
    /// The stream's final block ended first.
    ended,
};

pub const Result = struct {
    /// The bytes of `out` written.
    len: usize,
    end: End,
};

/// Inflate the zlib stream `input` into `out`, as far as it goes.
pub fn zlib(out: []u8, input: []const u8) Result {
    var inflater: Inflater = .{ .out = out, .bits = .{ .input = input } };
    const end = inflater.run();
    return .{ .len = inflater.written, .end = end };
}

const Error = error{ RanOut, Invalid, Full, Ended };

/// The input's bits, least significant first (RFC 1951 3.1.1).
const Bits = struct {
    input: []const u8,
    pos: usize = 0,
    buffer: u64 = 0,
    count: u7 = 0,

    fn take(self: *Bits, n: u6) Error!u32 {
        if (n == 0) return 0;
        while (self.count < n) {
            if (self.pos == self.input.len) return error.RanOut;
            self.buffer |= @as(u64, self.input[self.pos]) << @intCast(self.count);
            self.pos += 1;
            self.count += 8;
        }
        const value: u32 = @intCast(self.buffer & ((@as(u64, 1) << n) - 1));
        self.buffer >>= n;
        self.count -= n;
        return value;
    }

    /// Skip to the next byte boundary (a stored block's LEN).
    fn alignToByte(self: *Bits) void {
        const drop: u6 = @intCast(self.count % 8);
        self.buffer >>= drop;
        self.count -= drop;
    }

    /// The next whole byte, after `alignToByte`.
    fn byte(self: *Bits) Error!u8 {
        return @intCast(try self.take(8));
    }
};

const max_bits = 15;

/// A canonical Huffman code (RFC 1951 3.2.2), decoded a bit at a time.
const Huffman = struct {
    /// How many codes there are of each length.
    count: [max_bits + 1]u16 = @splat(0),
    /// The symbols, in code order.
    symbol: [288]u16 = @splat(0),

    const Kind = enum { code_lengths, other };

    /// Build the code from each symbol's code length (0: unused), refusing
    /// what zlib's inflate_table refuses: an over-subscribed code, and an
    /// incomplete one - except, for a literal/length or distance code, a
    /// single 1-bit code. No codes at all is allowed (decoding then fails).
    fn build(self: *Huffman, lengths: []const u4, kind: Kind) Error!void {
        self.count = @splat(0);
        for (lengths) |len| self.count[len] += 1;
        self.count[0] = 0;
        var longest: usize = max_bits;
        while (longest > 0 and self.count[longest] == 0) longest -= 1;
        if (longest == 0) return;
        var left: i32 = 1;
        for (1..max_bits + 1) |len| {
            left <<= 1;
            left -= self.count[len];
            if (left < 0) return error.Invalid;
        }
        if (left > 0 and (kind == .code_lengths or longest != 1)) return error.Invalid;
        var offsets: [max_bits + 1]u16 = undefined;
        offsets[1] = 0;
        for (1..max_bits) |len| offsets[len + 1] = offsets[len] + self.count[len];
        for (lengths, 0..) |len, symbol| {
            if (len == 0) continue;
            self.symbol[offsets[len]] = @intCast(symbol);
            offsets[len] += 1;
        }
    }

    /// The next symbol: the first code, a bit at a time, that the lengths
    /// so far place it in.
    fn decode(self: *const Huffman, bits: *Bits) Error!u16 {
        var code: i32 = 0;
        var first: i32 = 0;
        var index: i32 = 0;
        for (1..max_bits + 1) |len| {
            code |= @intCast(try bits.take(1));
            const count: i32 = self.count[len];
            if (code - count < first) return self.symbol[@intCast(index + (code - first))];
            index += count;
            first += count;
            first <<= 1;
            code <<= 1;
        }
        return error.Invalid;
    }
};

/// RFC 1951 3.2.5.
const length_base = [29]u16{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
const length_extra = [29]u6{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
const distance_base = [30]u16{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
const distance_extra = [30]u6{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };

/// RFC 1951 3.2.7: the order of the code-length code's lengths.
const code_length_order = [19]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

const Inflater = struct {
    out: []u8,
    written: usize = 0,
    bits: Bits,
    literals: Huffman = .{},
    distances: Huffman = .{},

    fn run(self: *Inflater) End {
        self.stream() catch |err| return switch (err) {
            error.RanOut => .ran_out,
            error.Invalid => .invalid,
            error.Full => .complete,
            error.Ended => .ended,
        };
        unreachable;
    }

    /// The stream, until one of `Error`'s ends: it returns no other way.
    fn stream(self: *Inflater) Error!void {
        if (self.out.len == 0) return error.Full;
        // RFC 1950 2.2: CMF and FLG.
        const cmf = try self.bits.byte();
        const flg = try self.bits.byte();
        if (cmf & 0x0f != 8 or cmf >> 4 > 7 or (@as(u16, cmf) << 8 | flg) % 31 != 0 or flg & 0x20 != 0) return error.Invalid;
        // RFC 1951 3.2.3: blocks until the final one.
        while (true) {
            const final = try self.bits.take(1) == 1;
            switch (try self.bits.take(2)) {
                0 => try self.storedBlock(),
                1 => {
                    var lengths: [288]u4 = undefined;
                    @memset(lengths[0..144], 8);
                    @memset(lengths[144..256], 9);
                    @memset(lengths[256..280], 7);
                    @memset(lengths[280..288], 8);
                    try self.literals.build(&lengths, .other);
                    // All 32 five-bit codes: 30 and 31 decode, and are
                    // invalid (3.2.6).
                    const distance_lengths: [32]u4 = @splat(5);
                    try self.distances.build(&distance_lengths, .other);
                    try self.huffmanBlock();
                },
                2 => {
                    try self.dynamicHeader();
                    try self.huffmanBlock();
                },
                else => return error.Invalid,
            }
            if (final) return error.Ended;
        }
    }

    fn put(self: *Inflater, value: u8) Error!void {
        self.out[self.written] = value;
        self.written += 1;
        if (self.written == self.out.len) return error.Full;
    }

    /// 3.2.4: LEN, NLEN, and LEN bytes - copied as far as they arrived.
    fn storedBlock(self: *Inflater) Error!void {
        self.bits.alignToByte();
        const len_low = try self.bits.byte();
        const len_high = try self.bits.byte();
        const nlen_low = try self.bits.byte();
        const nlen_high = try self.bits.byte();
        const len = @as(u16, len_high) << 8 | len_low;
        const nlen = @as(u16, nlen_high) << 8 | nlen_low;
        if (len != ~nlen) return error.Invalid;
        for (0..len) |_| try self.put(try self.bits.byte());
    }

    /// 3.2.7: the code lengths, Huffman-coded themselves.
    fn dynamicHeader(self: *Inflater) Error!void {
        const literal_count = try self.bits.take(5) + 257;
        const distance_count = try self.bits.take(5) + 1;
        const code_length_count = try self.bits.take(4) + 4;
        if (literal_count > 286 or distance_count > 30) return error.Invalid;
        var code_lengths: [19]u4 = @splat(0);
        for (code_length_order[0..code_length_count]) |symbol| code_lengths[symbol] = @intCast(try self.bits.take(3));
        var code_length_code: Huffman = .{};
        try code_length_code.build(&code_lengths, .code_lengths);

        var lengths: [286 + 30]u4 = @splat(0);
        const total = literal_count + distance_count;
        var i: usize = 0;
        while (i < total) {
            const symbol = try code_length_code.decode(&self.bits);
            if (symbol < 16) {
                lengths[i] = @intCast(symbol);
                i += 1;
                continue;
            }
            // 16: the previous length 3 to 6 times; 17 and 18: zero, 3 to
            // 10 and 11 to 138 times.
            var repeated: u4 = 0;
            var times: u32 = undefined;
            switch (symbol) {
                16 => {
                    if (i == 0) return error.Invalid;
                    repeated = lengths[i - 1];
                    times = 3 + try self.bits.take(2);
                },
                17 => times = 3 + try self.bits.take(3),
                else => times = 11 + try self.bits.take(7),
            }
            if (i + times > total) return error.Invalid;
            @memset(lengths[i..][0..times], repeated);
            i += times;
        }
        // The end-of-block code must be there.
        if (lengths[256] == 0) return error.Invalid;
        try self.literals.build(lengths[0..literal_count], .other);
        try self.distances.build(lengths[literal_count..total], .other);
    }

    /// 3.2.5: literals, and lengths with their distances, to the end of the
    /// block. A symbol is written only once all of its bits have arrived.
    fn huffmanBlock(self: *Inflater) Error!void {
        while (true) {
            const symbol = try self.literals.decode(&self.bits);
            if (symbol < 256) {
                try self.put(@intCast(symbol));
                continue;
            }
            if (symbol == 256) return;
            const length_symbol = symbol - 257;
            if (length_symbol >= length_base.len) return error.Invalid;
            const length = length_base[length_symbol] + try self.bits.take(length_extra[length_symbol]);
            const distance_symbol = try self.distances.decode(&self.bits);
            if (distance_symbol >= distance_base.len) return error.Invalid;
            const distance = distance_base[distance_symbol] + try self.bits.take(distance_extra[distance_symbol]);
            if (distance > self.written) return error.Invalid;
            // Byte by byte: a copy may overlap what it writes.
            for (0..length) |_| try self.put(self.out[self.written - distance]);
        }
    }
};
