//! Form encoding keeps the canonical name and complete stateful output.
const std = @import("std");
const encoding = @import("encoding");
const testing = std.testing;

test "ISO-2022-JP uses its canonical name in the form charset entry" {
    try testing.expectEqualStrings("ISO-2022-JP", encoding.encoding.ISO_2022_JP.name);
}

test "HTML encoding emits a complete JIS designation before the first character" {
    const units = try std.unicode.utf8ToUtf16LeAlloc(testing.allocator, "★星★.txt");
    defer testing.allocator.free(units);
    const bytes = try encoding.hooks.encode(testing.allocator, units, &encoding.encoding.ISO_2022_JP);
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("\x1b$B!z@1!z\x1b(B.txt", bytes);
}

test "ISO-2022-JP retries a designation without committing it when output is full" {
    var encoder = encoding.encoding.ISO_2022_JP.newEncoder().?;
    var small: [4]u8 = undefined;
    const first = encoder.encode(&.{0x2605}, &small, false);
    try testing.expectEqual(.output_full, first.status);
    try testing.expectEqual(@as(usize, 0), first.code_units_consumed);
    var enough: [8]u8 = undefined;
    const retried = encoder.encode(&.{0x2605}, &enough, false);
    try testing.expectEqual(.input_empty, retried.status);
    try testing.expectEqualStrings("\x1b$B!z", enough[0..retried.bytes_written]);
}

test "HTML encoding flushes once and preserves the escape preceding a numeric reference" {
    const units = [_]u16{ 0x661f, 0xd83c, 0xdf1f, 0x2605 };
    const bytes = try encoding.hooks.encode(testing.allocator, &units, &encoding.encoding.ISO_2022_JP);
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("\x1b$B@1\x1b(B&#127775;\x1b$B!z\x1b(B", bytes);
}

test "HTML encoding uses the handler's error code point for ISO-2022-JP escape controls" {
    const bytes = try encoding.hooks.encode(testing.allocator, &.{ 'a', 0x1b, 'b' }, &encoding.encoding.ISO_2022_JP);
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("a&#65533;b", bytes);
}
