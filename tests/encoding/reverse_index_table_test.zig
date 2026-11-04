//! The legacy CJK encoders' reverse indexes are computed at build time
//! (tools/encoding/reverse_index_table.zig) and embedded (lane compiletime1).
//! Until then src/encoding/reverse_index.zig built each one at compile time
//! with the radix sort below, copied here unchanged from it: each embedded
//! table must be exactly the order that sort makes.
//!
//! The sort runs at compile time, as it did - in this test binary only.
const std = @import("std");
const encoding = @import("encoding");
const reverse_index = encoding.reverse_index;

/// How many pointers of `index` have a code point.
fn mappedCount(comptime index: []const u21) usize {
    @setEvalBranchQuota(4 * index.len + 1_000);
    var n: usize = 0;
    for (index) |code_point| {
        if (code_point != 0) n += 1;
    }
    return n;
}

/// The pointers of `index` that have a code point, ordered by code point and,
/// for equal code points, by pointer: a least-significant-digit radix sort on
/// the 21-bit code point, two stable passes of 11 bits over the pointers in
/// pointer order. Linear in the index, so cheap at compile time.
fn orderOf(comptime index: []const u21) [mappedCount(index)]u16 {
    @setEvalBranchQuota(40 * index.len + 100_000);
    const n = comptime mappedCount(index);
    comptime {
        var by_pointer: [n]u16 = undefined;
        var k: usize = 0;
        for (index, 0..) |code_point, pointer| {
            if (code_point == 0) continue;
            by_pointer[k] = @intCast(pointer);
            k += 1;
        }
        const by_low_digit = radixPass(n, index, by_pointer, 0);
        return radixPass(n, index, by_low_digit, 11);
    }
}

/// One stable counting-sort pass of `pointers` on the 11-bit digit of their
/// code points at `shift`.
fn radixPass(comptime n: usize, comptime index: []const u21, comptime pointers: [n]u16, comptime shift: u5) [n]u16 {
    comptime {
        var starts: [2049]usize = @splat(0);
        for (pointers) |pointer| starts[((index[pointer] >> shift) & 0x7FF) + 1] += 1;
        for (1..starts.len) |i| starts[i] += starts[i - 1];
        var sorted: [n]u16 = undefined;
        for (pointers) |pointer| {
            const digit = (index[pointer] >> shift) & 0x7FF;
            sorted[starts[digit]] = pointer;
            starts[digit] += 1;
        }
        return sorted;
    }
}

fn expectTableIsTheComptimeOrder(comptime table: *const reverse_index.ReverseIndex) !void {
    const expected = comptime orderOf(table.index);
    try std.testing.expectEqual(expected.len, table.len());
    for (expected, 0..) |pointer, i| try std.testing.expectEqual(pointer, table.pointerAt(i));
}

test "every embedded reverse index is the order the compile-time sort made" {
    try expectTableIsTheComptimeOrder(&reverse_index.jis0208);
    try expectTableIsTheComptimeOrder(&reverse_index.jis0212);
    try expectTableIsTheComptimeOrder(&reverse_index.big5);
    try expectTableIsTheComptimeOrder(&reverse_index.gb18030);
    try expectTableIsTheComptimeOrder(&reverse_index.euc_kr);
}
