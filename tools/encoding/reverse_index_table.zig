//! Build step: the legacy CJK encoders' reverse indexes, computed once and
//! embedded (lane compiletime1, 2026-11-04).
//!
//! src/encoding/reverse_index.zig built each of its five tables at compile
//! time - a radix sort of the forward index under a large branch quota - in
//! every binary that reached src/encoding: gb18030 2.6 s, EUC-KR 1.9 s, Big5
//! 1.9 s and jis0208 0.7 s of single-threaded Sema in tests-dom alone (lane
//! onebin2's time report). build.zig runs this tool once instead (Zig caches
//! its output while the forward indexes, compiled into it, are unchanged) and
//! reverse_index.zig @embedFile's each table.
//!
//! A table lists every pointer of its forward index that has a code point,
//! ordered by code point and - for a code point with several pointers - by
//! pointer: the order the comptime sort made (tests/encoding/
//! reverse_index_table_test.zig compares the two). Each pointer is two bytes,
//! little-endian.
//!
//!   reverse_index_table <jis0208.bin> <jis0212.bin> <big5.bin> <gb18030.bin> <euc_kr.bin>

const std = @import("std");
const Allocator = std.mem.Allocator;

/// The tables, in the order main takes their output paths.
pub const names = [_][]const u8{ "jis0208", "jis0212", "big5", "gb18030", "euc_kr" };

/// The pointers of `index` that have a code point (0 is "no code point"),
/// ordered by code point, equal code points by pointer.
pub fn order(allocator: Allocator, index: []const u21) Allocator.Error![]u16 {
    var pointers: std.ArrayList(u16) = .empty;
    errdefer pointers.deinit(allocator);
    for (index, 0..) |code_point, pointer| {
        if (code_point != 0) try pointers.append(allocator, @intCast(pointer));
    }
    // A stable sort of pointers listed in pointer order: equal code points
    // keep pointer order.
    std.mem.sort(u16, pointers.items, index, byCodePoint);
    return pointers.toOwnedSlice(allocator);
}

fn byCodePoint(index: []const u21, a: u16, b: u16) bool {
    return index[a] < index[b];
}

/// `pointers` as the embedded table: two bytes each, little-endian.
pub fn encode(allocator: Allocator, pointers: []const u16) Allocator.Error![]u8 {
    const bytes = try allocator.alloc(u8, pointers.len * 2);
    for (pointers, 0..) |pointer, i| std.mem.writeInt(u16, bytes[i * 2 ..][0..2], pointer, .little);
    return bytes;
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    // The forward indexes, by the module names build.zig gives them.
    const indexes = [names.len][]const u21{
        &@import("jis0208_index").INDEX,
        &@import("jis0212_index").INDEX,
        &@import("big5_index").INDEX,
        &@import("gb18030_index").INDEX,
        &@import("euc_kr_index").INDEX,
    };
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != names.len + 1) {
        std.debug.print("usage: reverse_index_table <jis0208.bin> <jis0212.bin> <big5.bin> <gb18030.bin> <euc_kr.bin>\n", .{});
        std.process.exit(2);
    }
    for (indexes, args[1..]) |index, path| {
        const bytes = try encode(arena, try order(arena, index));
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes });
    }
}

const testing = std.testing;

test "a table lists the mapped pointers by code point, equal code points in pointer order" {
    // pointer:            0  1  2  3  4  5
    const index = [_]u21{ 0, 5, 3, 5, 0, 1 };
    const pointers = try order(testing.allocator, &index);
    defer testing.allocator.free(pointers);
    try testing.expectEqualSlices(u16, &.{ 5, 2, 1, 3 }, pointers);
}

test "equal code points keep pointer order however many there are" {
    var index: [600]u21 = undefined;
    for (&index, 0..) |*code_point, pointer| code_point.* = @intCast(0x4E00 + (pointer % 3));
    const pointers = try order(testing.allocator, &index);
    defer testing.allocator.free(pointers);
    try testing.expectEqual(@as(usize, 600), pointers.len);
    for (pointers[1..], pointers[0 .. pointers.len - 1]) |after, before| {
        try testing.expect(index[before] < index[after] or (index[before] == index[after] and before < after));
    }
}

test "the embedded table is two bytes per pointer, little-endian" {
    const bytes = try encode(testing.allocator, &.{ 0x0102, 0xFFFE, 0 });
    defer testing.allocator.free(bytes);
    try testing.expectEqualSlices(u8, &.{ 0x02, 0x01, 0xFE, 0xFF, 0, 0 }, bytes);
}
