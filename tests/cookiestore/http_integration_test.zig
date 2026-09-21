//! Set-Cookie header parsing and storage
//!
//! RFC 6265bis §5.4 "The Set-Cookie Header Field":
//! https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.4
//!
//! Two defects these pin down:
//!
//! 1. `Max-Age` produced a *seconds*-epoch expiry while everything that reads
//!    `expiry_time` compares it against `clock.wallMillis()`, so every Max-Age
//!    cookie looked ~56 years stale and was dropped on the way into the jar.
//!    The old test only asserted `expiry_time != null`, which the bug satisfied.
//! 2. `processSetCookieHeaders` handed its parsed `Cookie` to `jar.store`,
//!    which clones, and then dropped the original on the floor — one leaked
//!    Cookie per Set-Cookie header.

const std = @import("std");
const clock = @import("clock");
const cookiestore = @import("cookiestore");

const CookieJar = cookiestore.CookieJar;
const parseSetCookieHeader = cookiestore.parseSetCookieHeader;
const processSetCookieHeaders = cookiestore.processSetCookieHeaders;

test "parseSetCookieHeader - Max-Age yields a live expiry in milliseconds" {
    const allocator = std.testing.allocator;

    const before = clock.wallMillis();
    var cookie = try parseSetCookieHeader(
        allocator,
        "id=abc; Max-Age=3600",
        "example.com",
        "/",
        true,
    );
    defer cookie.deinit();

    const expiry = cookie.expiry_time orelse return error.SessionCookieNotExpected;

    // The whole point: an hour from now is in the future, not the past.
    try std.testing.expect(!cookie.isExpired());
    try std.testing.expect(expiry >= before + 3600 * 1000);
    try std.testing.expect(expiry <= clock.wallMillis() + 3601 * 1000);
}

test "parseSetCookieHeader - a non-positive Max-Age expires the cookie" {
    const allocator = std.testing.allocator;

    var cookie = try parseSetCookieHeader(
        allocator,
        "id=abc; Max-Age=0",
        "example.com",
        "/",
        true,
    );
    defer cookie.deinit();

    try std.testing.expect(cookie.isExpired());
}

test "processSetCookieHeaders - a Max-Age cookie survives into the jar" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const headers = [_][]const u8{
        "session=abc123; Max-Age=3600",
        "theme=dark",
    };
    try processSetCookieHeaders(allocator, &jar, &headers, "example.com", "/", true);

    try std.testing.expectEqual(@as(usize, 2), jar.count());
}

test "processSetCookieHeaders - parsed cookies are not leaked" {
    // std.testing.allocator fails the test on any leak, so simply running a
    // batch of headers through is the assertion.
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const headers = [_][]const u8{
        "a=1; Path=/app; Secure",
        "b=2; Domain=example.com",
        "c=3; Max-Age=60",
        "not-a-cookie",
        "=nothing",
    };
    try processSetCookieHeaders(allocator, &jar, &headers, "example.com", "/", true);

    // The three well-formed headers land; the two malformed ones are skipped.
    try std.testing.expectEqual(@as(usize, 3), jar.count());
}
