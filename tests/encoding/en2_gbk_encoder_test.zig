//! GBK shares gb18030's encoder with the restricted output flag enabled.
const std = @import("std");
const encoding = @import("encoding");
const testing = std.testing;

test "GBK encodes euro as 80 and HTML mode replaces unmappable scalars" {
    const cases = .{
        .{ "€", "\x80" },
        .{ "💩", "&#128169;" },
        .{ "\u{e7c8}", "&#59336;" },
        .{ "¥", "&#165;" },
        .{ "⋯", "&#8943;" },
        .{ "〜", "&#12316;" },
        .{ "\u{10ffff}", "&#1114111;" },
    };
    inline for (cases) |case| {
        const units = try std.unicode.utf8ToUtf16LeAlloc(testing.allocator, case[0]);
        defer testing.allocator.free(units);
        for (units) |*unit| unit.* = std.mem.littleToNative(u16, unit.*);
        const bytes = try encoding.hooks.encode(testing.allocator, units, &encoding.encoding.GBK);
        defer testing.allocator.free(bytes);
        try testing.expectEqualStrings(case[1], bytes);
    }
}

test "GBK restriction does not restrict gb18030 output" {
    const bytes = try encoding.hooks.encode(testing.allocator, &.{0x20ac}, &encoding.encoding.GB18030);
    defer testing.allocator.free(bytes);
    try testing.expectEqualStrings("\xa2\xe3", bytes);
}
