//! Names exposed by TextDecoder are the ASCII-lowercase canonical names.
const std = @import("std");
const encoding = @import("encoding");

test "multibyte encoding labels expose an ASCII-lowercase name for TextDecoder" {
    const labels = [_][]const u8{ "UTF-8", "Big5", "utf-16", "UTF-16LE", "UTF-16BE", "GBK", "EUC-JP", "EUC-KR", "ISO-2022-JP", "Shift_JIS" };
    for (labels) |label| {
        const enc = encoding.getEncoding(label).?;
        const lower = try std.ascii.allocLowerString(std.testing.allocator, enc.name);
        defer std.testing.allocator.free(lower);
        try std.testing.expectEqualStrings(lower, enc.whatwg_name);
    }
}
