//! WebIDL 3.2.4 ConvertToInt with [EnforceRange], after ToNumber.

const std = @import("std");

/// WebCrypto dictionaries use unsigned octet, unsigned short, and unsigned long.
pub fn enforceRange(comptime T: type, number: f64) error{TypeError}!T {
    comptime std.debug.assert(T == u8 or T == u16 or T == u32);
    // Steps 2 and 4: unsigned bounds; the caller has already done ToNumber.
    const upper: f64 = @floatFromInt(std.math.maxInt(T));
    // Steps 5, 6.1-6.4: reject nonfinite, take IntegerPart, then check range.
    if (!std.math.isFinite(number)) return error.TypeError;
    const integer = @trunc(number);
    if (integer < 0 or integer > upper) return error.TypeError;
    return @intFromFloat(integer);
}

test "EnforceRange truncates toward zero, including negative zero" {
    try std.testing.expectEqual(@as(u8, 0), try enforceRange(u8, -0.9));
    try std.testing.expectEqual(@as(u8, 0), try enforceRange(u8, -0.0));
    try std.testing.expectEqual(@as(u8, 255), try enforceRange(u8, 255.999));
    try std.testing.expectEqual(@as(u16, 65535), try enforceRange(u16, 65535.75));
    try std.testing.expectEqual(@as(u32, 4294967295), try enforceRange(u32, 4294967295.75));
}

test "EnforceRange rejects nonfinite and out-of-range input instead of wrapping" {
    for ([_]f64{ std.math.nan(f64), std.math.inf(f64), -std.math.inf(f64), -1, 256 }) |number| {
        try std.testing.expectError(error.TypeError, enforceRange(u8, number));
    }
    try std.testing.expectError(error.TypeError, enforceRange(u16, 65536));
    try std.testing.expectError(error.TypeError, enforceRange(u32, 4294967296));
}
