//! RFC 9110 §5.6.7's three date formats and RFC 9111 §4.2's cache inputs.
const std = @import("std");
const cache = @import("fetch").cache;
const dates = cache.freshness_mod;

test "dp1 HTTP dates support pre-epoch instants and all three wire formats" {
    const cases = .{
        .{ "Wed, 31 Dec 1969 23:59:59 GMT", -1 },
        .{ "Sun, 06 Nov 1994 08:49:37 GMT", 784111777 },
        .{ "Sunday, 06-Nov-94 08:49:37 GMT", 784111777 },
        .{ "Sun Nov  6 08:49:37 1994", 784111777 },
        .{ "Tue, 29 Feb 2000 00:00:00 GMT", 951782400 },
        .{ "Thu, 01 Jan 1970 01:23:45 GMT", 5025 },
        .{ "Sat, 31 Dec 2016 23:59:60 GMT", 1483228800 },
        .{ "Fri, 06 Nov 1994 08:49:37 GMT", 784111777 },
        .{ "sun, 06 nov 1994 08:49:37 gmt", 784111777 },
    };
    inline for (cases) |case| try std.testing.expectEqual(@as(?i64, case[1]), cache.parseHttpDate(case[0]));
}

test "dp1 HTTP dates reject invalid calendar fields and malformed syntax" {
    for ([_][]const u8{
        "Sun, 32 Jan 2023 00:00:00 GMT",
        "Sun, 31 Apr 2023 00:00:00 GMT",
        "Wed, 29 Feb 2023 00:00:00 GMT",
        "Wed, 29 Feb 1900 00:00:00 GMT",
        "Wed, 29 Feb 2100 00:00:00 GMT",
        "Wed, 01 Jan 0000 00:00:00 GMT",
        "Wed, 01 Jan 2020 24:00:00 GMT",
        "Wed, 01 Jan 2020 00:60:00 GMT",
        "Wed, 01 Jan 2020 00:00:61 GMT",
        "Wed, 01 Jan 2020 00:00:00 PST",
        "Wed, 01 Jan 2020 00:00:00 GMT trailing",
        "Wed, +1 Jan 2020 00:00:00 GMT",
        "Wed, 01 Jan 2020 00-00-00 GMT",
        "Xxx, 01 Jan 2020 00:00:00 GMT",
        "Wed, 00 Jan 2020 00:00:00 GMT",
        "Wed, 01 Xxx 2020 00:00:00 GMT",
        "Wed Jan 1 00:00:00 2020",
        "Wednesday, 01-Jan-2020 00:00:00 GMT",
        "",
    }) |input| try std.testing.expectEqual(@as(?i64, null), cache.parseHttpDate(input));
}

test "dp1 rfc850 years use the fifty-year future boundary" {
    if (comptime !@hasDecl(dates, "parseHttpDateAt")) {
        try std.testing.expect(false);
    } else {
        // Now is 2026-01-01 00:00:00 UTC. Exactly fifty years is allowed;
        // one second later must mean the matching year in the past.
        const now: i64 = 1767225600;
        try std.testing.expectEqual(cache.parseHttpDate("Wed, 01 Jan 2076 00:00:00 GMT"), dates.parseHttpDateAt("Wednesday, 01-Jan-76 00:00:00 GMT", now));
        try std.testing.expectEqual(cache.parseHttpDate("Thu, 01 Jan 1976 00:00:01 GMT"), dates.parseHttpDateAt("Thursday, 01-Jan-76 00:00:01 GMT", now));
        try std.testing.expectEqual(cache.parseHttpDate("Sat, 01 Jan 1977 00:00:00 GMT"), dates.parseHttpDateAt("Saturday, 01-Jan-77 00:00:00 GMT", now));
        // The fifty-year window crosses centuries; "00" from 1999 is
        // 2000, rather than the current century's 1900.
        try std.testing.expectEqual(@as(?i64, 946684800), dates.parseHttpDateAt("Saturday, 01-Jan-00 00:00:00 GMT", 915148800));
    }
}

test "dp1 HTTP-date to WallTime checks its nanosecond range" {
    if (comptime !@hasDecl(dates, "parseHttpDateWallTime")) {
        try std.testing.expect(false);
    } else {
        try std.testing.expectEqual(@as(i64, -std.time.ns_per_s), dates.parseHttpDateWallTime("Wed, 31 Dec 1969 23:59:59 GMT").?.ns_since_epoch);
        try std.testing.expect(dates.parseHttpDateWallTime("Fri, 01 Jan 9999 00:00:00 GMT") == null);
        try std.testing.expect(dates.parseHttpDateWallTime("invalid") == null);
    }
}

test "dp1 cache creation and revalidation keep Date Expires and Last-Modified seconds" {
    const allocator = std.testing.allocator;
    const entry = try cache.CacheEntry.init(allocator, 200, &.{
        .{ .name = "Date", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
        .{ .name = "Expires", .value = "Sun Nov  6 09:49:37 1994" },
        .{ .name = "Last-Modified", .value = "Wed, 31 Dec 1969 23:59:59 GMT" },
    }, null, 784111770, 784111780);
    defer entry.deinit();
    try std.testing.expectEqual(@as(i64, 784111777), entry.timing.date_value);
    try std.testing.expectEqual(@as(?i64, 784115377), entry.timing.expires);
    try std.testing.expectEqual(@as(?i64, -1), entry.timing.last_modified);
    try entry.updateAfterRevalidation(&.{
        .{ .name = "Date", .value = "Sunday, 06-Nov-94 10:49:37 GMT" },
        .{ .name = "Expires", .value = "Sun, 06 Nov 1994 11:49:37 GMT" },
        .{ .name = "Last-Modified", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
    }, 784118970, 784118980);
    try std.testing.expectEqual(@as(i64, 784118977), entry.timing.date_value);
    try std.testing.expectEqual(@as(?i64, 784122577), entry.timing.expires);
    try std.testing.expectEqual(@as(?i64, 784111777), entry.timing.last_modified);
}
