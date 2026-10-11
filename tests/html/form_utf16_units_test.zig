//! The text-control helpers measure a value in UTF-16 code units (HTML
//! 4.10.18.2 maxlength, 4.10.20 the selection APIs), over the value's WTF-8
//! bytes - a lone surrogate included, which is one code unit in three bytes.
const std = @import("std");
const testing = std.testing;
const form_associated = @import("html").form_associated;

const lone_high = "\xED\xA0\x80"; // U+D800
const lone_low = "\xED\xB0\x80"; // U+DC00
const grinning = "\xF0\x9F\x98\x80"; // U+1F600, a pair

test "utf16Length counts a lone surrogate as one code unit" {
    try testing.expectEqual(@as(u32, 3), form_associated.utf16Length("a" ++ lone_high ++ "b"));
    try testing.expectEqual(@as(u32, 2), form_associated.utf16Length(lone_low ++ lone_high));
    try testing.expectEqual(@as(u32, 4), form_associated.utf16Length("a" ++ grinning ++ "b"));
    try testing.expectEqual(@as(u32, 0), form_associated.utf16Length(""));
}

test "byteOffsetOfUtf16 steps over a lone surrogate and rounds down inside a pair" {
    const text = "a" ++ lone_high ++ grinning ++ "b";
    try testing.expectEqual(@as(usize, 1), form_associated.byteOffsetOfUtf16(text, 1));
    try testing.expectEqual(@as(usize, 4), form_associated.byteOffsetOfUtf16(text, 2));
    try testing.expectEqual(@as(usize, 4), form_associated.byteOffsetOfUtf16(text, 3));
    try testing.expectEqual(@as(usize, 8), form_associated.byteOffsetOfUtf16(text, 4));
    try testing.expectEqual(@as(usize, 9), form_associated.byteOffsetOfUtf16(text, 5));
}

test "maxlength room: a value holding a lone surrogate leaves room for the rest" {
    // user_input.insertText's arithmetic: maxlength 3, value "a<U+D800>"
    // (two code units, four bytes), nothing selected - one code unit of
    // room, so typing "bc" inserts "b".
    const value = "a" ++ lone_high;
    const max: u32 = 3;
    const kept = form_associated.utf16Length(value);
    try testing.expectEqual(@as(u32, 2), kept);
    const room = max - kept;
    const typed = "bc";
    const cut = typed[0..form_associated.byteOffsetOfUtf16(typed, room)];
    try testing.expectEqualStrings("b", cut);
}

test "setRangeText clamps to the length in code units around a lone surrogate" {
    // The value is three code units in five bytes: a range past its end is
    // clamped to 3 (steps 5-6), and the selection follows the insertion.
    const result = try form_associated.setRangeText(testing.allocator, "a" ++ lone_high ++ "b", .{ .start = 3, .end = 3 }, "c", .{ 5, 5 }, .select);
    defer testing.allocator.free(result.value);
    try testing.expectEqualSlices(u8, "a" ++ lone_high ++ "bc", result.value);
    try testing.expectEqual(@as(u32, 3), result.selection_start);
    try testing.expectEqual(@as(u32, 4), result.selection_end);
}
