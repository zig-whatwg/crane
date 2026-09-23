//! WebIDL § 3.2.4 "ConvertToInt", the integer conversion every `short`,
//! `unsigned short`, `long` ... argument goes through when it carries neither
//! [EnforceRange] nor [Clamp].
//!
//! The binding used to `@intFromFloat` the number and throw RangeError when it
//! did not fit. `@intFromFloat` of NaN, an infinity or anything past the target
//! range is safety-checked illegal behaviour, so
//! `range.compareBoundaryPoints(-1, r)` - `how` is an `unsigned short` -
//! panicked the whole process (dom/ranges/Range-compareBoundaryPoints.html).
//! The spec never throws here: it truncates and wraps.

const std = @import("std");
const v8 = @import("v8");

const convertToInt = v8.conversions.convertToInt;

test "NaN, infinities and zeros convert to 0 (step 6)" {
    try std.testing.expectEqual(@as(u16, 0), convertToInt(u16, std.math.nan(f64)));
    try std.testing.expectEqual(@as(u16, 0), convertToInt(u16, std.math.inf(f64)));
    try std.testing.expectEqual(@as(i32, 0), convertToInt(i32, -std.math.inf(f64)));
    try std.testing.expectEqual(@as(i8, 0), convertToInt(i8, -0.0));
}

test "values are truncated toward zero (step 7)" {
    try std.testing.expectEqual(@as(u16, 3), convertToInt(u16, 3.9));
    try std.testing.expectEqual(@as(i16, -3), convertToInt(i16, -3.9));
}

test "unsigned types wrap modulo 2^n (steps 8 and 9)" {
    try std.testing.expectEqual(@as(u16, 65535), convertToInt(u16, -1));
    try std.testing.expectEqual(@as(u16, 0), convertToInt(u16, 65536));
    try std.testing.expectEqual(@as(u16, 1), convertToInt(u16, 65537));
    try std.testing.expectEqual(@as(u32, 4294967295), convertToInt(u32, -1));
    try std.testing.expectEqual(@as(u8, 0), convertToInt(u8, 1e300));
}

test "signed types wrap into [-2^(n-1), 2^(n-1)) (step 10)" {
    try std.testing.expectEqual(@as(i16, -1), convertToInt(i16, 65535));
    try std.testing.expectEqual(@as(i16, -32768), convertToInt(i16, 32768));
    try std.testing.expectEqual(@as(i32, -2147483648), convertToInt(i32, 2147483648));
    try std.testing.expectEqual(@as(i8, 127), convertToInt(i8, 127));
}

test "64-bit types keep the exact double" {
    try std.testing.expectEqual(@as(u64, 18446744073709549568), convertToInt(u64, -2048));
    try std.testing.expectEqual(@as(i64, -9007199254740991), convertToInt(i64, -9007199254740991));
}
