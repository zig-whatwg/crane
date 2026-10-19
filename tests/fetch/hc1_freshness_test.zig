//! RFC 9111 4.2 freshness as the HTTP cache computes it (lane httpcache1):
//! the freshness lifetime (4.2.1), the heuristic (4.2.2) with the statuses
//! the browsers' majority gives one, the age (4.2.3, the arithmetic the RFC
//! 7234 library pinned, unchanged in 9111), Expires (5.3) and Age (5.1).
const std = @import("std");
const cache = @import("fetch").cache;
const freshness = cache.freshness_mod;
const Facts = freshness.Facts;

const Header = struct { name: []const u8, value: []const u8 };

fn facts(status: u16, headers: []const Header) Facts {
    return Facts.fromHeaders(status, headers);
}

// "Sun, 06 Nov 1994 08:49:37 GMT"
const t0: i64 = 784111777;

test "hc1 freshness: max-age wins over Expires, and Expires counts from Date" {
    const both = facts(200, &.{
        .{ .name = "Date", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
        .{ .name = "Expires", .value = "Sun, 06 Nov 1994 09:49:37 GMT" },
        .{ .name = "Cache-Control", .value = "max-age=60" },
    });
    try std.testing.expectEqual(@as(u64, 60), freshness.lifetime(both, t0));
    const expires = facts(200, &.{
        .{ .name = "Date", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
        .{ .name = "Expires", .value = "Sun, 06 Nov 1994 09:49:37 GMT" },
    });
    try std.testing.expectEqual(@as(u64, 3600), freshness.lifetime(expires, t0));
    // No Date: the time the response was received (RFC 9110 6.6.1).
    const no_date = facts(200, &.{.{ .name = "Expires", .value = "Sun, 06 Nov 1994 09:49:37 GMT" }});
    try std.testing.expectEqual(@as(u64, 1800), freshness.lifetime(no_date, t0 + 1800));
    // An Expires before Date is a lifetime of 0, not a negative one.
    const past = facts(200, &.{
        .{ .name = "Date", .value = "Sun, 06 Nov 1994 10:49:37 GMT" },
        .{ .name = "Expires", .value = "Sun, 06 Nov 1994 09:49:37 GMT" },
    });
    try std.testing.expectEqual(@as(u64, 0), freshness.lifetime(past, t0));
}

test "hc1 freshness: an invalid Expires is already expired, whatever Last-Modified says" {
    // 5.3: "A cache recipient MUST interpret invalid date formats, especially
    // the value "0", as representing a time in the past". The RFC 7234-era
    // library fell through to the Last-Modified heuristic instead.
    for ([_][]const u8{ "0", "-1", "soon", "Sun, 06 Nov 1994 08:49:37 PST" }) |bad| {
        const f = facts(200, &.{
            .{ .name = "Date", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
            .{ .name = "Last-Modified", .value = "Sun, 06 Nov 1984 08:49:37 GMT" },
            .{ .name = "Expires", .value = bad },
        });
        try std.testing.expectEqual(@as(u64, 0), freshness.lifetime(f, t0));
    }
}

test "hc1 freshness: an invalid max-age is stale" {
    // 4.2.1: "Caches are encouraged to consider responses that have invalid
    // freshness information (e.g., a max-age directive with non-integer
    // content) to be stale."
    const f = facts(200, &.{
        .{ .name = "Date", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
        .{ .name = "Expires", .value = "Sun, 06 Nov 1994 09:49:37 GMT" },
        .{ .name = "Cache-Control", .value = "max-age=ten" },
    });
    try std.testing.expectEqual(@as(u64, 0), freshness.lifetime(f, t0));
}

test "hc1 freshness: s-maxage is a shared cache's; this private cache ignores it" {
    const f = facts(200, &.{.{ .name = "Cache-Control", .value = "s-maxage=600" }});
    try std.testing.expectEqual(@as(u64, 0), freshness.lifetime(f, t0));
}

test "hc1 freshness: the heuristic is 10% of Date minus Last-Modified, with no cap" {
    const lm = "Sun, 06 Nov 1994 08:49:37 GMT";
    const ten_days_later = "Wed, 16 Nov 1994 08:49:37 GMT";
    const f = facts(200, &.{
        .{ .name = "Date", .value = ten_days_later },
        .{ .name = "Last-Modified", .value = lm },
    });
    // 864000 s / 10: the 1-day cap of the RFC 7234-era library is gone
    // (Chromium has none; Firefox a week; RFC 9111 4.2.2 sets none).
    try std.testing.expectEqual(@as(u64, 86400), freshness.lifetime(f, t0 + 864000));
    // A Last-Modified after Date gives nothing.
    const future = facts(200, &.{
        .{ .name = "Date", .value = lm },
        .{ .name = "Last-Modified", .value = ten_days_later },
    });
    try std.testing.expectEqual(@as(u64, 0), freshness.lifetime(future, t0));
}

test "hc1 freshness: the heuristic statuses are the browsers' majority's" {
    const headers = [_]Header{
        .{ .name = "Date", .value = "Wed, 16 Nov 1994 08:49:37 GMT" },
        .{ .name = "Last-Modified", .value = "Sun, 06 Nov 1994 08:49:37 GMT" },
    };
    for ([_]u16{ 200, 203, 204, 206, 300, 301, 308 }) |status| {
        try std.testing.expectEqual(@as(u64, 86400), freshness.lifetime(facts(status, &headers), t0 + 864000));
    }
    // RFC 9110 15.1 calls these heuristically cacheable, but Chrome 155 and
    // Firefox 158 give them no heuristic lifetime (fetch/http-cache/
    // heuristic.any.html): stored, never fresh by heuristic.
    for ([_]u16{ 404, 405, 414, 501, 201, 302, 307, 403, 500 }) |status| {
        try std.testing.expectEqual(@as(u64, 0), freshness.lifetime(facts(status, &headers), t0 + 864000));
    }
    // A public response of an unknown status: none either (Chrome, Firefox).
    const public = headers ++ [_]Header{.{ .name = "Cache-Control", .value = "public" }};
    try std.testing.expectEqual(@as(u64, 0), freshness.lifetime(facts(299, &public), t0 + 864000));
    // 410 Gone is fresh without limit (Chromium and Gecko both).
    try std.testing.expect(freshness.lifetime(facts(410, &.{}), t0) >= 2147483648);
}

test "hc1 freshness: RFC 9110 15.1's heuristically cacheable statuses decide what may be stored" {
    for ([_]u16{ 200, 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501 }) |status| {
        try std.testing.expect(freshness.heuristicallyCacheable(status));
    }
    for ([_]u16{ 201, 202, 302, 303, 307, 400, 403, 500, 502, 503 }) |status| {
        try std.testing.expect(!freshness.heuristicallyCacheable(status));
    }
}

test "hc1 freshness: current age is the corrected initial age plus the resident time" {
    // The RFC 7234 library's three age cases, unchanged in RFC 9111 4.2.3.
    // request 1000, response 1001, Date 1001: age at 1001 is the 1 s delay.
    const plain = Facts{ .status = 200, .date = 1001 };
    try std.testing.expectEqual(@as(u64, 1), freshness.currentAge(plain, 1000, 1001, 1001));
    try std.testing.expectEqual(@as(u64, 101), freshness.currentAge(plain, 1000, 1001, 1101));
    // An Age header of 50 adds itself to the response delay.
    const aged = Facts{ .status = 200, .date = 1001, .age = 50 };
    try std.testing.expectEqual(@as(u64, 51), freshness.currentAge(aged, 1000, 1001, 1001));
    // A Date ahead of the clock gives no negative apparent age.
    const skewed = Facts{ .status = 200, .date = 1011 };
    try std.testing.expectEqual(@as(u64, 1), freshness.currentAge(skewed, 1000, 1001, 1001));
    // A Date far behind: the apparent age dominates.
    const old = Facts{ .status = 200, .date = 401 };
    try std.testing.expectEqual(@as(u64, 600), freshness.currentAge(old, 1000, 1001, 1001));
}

test "hc1 freshness: Age takes its first member and ignores an invalid one" {
    try std.testing.expectEqual(@as(u64, 30), facts(200, &.{.{ .name = "Age", .value = "30, 40" }}).age);
    try std.testing.expectEqual(@as(u64, 0), facts(200, &.{.{ .name = "Age", .value = "-3" }}).age);
    try std.testing.expectEqual(@as(u64, 0), facts(200, &.{.{ .name = "Age", .value = "soon" }}).age);
    try std.testing.expectEqual(@as(u64, 2147483648), facts(200, &.{.{ .name = "Age", .value = "999999999999999999999" }}).age);
}

test "hc1 freshness: Cache-Control lines combine, and the first max-age counts" {
    const f = facts(200, &.{
        .{ .name = "cache-control", .value = "public" },
        .{ .name = "Cache-Control", .value = "max-age=5, max-age=900" },
    });
    try std.testing.expect(f.directives.public);
    try std.testing.expectEqual(@as(u64, 5), freshness.lifetime(f, t0));
}

test "hc1 freshness: a response's Pragma: no-cache makes it no-cache, whatever Cache-Control says" {
    // RFC 9111 5.4 gives Pragma no response meaning, but Chrome 155, Firefox
    // 158 and Safari 27 all refuse to reuse such a response without the
    // network (fetch/http-cache/pragma-no-cache-with-cache-control.html,
    // wpt.fyi 23b0b89b1a; Chrome and Safari even with immutable).
    const f = facts(200, &.{
        .{ .name = "Cache-Control", .value = "max-age=2592000, public" },
        .{ .name = "Pragma", .value = "no-cache" },
    });
    try std.testing.expect(f.directives.no_cache);
    const other = facts(200, &.{.{ .name = "Pragma", .value = "x-other" }});
    try std.testing.expect(!other.directives.no_cache);
}
