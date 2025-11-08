//! Comptime Index Generator
//!
//! Parses WHATWG index files at compile time and generates efficient lookup tables.
//!
//! Index file format (tab-separated):
//!   pointer<TAB>code_point
//!   0<TAB>0x0410
//!   1<TAB>0x0411
//!
//! Lines starting with # are comments and are ignored.

const std = @import("std");

/// Single-byte encoding index: maps pointer (0-127) to Unicode code point
///
/// Null entries (0xFFFF) indicate unmapped pointers.
pub const Index = struct {
    /// Code points for pointers 0-127
    /// Unmapped pointers are represented as 0xFFFF
    map: [128]u21,
};

/// Parse a WHATWG index file at comptime.
///
/// Returns an Index with 128 entries (pointers 0-127 → code points).
/// Unmapped pointers are set to 0xFFFF.
pub fn parseIndex(comptime content: []const u8) Index {
    var index = Index{ .map = [_]u21{0xFFFF} ** 128 };

    var line_iter = std.mem.splitScalar(u8, content, '\n');
    while (line_iter.next()) |line| {
        // Skip empty lines
        if (line.len == 0) continue;

        // Skip comments
        if (line[0] == '#') continue;

        // Parse line: pointer<TAB>code_point
        var parts = std.mem.splitScalar(u8, line, '\t');

        // Get pointer
        const pointer_str = parts.next() orelse continue;
        const pointer = std.fmt.parseInt(u8, pointer_str, 10) catch continue;

        // Get code point (hex with 0x prefix)
        const code_point_str = parts.next() orelse continue;
        if (code_point_str.len < 3) continue; // Need at least "0xX"
        if (code_point_str[0] != '0' or code_point_str[1] != 'x') continue;

        const code_point = std.fmt.parseInt(u21, code_point_str[2..], 16) catch continue;

        // Store in index
        if (pointer < 128) {
            index.map[pointer] = code_point;
        }
    }

    return index;
}

/// Get code point for a given pointer.
///
/// Returns null if the pointer is not mapped in this index.
pub fn getCodePoint(index: *const Index, pointer: u8) ?u21 {
    if (pointer >= 128) return null;
    const cp = index.map[pointer];
    if (cp == 0xFFFF) return null;
    return cp;
}

/// Get pointer for a given code point.
///
/// Returns null if the code point is not in this index.
/// This is a linear search - suitable for encoding (less common operation).
pub fn getPointer(index: *const Index, code_point: u21) ?u8 {
    for (index.map, 0..) |cp, pointer| {
        if (cp == code_point) {
            return @intCast(pointer);
        }
    }
    return null;
}

// Tests

test "parseIndex - IBM866" {
    const content = "# Comment line\n0\t0x0410\n1\t0x0411\n2\t0x0412\n127\t0x00A0\n";

    const index = parseIndex(content);

    try std.testing.expectEqual(@as(u21, 0x0410), index.map[0]);
    try std.testing.expectEqual(@as(u21, 0x0411), index.map[1]);
    try std.testing.expectEqual(@as(u21, 0x0412), index.map[2]);
    try std.testing.expectEqual(@as(u21, 0x00A0), index.map[127]);

    // Unmapped entries should be 0xFFFF
    try std.testing.expectEqual(@as(u21, 0xFFFF), index.map[3]);
}

test "getCodePoint" {
    const content = "0\t0x0410\n1\t0x0411\n";

    const index = parseIndex(content);

    try std.testing.expectEqual(@as(u21, 0x0410), getCodePoint(&index, 0).?);
    try std.testing.expectEqual(@as(u21, 0x0411), getCodePoint(&index, 1).?);
    try std.testing.expect(getCodePoint(&index, 2) == null);
    try std.testing.expect(getCodePoint(&index, 128) == null);
}

test "getPointer" {
    const content = "0\t0x0410\n1\t0x0411\n5\t0x0415\n";

    const index = parseIndex(content);

    try std.testing.expectEqual(@as(u8, 0), getPointer(&index, 0x0410).?);
    try std.testing.expectEqual(@as(u8, 1), getPointer(&index, 0x0411).?);
    try std.testing.expectEqual(@as(u8, 5), getPointer(&index, 0x0415).?);
    try std.testing.expect(getPointer(&index, 0x9999) == null);
}
