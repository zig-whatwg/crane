//! chrome-devtools-mcp's text helpers (src/utils/text.ts at
//! chrome-devtools-mcp-v1.13.0, Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md), translated. Lengths are JavaScript's: UTF-16
//! code units, so a character outside the BMP counts two and is never cut in
//! half (StringUtilities.truncateToCodeUnitLength).

const std = @import("std");
const Allocator = std.mem.Allocator;

/// String.prototype.length of UTF-8 `text` (invalid UTF-8: its bytes).
pub fn codeUnits(text: []const u8) usize {
    const view = std.unicode.Utf8View.init(text) catch return text.len;
    var it = view.iterator();
    var units: usize = 0;
    while (it.nextCodepoint()) |cp| units += if (cp >= 0x10000) 2 else 1;
    return units;
}

/// The longest prefix of `text` of at most `max` code units that does not
/// split a surrogate pair.
fn prefixUnits(text: []const u8, max: usize) []const u8 {
    const view = std.unicode.Utf8View.init(text) catch return text[0..@min(max, text.len)];
    var it = view.iterator();
    var units: usize = 0;
    var end: usize = 0;
    while (it.nextCodepointSlice()) |slice| {
        const cp = std.unicode.utf8Decode(slice) catch 0;
        const width: usize = if (cp >= 0x10000) 2 else 1;
        if (units + width > max) break;
        units += width;
        end = it.i;
    }
    return text[0..end];
}

pub const TruncateOptions = struct {
    ellipsis: []const u8 = "...",
    include_ellipsis_in_length: bool = false,
};

/// truncateText.
pub fn truncateText(arena: Allocator, text: []const u8, max: usize, options: TruncateOptions) ![]const u8 {
    if (codeUnits(text) <= max) return text;
    const keep = if (options.include_ellipsis_in_length) max -| codeUnits(options.ellipsis) else max;
    return std.fmt.allocPrint(arena, "{s}{s}", .{ prefixUnits(text, keep), options.ellipsis });
}

/// ECMAScript WhiteSpace and LineTerminator: what a regular expression's
/// \s matches.
pub fn isJsSpace(cp: u21) bool {
    return switch (cp) {
        0x09...0x0d, 0x20, 0xa0, 0x1680, 0x2000...0x200a, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff => true,
        else => false,
    };
}

/// URL_SIZE_LIMIT.
const url_size_limit = 255;

/// truncateUrl.
pub fn truncateUrl(arena: Allocator, url: []const u8) ![]const u8 {
    return truncateText(arena, url, url_size_limit, .{ .ellipsis = "... <truncated>" });
}

test "truncateText counts UTF-16 code units and never splits a pair" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    try std.testing.expectEqualStrings("abcdef", try truncateText(arena, "abcdef", 6, .{}));
    try std.testing.expectEqualStrings("ab...", try truncateText(arena, "abcdef", 5, .{ .include_ellipsis_in_length = true }));
    try std.testing.expectEqualStrings("abcde...", try truncateText(arena, "abcdef", 5, .{}));
    // U+1F600 is two code units: a cut inside it drops it.
    try std.testing.expectEqualStrings("a...", try truncateText(arena, "a\u{1F600}bc", 2, .{}));
}
