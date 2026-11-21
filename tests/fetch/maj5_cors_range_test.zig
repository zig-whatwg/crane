//! Lane maj5: Fetch "CORS-safelisted request-header", the `range` case -
//! "Let rangeValue be the result of parsing a single range header value
//! given value and false. If rangeValue is failure, then return false. If
//! rangeValue[0] is null, then return false." - and "parse a single range
//! header value" step 2, a case-sensitive "bytes". Chrome and Firefox
//! preflight `BYTES=100-200`, `Bytes=100-200` and `bytes=200-100`
//! (cors/cors-safelisted-request-header.any.js).
const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const internal = fetch.internal;

test "a range is safelisted only as `bytes=` start-end with start <= end" {
    for ([_][]const u8{ "bytes=100-200", "bytes=0-", "bytes=5-5" }) |value| {
        if (!internal.isCORSSafelistedRequestHeader("range", value)) {
            std.debug.print("range \"{s}\" should be safelisted\n", .{value});
            return error.TestUnexpectedResult;
        }
    }
    for ([_][]const u8{ "BYTES=100-200", "Bytes=100-200", "bytes=200-100", "bytes=-500", "bytes = 1-2", "bytes=1-2,3-4", "bytes=", "bytes" }) |value| {
        if (internal.isCORSSafelistedRequestHeader("Range", value)) {
            std.debug.print("range \"{s}\" should need a preflight\n", .{value});
            return error.TestUnexpectedResult;
        }
    }
}

test "parse a single range header value: the unit is case-sensitive" {
    try testing.expect(internal.parseSingleRangeHeaderValue("BYTES=0-5", true) == null);
    try testing.expect(internal.parseSingleRangeHeaderValue("ByTes=0-5", true) == null);
    const range = internal.parseSingleRangeHeaderValue("bytes \t =\t 6-", true).?;
    try testing.expectEqual(@as(?u64, 6), range.start);
    try testing.expectEqual(@as(?u64, null), range.end);
}
