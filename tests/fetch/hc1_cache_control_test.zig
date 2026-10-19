//! RFC 9111 5.2 Cache-Control, as the HTTP cache reads it (lane httpcache1):
//! the directive grammar (`token [ "=" ( token / quoted-string ) ]`, names
//! compared case-insensitively, 5.2), delta-seconds (1.2.2: 1*DIGIT, an
//! overflow is 2^31), the first occurrence of a duplicated directive
//! (4.2.1), an invalid max-age (4.2.1: stale), and the request directives
//! (5.2.1) the browsers' majority honours.
const std = @import("std");
const cache = @import("fetch").cache;
const Directives = cache.cache_control.Directives;

test "hc1 Cache-Control: a quoted argument's comma does not end the directive" {
    // 5.2: `no-cache="a, max-age=0"` is ONE directive with a quoted-string
    // argument; the RFC 7234-era parser split it at the comma inside the
    // quotes and read a second max-age out of it.
    const d = Directives.parse("max-age=60, no-cache=\"a, max-age=0\"");
    try std.testing.expectEqual(Directives.Seconds{ .value = 60 }, d.max_age);
    try std.testing.expect(d.no_cache);
}

test "hc1 Cache-Control: the first occurrence of a directive is the one used" {
    // 4.2.1: "either the first occurrence should be used or the response
    // should be considered stale".
    const d = Directives.parse("max-age=60, max-age=0");
    try std.testing.expectEqual(Directives.Seconds{ .value = 60 }, d.max_age);
    var lines = Directives{};
    lines.add("max-age=5");
    lines.add("max-age=7, no-store");
    try std.testing.expectEqual(Directives.Seconds{ .value = 5 }, lines.max_age);
    try std.testing.expect(lines.no_store);
}

test "hc1 Cache-Control: delta-seconds are digits; an overflow is 2^31, anything else invalid" {
    try std.testing.expectEqual(Directives.Seconds{ .value = 2147483648 }, Directives.parse("max-age=99999999999999999999").max_age);
    try std.testing.expectEqual(Directives.Seconds.invalid, Directives.parse("max-age=abc").max_age);
    try std.testing.expectEqual(Directives.Seconds.invalid, Directives.parse("max-age=-5").max_age);
    try std.testing.expectEqual(Directives.Seconds.invalid, Directives.parse("max-age=").max_age);
    try std.testing.expectEqual(Directives.Seconds.invalid, Directives.parse("max-age").max_age);
    // 5.2: recipients accept the quoted form too.
    try std.testing.expectEqual(Directives.Seconds{ .value = 5 }, Directives.parse("max-age=\"5\"").max_age);
    try std.testing.expectEqual(Directives.Seconds.absent, Directives.parse("no-cache").max_age);
}

test "hc1 Cache-Control: names are case-insensitive, whitespace and empty members are skipped" {
    const d = Directives.parse(" ,  MAX-AGE=10 ,,Private ,  Must-Revalidate");
    try std.testing.expectEqual(Directives.Seconds{ .value = 10 }, d.max_age);
    try std.testing.expect(d.private);
    try std.testing.expect(d.must_revalidate);
    try std.testing.expect(!d.public);
}

test "hc1 Cache-Control: an unknown directive, even with a quoted argument, is ignored" {
    const d = Directives.parse("community=\"UCI, max-age=0\", public, foo=bar");
    try std.testing.expectEqual(Directives.Seconds.absent, d.max_age);
    try std.testing.expect(d.public);
}

test "hc1 Cache-Control: the request directives max-stale, min-fresh, no-cache, no-store, only-if-cached" {
    const any = Directives.parse("max-stale");
    try std.testing.expectEqual(Directives.MaxStale.any, any.max_stale.?);
    const bounded = Directives.parse("max-stale=30, min-fresh=20");
    try std.testing.expectEqual(Directives.MaxStale{ .seconds = 30 }, bounded.max_stale.?);
    try std.testing.expectEqual(Directives.Seconds{ .value = 20 }, bounded.min_fresh);
    // An invalid max-stale argument is no permission to serve stale.
    try std.testing.expectEqual(@as(?Directives.MaxStale, null), Directives.parse("max-stale=soon").max_stale);
    const flags = Directives.parse("no-cache, no-store, only-if-cached");
    try std.testing.expect(flags.no_cache and flags.no_store and flags.only_if_cached);
}

test "hc1 Cache-Control: s-maxage, stale-while-revalidate and immutable parse" {
    const d = Directives.parse("s-maxage=600, stale-while-revalidate=30, immutable, proxy-revalidate");
    try std.testing.expectEqual(Directives.Seconds{ .value = 600 }, d.s_maxage);
    try std.testing.expectEqual(Directives.Seconds{ .value = 30 }, d.stale_while_revalidate);
    try std.testing.expect(d.immutable and d.proxy_revalidate);
}

test "hc1 Cache-Control: a malformed member is skipped up to the next comma outside quotes" {
    const d = Directives.parse("=oops, \"stray, quoted\" junk, max-age=9");
    try std.testing.expectEqual(Directives.Seconds{ .value = 9 }, d.max_age);
}
