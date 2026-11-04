//! Reverse indexes for the legacy CJK encoders: code point -> pointer, in
//! O(log n) instead of a scan of the forward index (code_point = INDEX[pointer]).
//!
//! Encoding Standard "index pointer": the FIRST pointer for a code point in an
//! index; "index Shift_JIS pointer" and "index Big5 pointer" exclude a range
//! of pointers first. Each reverse index lists every pointer of its forward
//! index that has a code point, ordered by code point and - for a code point
//! with several pointers - by pointer, so the first match is the first pointer.
//!
//! Every reverse index is a constant: no lazy build, no initialisation flag,
//! no allocation, nothing two threads could race on. They were five
//! process-wide `var`s built on first use behind atomic flags, where two
//! threads' first lookups both built and both wrote the index while a third
//! read it (lane gstate4). A table is two bytes per mapped pointer (the
//! pointer, little-endian; its code point is read from the forward index),
//! about 170 KB for all five.
//!
//! The tables are computed once, at build time, by
//! tools/encoding/reverse_index_table.zig and embedded here (`@embedFile` of
//! the step's output; lane compiletime1). A radix sort used to build them at
//! compile time in every binary that reached this file - 7 s of
//! single-threaded Sema in each test binary - and
//! tests/encoding/reverse_index_table_test.zig proves the embedded tables are
//! that sort's result.
//!
//! Usage:
//!   const ptr = reverse_index.findEucKrPointer(0xAC00);

const std = @import("std");

// Import forward indexes
const jis0208_index = @import("japanese/jis0208_index.zig");
const jis0212_index = @import("japanese/jis0212_index.zig");
const big5_index = @import("chinese/big5_index.zig");
const gb18030_index = @import("chinese/gb18030_index.zig");
const euc_kr_index = @import("korean/euc_kr_index.zig");

/// A reverse index: the pointers of `index` that have a code point, ordered
/// by code point, equal code points by pointer.
pub const ReverseIndex = struct {
    /// The forward index: pointer -> code point (0: no code point).
    index: []const u21,
    /// Every pointer of `index` with a code point, in code point order: two
    /// bytes each, little-endian (the build step's table).
    order: []const u8,

    /// How many pointers the table lists.
    pub fn len(self: *const ReverseIndex) usize {
        return self.order.len / 2;
    }

    /// The table's `i`th pointer.
    pub fn pointerAt(self: *const ReverseIndex, i: usize) u16 {
        return std.mem.readInt(u16, self.order[i * 2 ..][0..2], .little);
    }

    fn codePointAt(self: *const ReverseIndex, i: usize) u21 {
        return self.index[self.pointerAt(i)];
    }

    /// The position of the first entry whose code point is not below
    /// `code_point`.
    fn lowerBound(self: *const ReverseIndex, code_point: u21) usize {
        var left: usize = 0;
        var right: usize = self.len();
        while (left < right) {
            const mid = left + (right - left) / 2;
            if (self.codePointAt(mid) < code_point) left = mid + 1 else right = mid;
        }
        return left;
    }

    /// The position after the last entry whose code point is not above
    /// `code_point`.
    fn upperBound(self: *const ReverseIndex, code_point: u21) usize {
        var left: usize = 0;
        var right: usize = self.len();
        while (left < right) {
            const mid = left + (right - left) / 2;
            if (self.codePointAt(mid) <= code_point) left = mid + 1 else right = mid;
        }
        return left;
    }

    /// The FIRST pointer for `code_point` ("index pointer").
    pub fn findPointer(self: *const ReverseIndex, code_point: u21) ?u16 {
        const i = self.lowerBound(code_point);
        if (i < self.len() and self.codePointAt(i) == code_point) return self.pointerAt(i);
        return null;
    }

    /// The LAST pointer for `code_point`.
    pub fn findLastPointer(self: *const ReverseIndex, code_point: u21) ?u16 {
        const i = self.upperBound(code_point);
        if (i > 0 and self.codePointAt(i - 1) == code_point) return self.pointerAt(i - 1);
        return null;
    }

    /// The first pointer for `code_point` that is at least `min_pointer`
    /// (Big5's exclusion of the pointers below 5024).
    pub fn findPointerAbove(self: *const ReverseIndex, code_point: u21, min_pointer: u16) ?u16 {
        var i = self.lowerBound(code_point);
        while (i < self.len() and self.codePointAt(i) == code_point) : (i += 1) {
            if (self.pointerAt(i) >= min_pointer) return self.pointerAt(i);
        }
        return null;
    }

    /// The first pointer for `code_point` outside `[exclude_min, exclude_max]`
    /// (Shift_JIS's "index Shift_JIS pointer").
    pub fn findPointerOutside(self: *const ReverseIndex, code_point: u21, exclude_min: u16, exclude_max: u16) ?u16 {
        var i = self.lowerBound(code_point);
        while (i < self.len() and self.codePointAt(i) == code_point) : (i += 1) {
            const pointer = self.pointerAt(i);
            if (pointer < exclude_min or pointer > exclude_max) return pointer;
        }
        return null;
    }

    /// The last pointer for `code_point` that is at least `min_pointer`: a
    /// code point's pointers are in ascending order, so it is the last one
    /// when that one qualifies.
    pub fn findLastPointerAbove(self: *const ReverseIndex, code_point: u21, min_pointer: u16) ?u16 {
        const last = self.findLastPointer(code_point) orelse return null;
        return if (last >= min_pointer) last else null;
    }
};

// The build step's tables, by the anonymous import names build.zig gives
// them (`addGeneratedTables`).
const jis0208_order = @embedFile("reverse_index_jis0208");
const jis0212_order = @embedFile("reverse_index_jis0212");
const big5_order = @embedFile("reverse_index_big5");
const gb18030_order = @embedFile("reverse_index_gb18030");
const euc_kr_order = @embedFile("reverse_index_euc_kr");

/// Index jis0208, reversed.
pub const jis0208: ReverseIndex = .{ .index = &jis0208_index.INDEX, .order = jis0208_order };
/// Index jis0212, reversed.
pub const jis0212: ReverseIndex = .{ .index = &jis0212_index.INDEX, .order = jis0212_order };
/// Index Big5, reversed.
pub const big5: ReverseIndex = .{ .index = &big5_index.INDEX, .order = big5_order };
/// Index gb18030, reversed.
pub const gb18030: ReverseIndex = .{ .index = &gb18030_index.INDEX, .order = gb18030_order };
/// Index EUC-KR, reversed.
pub const euc_kr: ReverseIndex = .{ .index = &euc_kr_index.INDEX, .order = euc_kr_order };

// ============================================================================
// Lookups
// ============================================================================

/// Find JIS X 0208 pointer for code point
pub fn findJis0208Pointer(code_point: u21) ?u16 {
    return jis0208.findPointer(code_point);
}

/// Encoding § 13.3 "index Shift_JIS pointer": the index pointer for
/// `code_point` in index jis0208 excluding the entries whose pointer is in the
/// range 8272 to 8835 - the NEC-selected IBM extensions, which Shift_JIS
/// encodes from their IBM extension duplicates (10716 on) instead.
pub fn findShiftJisPointer(code_point: u21) ?u16 {
    return jis0208.findPointerOutside(code_point, 8272, 8835);
}

/// Find JIS X 0212 pointer for code point
pub fn findJis0212Pointer(code_point: u21) ?u16 {
    return jis0212.findPointer(code_point);
}

/// Find Big5 pointer for code point (first occurrence)
pub fn findBig5Pointer(code_point: u21) ?u16 {
    return big5.findPointer(code_point);
}

/// Find Big5 pointer above minimum (for special ranges)
pub fn findBig5PointerAbove(code_point: u21, min_pointer: u16) ?u16 {
    return big5.findPointerAbove(code_point, min_pointer);
}

/// Find GB18030 pointer for code point
pub fn findGb18030Pointer(code_point: u21) ?u16 {
    return gb18030.findPointer(code_point);
}

/// Find EUC-KR pointer for code point
pub fn findEucKrPointer(code_point: u21) ?u16 {
    return euc_kr.findPointer(code_point);
}

// ============================================================================
// Tests
// ============================================================================

/// What a scan of `index` answers: the first and the last pointer of every
/// code point, checked against `reverse` for each mapped pointer.
fn expectMatchesScan(reverse: *const ReverseIndex, index: []const u21) !void {
    const testing = std.testing;
    var first: std.AutoHashMapUnmanaged(u21, u16) = .empty;
    defer first.deinit(testing.allocator);
    var last: std.AutoHashMapUnmanaged(u21, u16) = .empty;
    defer last.deinit(testing.allocator);
    for (index, 0..) |code_point, pointer| {
        if (code_point == 0) continue;
        const gop = try first.getOrPut(testing.allocator, code_point);
        if (!gop.found_existing) gop.value_ptr.* = @intCast(pointer);
        try last.put(testing.allocator, code_point, @intCast(pointer));
    }
    var mapped: usize = 0;
    for (index) |code_point| {
        if (code_point != 0) mapped += 1;
    }
    try testing.expectEqual(mapped, reverse.len());
    var it = first.iterator();
    while (it.next()) |entry| {
        try testing.expectEqual(@as(?u16, entry.value_ptr.*), reverse.findPointer(entry.key_ptr.*));
        try testing.expectEqual(@as(?u16, last.get(entry.key_ptr.*).?), reverse.findLastPointer(entry.key_ptr.*));
    }
    // A code point no pointer maps.
    try testing.expectEqual(@as(?u16, null), reverse.findPointer(0x0001));
    try testing.expectEqual(@as(?u16, null), reverse.findLastPointer(0x0001));
}

test "every reverse index answers the first and last pointer a scan of its forward index finds" {
    try expectMatchesScan(&jis0208, &jis0208_index.INDEX);
    try expectMatchesScan(&jis0212, &jis0212_index.INDEX);
    try expectMatchesScan(&big5, &big5_index.INDEX);
    try expectMatchesScan(&gb18030, &gb18030_index.INDEX);
    try expectMatchesScan(&euc_kr, &euc_kr_index.INDEX);
}

test "reverse index lookups" {
    const testing = std.testing;
    // Ideographic space is jis0208's pointer 0.
    try testing.expectEqual(@as(?u16, 0), findJis0208Pointer(0x3000));
    const hiragana_a = findJis0208Pointer(0x3042).?;
    try testing.expectEqual(@as(u21, 0x3042), jis0208_index.INDEX[hiragana_a]);
    try testing.expect(findEucKrPointer(0xAC00) != null);
    try testing.expect(findBig5PointerAbove(0x3000, 0) != null);
    const zhong = findGb18030Pointer(0x4E2D).?;
    try testing.expectEqual(@as(u21, 0x4E2D), gb18030_index.INDEX[zhong]);
}

test "the Shift_JIS and Big5 exclusions skip the excluded pointers" {
    const testing = std.testing;
    // A code point among the NEC-selected IBM extensions (8272-8835) that
    // also has a pointer outside them: Shift_JIS takes the first outside.
    for (jis0208_index.INDEX, 0..) |code_point, pointer| {
        if (code_point == 0) continue;
        const outside = findShiftJisPointer(code_point);
        if (outside) |p| {
            try testing.expect(p < 8272 or p > 8835);
            try testing.expectEqual(code_point, jis0208_index.INDEX[p]);
        } else {
            try testing.expect(pointer >= 8272 and pointer <= 8835);
        }
    }
    // Big5: the first pointer at or above 5024, when there is one.
    for (big5_index.INDEX) |code_point| {
        if (code_point == 0) continue;
        if (findBig5PointerAbove(code_point, 5024)) |p| try testing.expect(p >= 5024);
        const last = big5.findLastPointer(code_point).?;
        try testing.expectEqual(if (last >= 5024) @as(?u16, last) else null, big5.findLastPointerAbove(code_point, 5024));
    }
}
