//! A worker's setTimeout(), setInterval(), clearTimeout() and
//! clearInterval() convert their `long` arguments as WebIDL does
//! (ConvertToInt(V, 32, "signed"), after ToNumber): the integer part modulo
//! 2^32, read as two's complement - the same answer a Window's timers get
//! from the engine's ToInt32. Pure arithmetic: no engine, no worker.

const std = @import("std");
const testing = std.testing;
const convertToLong = @import("html").worker_host.convertToLong;

test "NaN, the infinities and zero convert to 0" {
    try testing.expectEqual(@as(i32, 0), convertToLong(std.math.nan(f64)));
    try testing.expectEqual(@as(i32, 0), convertToLong(std.math.inf(f64)));
    try testing.expectEqual(@as(i32, 0), convertToLong(-std.math.inf(f64)));
    try testing.expectEqual(@as(i32, 0), convertToLong(0.0));
    try testing.expectEqual(@as(i32, 0), convertToLong(-0.0));
}

test "the integer part is taken, toward zero" {
    try testing.expectEqual(@as(i32, 5), convertToLong(5.9));
    try testing.expectEqual(@as(i32, -5), convertToLong(-5.9));
    try testing.expectEqual(@as(i32, 0), convertToLong(-0.5));
}

test "values wrap modulo 2^32: 2^32 is 0, as type-long-settimeout expects" {
    try testing.expectEqual(@as(i32, 0), convertToLong(4294967296.0));
    try testing.expectEqual(@as(i32, 1), convertToLong(4294967297.0));
    try testing.expectEqual(@as(i32, -1), convertToLong(4294967295.0));
    try testing.expectEqual(@as(i32, std.math.minInt(i32)), convertToLong(2147483648.0));
    try testing.expectEqual(@as(i32, std.math.maxInt(i32)), convertToLong(2147483647.0));
    try testing.expectEqual(@as(i32, std.math.minInt(i32)), convertToLong(-2147483648.0));
    try testing.expectEqual(@as(i32, std.math.maxInt(i32)), convertToLong(-2147483649.0));
    // Far past 2^53, where every double is an integer.
    try testing.expectEqual(@as(i32, 0), convertToLong(std.math.pow(f64, 2, 60)));
}
