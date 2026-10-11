//! The code units of a string held as WTF-8.
//!
//! Infra defines a string as a sequence of 16-bit code units (Infra §4.6,
//! "string"), and the DOM measures and indexes strings in them: a node's
//! length, substring data and replace data (DOM 4.10), a range's offsets.
//! Crane holds a DOM string as its WTF-8 encoding: a surrogate pair as one
//! four-byte sequence and a lone surrogate as its three bytes ED A0..BF xx,
//! which is what V8's WriteUtf8 writes without REPLACE_INVALID_UTF8
//! (conversions.fromV8Value) and what newStringFromWtf8 turns back into the
//! same code units. This file maps code-unit offsets onto those bytes.
//!
//! Two rules keep the bytes canonical WTF-8, so that byte equality stays
//! string equality (isEqualNode compares data bytes):
//! - an offset between the two code units of a four-byte sequence splits it
//!   into its two three-byte surrogates;
//! - where two pieces meet, a high surrogate's three bytes followed by a low
//!   surrogate's become the pair's four-byte sequence.
//!
//! Every function takes well-formed (generalized) WTF-8 - what V8, the HTML
//! parser and the encoders produce - and never reads outside the slice it is
//! given when the bytes are not.

const std = @import("std");

const lanes = 32;
const Block = @Vector(lanes, u8);

/// The UTF-16 code units one byte contributes: 1 for a byte that starts a
/// sequence, 0 for a continuation byte, and 1 more for the lead byte of a
/// four-byte sequence (a supplementary code point is a surrogate pair).
inline fn byteUnits(byte: u8) usize {
    return @as(usize, @intFromBool((byte & 0xC0) != 0x80)) + @intFromBool(byte >= 0xF0);
}

/// The code units of a block of `lanes` bytes, counted at their lead bytes.
inline fn blockUnits(block: Block) usize {
    if (@reduce(.Max, block) < 0x80) return lanes;
    const lead = (block & @as(Block, @splat(0xC0))) != @as(Block, @splat(0x80));
    const four = block >= @as(Block, @splat(0xF0));
    const Mask = std.meta.Int(.unsigned, lanes);
    return @popCount(@as(Mask, @bitCast(lead))) + @popCount(@as(Mask, @bitCast(four)));
}

/// The length of `bytes` in UTF-16 code units: Infra's string length.
pub fn codeUnitLength(bytes: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i + lanes <= bytes.len) : (i += lanes) count += blockUnits(bytes[i..][0..lanes].*);
    for (bytes[i..]) |byte| count += byteUnits(byte);
    return count;
}

/// Where a code-unit offset falls in the bytes.
pub const Position = struct {
    /// The byte offset of the code point the code unit starts - or, for
    /// `mid_pair`, of the four-byte sequence whose low surrogate it is.
    byte: usize,
    /// The offset lies between the high and the low surrogate of the
    /// four-byte sequence at `byte`.
    mid_pair: bool = false,
};

/// The position of code unit `unit` in `bytes`; the end of the bytes for an
/// offset at or past their length.
pub fn positionOfCodeUnit(bytes: []const u8, unit: usize) Position {
    var counted: usize = 0;
    var i: usize = 0;
    // Whole blocks whose code units all come before `unit`. A block's units
    // are those of its lead bytes, so a sequence that runs on into the next
    // block is counted once, here; its continuation bytes are skipped below.
    while (i + lanes <= bytes.len) {
        const units = blockUnits(bytes[i..][0..lanes].*);
        if (counted + units > unit) break;
        counted += units;
        i += lanes;
    }
    while (i < bytes.len) : (i += 1) {
        const byte = bytes[i];
        if ((byte & 0xC0) == 0x80) continue;
        if (counted == unit) return .{ .byte = i };
        if (byte >= 0xF0) {
            if (counted + 1 == unit) return .{ .byte = i, .mid_pair = true };
            counted += 2;
        } else counted += 1;
    }
    return .{ .byte = bytes.len };
}

/// The three-byte encoding of a surrogate code unit.
fn encodeSurrogate(unit: u16) [3]u8 {
    return .{
        @intCast(0xE0 | (unit >> 12)),
        @intCast(0x80 | ((unit >> 6) & 0x3F)),
        @intCast(0x80 | (unit & 0x3F)),
    };
}

/// The surrogate code unit a three-byte sequence encodes.
fn decodeSurrogate(bytes: []const u8) u16 {
    return (@as(u16, bytes[0] & 0x0F) << 12) | (@as(u16, bytes[1] & 0x3F) << 6) | (bytes[2] & 0x3F);
}

const Halves = struct { high: [3]u8, low: [3]u8 };

/// The two surrogates of the four-byte sequence at the start of `bytes`,
/// each in its three-byte form. A truncated sequence (ill-formed input) gives
/// U+FFFD for both rather than reading past the slice.
fn pairHalves(bytes: []const u8) Halves {
    const replacement = [3]u8{ 0xEF, 0xBF, 0xBD };
    if (bytes.len < 4) return .{ .high = replacement, .low = replacement };
    const code_point: u21 = (@as(u21, bytes[0] & 0x07) << 18) | (@as(u21, bytes[1] & 0x3F) << 12) |
        (@as(u21, bytes[2] & 0x3F) << 6) | (bytes[3] & 0x3F);
    if (code_point < 0x10000) return .{ .high = replacement, .low = replacement };
    const offset = code_point - 0x10000;
    return .{
        .high = encodeSurrogate(@intCast(0xD800 + (offset >> 10))),
        .low = encodeSurrogate(@intCast(0xDC00 + (offset & 0x3FF))),
    };
}

/// Whether `bytes` ends with a high surrogate's three bytes, ED A0..AF xx.
/// ED is never a continuation byte, so the last three bytes are a whole
/// sequence when it starts them.
fn endsWithHighSurrogate(bytes: []const u8) bool {
    if (bytes.len < 3) return false;
    const tail = bytes[bytes.len - 3 ..];
    return tail[0] == 0xED and tail[1] >= 0xA0 and tail[1] <= 0xAF;
}

/// Whether `bytes` starts with a low surrogate's three bytes, ED B0..BF xx.
fn startsWithLowSurrogate(bytes: []const u8) bool {
    return bytes.len >= 3 and bytes[0] == 0xED and bytes[1] >= 0xB0 and bytes[1] <= 0xBF;
}

/// The four-byte sequence of the pair a high and a low surrogate make.
fn joinPair(high: []const u8, low: []const u8) [4]u8 {
    const code_point: u21 = 0x10000 + (@as(u21, decodeSurrogate(high) - 0xD800) << 10) + (decodeSurrogate(low) - 0xDC00);
    return .{
        @intCast(0xF0 | (code_point >> 18)),
        @intCast(0x80 | ((code_point >> 12) & 0x3F)),
        @intCast(0x80 | ((code_point >> 6) & 0x3F)),
        @intCast(0x80 | (code_point & 0x3F)),
    };
}

/// A string being assembled from up to five pieces - a substring or a
/// splice - written one after another with each seam joined: a piece that
/// ends with a high surrogate and one that starts with a low surrogate meet
/// as the pair's four-byte sequence.
///
/// Fill it in place (`var pieces: Pieces = .{}`): the split surrogates are
/// held in the struct itself.
pub const Pieces = struct {
    items: [5][]const u8 = undefined,
    count: usize = 0,
    high: [3]u8 = undefined,
    low: [3]u8 = undefined,

    fn add(self: *Pieces, piece: []const u8) void {
        if (piece.len == 0) return;
        self.items[self.count] = piece;
        self.count += 1;
    }

    /// The code units from `start` to `end` of `bytes` (DOM's substring
    /// data): a pair cut at either end leaves its surrogate.
    pub fn substring(self: *Pieces, bytes: []const u8, start: Position, end: Position) void {
        self.* = .{};
        if (start.byte == end.byte and start.mid_pair == end.mid_pair) return;
        var from = start.byte;
        if (start.mid_pair) {
            self.low = pairHalves(bytes[start.byte..]).low;
            self.add(&self.low);
            from += 4;
        }
        if (end.byte > from) self.add(bytes[from..end.byte]);
        if (end.mid_pair) {
            self.high = pairHalves(bytes[end.byte..]).high;
            self.add(&self.high);
        }
    }

    /// `bytes` with the code units from `start` to `end` replaced by `data`
    /// (DOM's replace data, steps 5-7).
    pub fn splice(self: *Pieces, bytes: []const u8, start: Position, end: Position, data: []const u8) void {
        self.* = .{};
        self.add(bytes[0..start.byte]);
        if (start.mid_pair) {
            self.high = pairHalves(bytes[start.byte..]).high;
            self.add(&self.high);
        }
        self.add(data);
        var rest = end.byte;
        if (end.mid_pair) {
            self.low = pairHalves(bytes[end.byte..]).low;
            self.add(&self.low);
            rest = @min(end.byte + 4, bytes.len);
        }
        self.add(bytes[rest..]);
    }

    /// The byte length of the pieces once their seams are joined.
    pub fn joinedLength(self: *const Pieces) usize {
        var total: usize = 0;
        for (self.items[0..self.count], 0..) |piece, k| {
            total += piece.len;
            if (k > 0 and endsWithHighSurrogate(self.items[k - 1]) and startsWithLowSurrogate(piece)) total -= 2;
        }
        return total;
    }

    /// Write the pieces into `dest`, exactly `joinedLength()` bytes. `dest`
    /// must not overlap the bytes the pieces were taken from.
    pub fn writeJoined(self: *const Pieces, dest: []u8) void {
        var written: usize = 0;
        for (self.items[0..self.count], 0..) |piece, k| {
            var rest = piece;
            if (k > 0 and endsWithHighSurrogate(self.items[k - 1]) and startsWithLowSurrogate(piece)) {
                const pair = joinPair(dest[written - 3 .. written], piece[0..3]);
                @memcpy(dest[written - 3 ..][0..4], &pair);
                written += 1;
                rest = piece[3..];
            }
            @memcpy(dest[written..][0..rest.len], rest);
            written += rest.len;
        }
        std.debug.assert(written == dest.len);
    }

    /// The joined pieces in a new allocation. OWNED.
    pub fn toOwned(self: *const Pieces, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.joinedLength());
        self.writeJoined(result);
        return result;
    }
};

/// The code units from `start` to `end` (end at least start) of `bytes`, in
/// a new allocation. OWNED.
pub fn substring(allocator: std.mem.Allocator, bytes: []const u8, start: usize, end: usize) ![]u8 {
    var pieces: Pieces = .{};
    pieces.substring(bytes, positionOfCodeUnit(bytes, start), positionOfCodeUnit(bytes, end));
    return pieces.toOwned(allocator);
}

/// `bytes` with the code units from `start` to `end` (end at least start)
/// replaced by `data`, in a new allocation. OWNED.
pub fn splice(allocator: std.mem.Allocator, bytes: []const u8, start: usize, end: usize, data: []const u8) ![]u8 {
    var pieces: Pieces = .{};
    pieces.splice(bytes, positionOfCodeUnit(bytes, start), positionOfCodeUnit(bytes, end), data);
    return pieces.toOwned(allocator);
}

/// Append `bytes` to `list`, joining a high surrogate the list ends with and
/// a low surrogate `bytes` starts with into their pair: Infra's concatenate
/// over WTF-8.
pub fn appendJoined(allocator: std.mem.Allocator, list: *std.ArrayListUnmanaged(u8), bytes: []const u8) !void {
    if (endsWithHighSurrogate(list.items) and startsWithLowSurrogate(bytes)) {
        try list.ensureUnusedCapacity(allocator, bytes.len - 2);
        const at = list.items.len - 3;
        const pair = joinPair(list.items[at..], bytes[0..3]);
        list.items.len = at;
        list.appendSliceAssumeCapacity(&pair);
        list.appendSliceAssumeCapacity(bytes[3..]);
        return;
    }
    try list.appendSlice(allocator, bytes);
}

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

// Code units in WTF-8 (python: chr(u).encode('utf-8', 'surrogatepass')).
const hi_d83c = "\xED\xA0\xBC";
const hi_d83d = "\xED\xA0\xBD";
const lo_df20 = "\xED\xBC\xA0";
const lo_df1f = "\xED\xBC\x9F";
const lo_de00 = "\xED\xB8\x80";
const shooting_star = "\xF0\x9F\x8C\xA0"; // U+1F320 = D83C DF20
const glowing_star = "\xF0\x9F\x8C\x9F"; // U+1F31F = D83C DF1F
const alchemical = "\xF0\x9F\x9C\xA0"; // U+1F720 = D83D DF20
const grinning = "\xF0\x9F\x98\x80"; // U+1F600 = D83D DE00

/// The code units of `bytes`, decoded one sequence at a time: the reference
/// the vectorised functions are checked against.
fn referenceUnits(bytes: []const u8, out: []u16) usize {
    var n: usize = 0;
    var i: usize = 0;
    while (i < bytes.len) {
        const b = bytes[i];
        const width: usize = if (b < 0x80) 1 else if (b < 0xE0) 2 else if (b < 0xF0) 3 else 4;
        if (width == 4) {
            out[n] = 0xD800;
            out[n + 1] = 0xDC00;
            n += 2;
        } else {
            out[n] = 0;
            n += 1;
        }
        i += width;
    }
    return n;
}

test "codeUnitLength counts UTF-16 code units, not bytes or code points" {
    try testing.expectEqual(@as(usize, 0), codeUnitLength(""));
    try testing.expectEqual(@as(usize, 3), codeUnitLength("abc"));
    try testing.expectEqual(@as(usize, 1), codeUnitLength("\xC3\xA9")); // é
    try testing.expectEqual(@as(usize, 2), codeUnitLength("\xE6\x97\xA5\xE6\x9C\xAC")); // 日本
    try testing.expectEqual(@as(usize, 2), codeUnitLength(grinning));
    try testing.expectEqual(@as(usize, 4), codeUnitLength("A" ++ grinning ++ "B"));
    try testing.expectEqual(@as(usize, 1), codeUnitLength(hi_d83d));
    try testing.expectEqual(@as(usize, 1), codeUnitLength(lo_de00));
    // A pair held as its two three-byte surrogates (generalized WTF-8).
    try testing.expectEqual(@as(usize, 2), codeUnitLength(hi_d83d ++ lo_de00));
}

test "codeUnitLength agrees with a sequence-by-sequence count across block boundaries" {
    var buffer: [200]u8 = undefined;
    var units: [200]u16 = undefined;
    const samples = [_][]const u8{ "a", "\xC3\xA9", "\xE6\x97\xA5", grinning, hi_d83c, lo_df20 };
    // Every alignment of every kind of sequence against the 32-byte blocks.
    for (0..40) |lead| {
        for (samples) |sample| {
            var len: usize = 0;
            for (0..lead) |_| {
                buffer[len] = 'x';
                len += 1;
            }
            while (len + sample.len <= 120) {
                @memcpy(buffer[len..][0..sample.len], sample);
                len += sample.len;
            }
            const bytes = buffer[0..len];
            try testing.expectEqual(referenceUnits(bytes, &units), codeUnitLength(bytes));
        }
    }
}

test "positionOfCodeUnit finds code points and the middle of a pair" {
    const text = "A" ++ grinning ++ "B";
    try testing.expectEqual(Position{ .byte = 0 }, positionOfCodeUnit(text, 0));
    try testing.expectEqual(Position{ .byte = 1 }, positionOfCodeUnit(text, 1));
    try testing.expectEqual(Position{ .byte = 1, .mid_pair = true }, positionOfCodeUnit(text, 2));
    try testing.expectEqual(Position{ .byte = 5 }, positionOfCodeUnit(text, 3));
    try testing.expectEqual(Position{ .byte = 6 }, positionOfCodeUnit(text, 4));
    try testing.expectEqual(Position{ .byte = 6 }, positionOfCodeUnit(text, 9));
    // A lone surrogate is one code unit of three bytes.
    const lone = "x" ++ hi_d83d ++ "y";
    try testing.expectEqual(Position{ .byte = 4 }, positionOfCodeUnit(lone, 2));
}

test "positionOfCodeUnit agrees with a sequence-by-sequence walk across block boundaries" {
    var buffer: [200]u8 = undefined;
    const samples = [_][]const u8{ "\xC3\xA9", "\xE6\x97\xA5", grinning, lo_df20 };
    for (0..40) |lead| {
        for (samples) |sample| {
            var len: usize = 0;
            for (0..lead) |_| {
                buffer[len] = 'x';
                len += 1;
            }
            while (len + sample.len + 1 <= 150) {
                @memcpy(buffer[len..][0..sample.len], sample);
                len += sample.len;
                buffer[len] = 'y';
                len += 1;
            }
            const bytes = buffer[0..len];
            // Walk it: every code unit offset and the position it must have.
            var unit: usize = 0;
            var i: usize = 0;
            while (i < bytes.len) {
                const b = bytes[i];
                const width: usize = if (b < 0x80) 1 else if (b < 0xE0) 2 else if (b < 0xF0) 3 else 4;
                try testing.expectEqual(Position{ .byte = i }, positionOfCodeUnit(bytes, unit));
                if (width == 4) {
                    try testing.expectEqual(Position{ .byte = i, .mid_pair = true }, positionOfCodeUnit(bytes, unit + 1));
                    unit += 2;
                } else unit += 1;
                i += width;
            }
            try testing.expectEqual(Position{ .byte = bytes.len }, positionOfCodeUnit(bytes, unit));
        }
    }
}

test "substring splits a surrogate pair cut at either end (CharacterData-surrogates)" {
    const data = shooting_star ++ " test " ++ shooting_star ++ " TEST";
    const result = try substring(testing.allocator, data, 1, 9);
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, lo_df20 ++ " test " ++ hi_d83c, result);

    const low = try substring(testing.allocator, data, 1, 2);
    defer testing.allocator.free(low);
    try testing.expectEqualSlices(u8, lo_df20, low);

    const empty = try substring(testing.allocator, data, 1, 1);
    defer testing.allocator.free(empty);
    try testing.expectEqualSlices(u8, "", empty);

    const whole = try substring(testing.allocator, data, 0, 15);
    defer testing.allocator.free(whole);
    try testing.expectEqualSlices(u8, data, whole);
}

/// replace data's splice, by code-unit offset and count.
fn expectSplice(before: []const u8, offset: usize, count: usize, data: []const u8, expected: []const u8) !void {
    const result = try splice(testing.allocator, before, offset, offset + count, data);
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, expected, result);
    try testing.expectEqual(codeUnitLength(before) - count + codeUnitLength(data), codeUnitLength(result));
}

test "splice splits and joins surrogate pairs (CharacterData-surrogates replaceData)" {
    const start = shooting_star ++ " test " ++ shooting_star ++ " TEST";
    const step1 = hi_d83c ++ "--st " ++ shooting_star ++ " TEST";
    try expectSplice(start, 1, 4, "--", step1);
    const step2 = glowing_star ++ " st " ++ shooting_star ++ " TEST";
    try expectSplice(step1, 1, 2, lo_df1f ++ " ", step2);
    const step3 = glowing_star ++ " st---" ++ lo_df20 ++ " TEST";
    try expectSplice(step2, 5, 2, "---", step3);
    try expectSplice(step3, 6, 2, " " ++ hi_d83d, glowing_star ++ " st- " ++ alchemical ++ " TEST");
}

test "splice joins the halves a deletion brings together (CharacterData-surrogates deleteData)" {
    const start = shooting_star ++ " test " ++ shooting_star ++ " TEST";
    const step1 = hi_d83c ++ "st " ++ shooting_star ++ " TEST";
    try expectSplice(start, 1, 4, "", step1);
    try expectSplice(step1, 1, 4, "", shooting_star ++ " TEST");
}

test "splice inserts inside a pair and rejoins it (CharacterData-surrogates insertData)" {
    const start = shooting_star ++ " test " ++ shooting_star ++ " TEST";
    const step1 = hi_d83c ++ "--" ++ lo_df20 ++ " test " ++ shooting_star ++ " TEST";
    try expectSplice(start, 1, 0, "--", step1);
    const step2 = glowing_star ++ " --" ++ lo_df20 ++ " test " ++ shooting_star ++ " TEST";
    try expectSplice(step1, 1, 0, lo_df1f ++ " ", step2);
    try expectSplice(step2, 5, 0, " " ++ hi_d83d, glowing_star ++ " -- " ++ alchemical ++ " test " ++ shooting_star ++ " TEST");
    // Inserting nothing between the halves gives the pair back whole.
    try expectSplice(start, 1, 0, "", start);
}

test "splice joins an appended low surrogate to a lone high one" {
    try expectSplice(hi_d83d, 1, 0, lo_de00, grinning);
    try expectSplice(lo_de00, 0, 0, hi_d83d, grinning);
    // A lone high surrogate next to a lone high surrogate stays two.
    try expectSplice(hi_d83d, 1, 0, hi_d83c, hi_d83d ++ hi_d83c);
}

test "Pieces.joinedLength is exact when nothing joins" {
    var pieces: Pieces = .{};
    pieces.splice("hello", .{ .byte = 5 }, .{ .byte = 5 }, " world");
    try testing.expectEqual(@as(usize, 11), pieces.joinedLength());
    var out: [11]u8 = undefined;
    pieces.writeJoined(&out);
    try testing.expectEqualStrings("hello world", &out);
}

test "appendJoined joins a pair split across two pieces" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(testing.allocator);
    try appendJoined(testing.allocator, &list, "a" ++ hi_d83d);
    try appendJoined(testing.allocator, &list, lo_de00 ++ "b");
    try testing.expectEqualSlices(u8, "a" ++ grinning ++ "b", list.items);
    try appendJoined(testing.allocator, &list, lo_de00);
    try testing.expectEqualSlices(u8, "a" ++ grinning ++ "b" ++ lo_de00, list.items);
}
