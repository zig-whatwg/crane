//! Expiry semantics for "set a cookie"
//!
//! Cookie Store Standard: https://cookiestore.spec.whatwg.org/#set-a-cookie
//! RFC 6265bis §5.5 "Storage Model":
//! https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.5
//!
//! Three rules live here, all of them observable from
//! `tests/wpt/cookiestore/cookieStore_set_maxAge.https.any.js` and
//! `tests/wpt/cookiestore/cookieListItem_attributes.https.window.js`:
//!
//! 1. `maxAge` is a seconds-from-now lifetime. Non-positive means the cookie is
//!    already expired, which deletes any cookie of the same identity.
//! 2. Supplying both `expires` and `maxAge` is a failure (surfaces as TypeError).
//! 3. An expiry more than 400 days in the future is clamped to 400 days.

const std = @import("std");
const clock = @import("clock");
const cookiestore = @import("cookiestore");

const CookieJar = cookiestore.CookieJar;
const setCookie = cookiestore.setCookie;
const queryCookies = cookiestore.queryCookies;

const ONE_DAY_MS: i64 = 24 * 60 * 60 * 1000;
const FOUR_HUNDRED_DAYS_MS: i64 = 400 * ONE_DAY_MS;

/// Returns the stored cookie named `name`, or null. Reaches into the jar
/// directly because `CookieListItem` deliberately carries only name and value.
fn storedCookie(jar: *CookieJar, name: []const u8) ?cookiestore.Cookie {
    for (jar.cookies.items) |cookie| {
        if (std.mem.eql(u8, cookie.name, name)) return cookie;
    }
    return null;
}

fn countNamed(allocator: std.mem.Allocator, jar: *CookieJar, name: []const u8) !usize {
    var items = try queryCookies(allocator, jar, "example.com", "/", name);
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }
    return items.items.len;
}

test "setCookie - maxAge sets an expiry that many seconds from now" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const before = clock.wallMillis();
    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .max_age = 60,
    });

    try std.testing.expectEqual(@as(usize, 1), try countNamed(allocator, &jar, "cookie-name"));

    const cookie = storedCookie(&jar, "cookie-name") orelse return error.CookieMissing;
    const expiry = cookie.expiry_time orelse return error.SessionCookieNotExpected;

    // 60s from now, allowing a second of slop for the clock reads either side.
    try std.testing.expect(expiry >= before + 60 * 1000);
    try std.testing.expect(expiry <= clock.wallMillis() + 61 * 1000);
}

test "setCookie - non-positive maxAge expires the cookie immediately" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // Seed a live cookie, then overwrite it with a negative maxAge.
    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
    });
    try std.testing.expectEqual(@as(usize, 1), try countNamed(allocator, &jar, "cookie-name"));

    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .max_age = -60,
    });
    try std.testing.expectEqual(@as(usize, 0), try countNamed(allocator, &jar, "cookie-name"));

    // maxAge of exactly zero is non-positive too.
    try setCookie(allocator, &jar, "example.com", .{
        .name = "other-name",
        .value = "other-value",
        .max_age = 0,
    });
    try std.testing.expectEqual(@as(usize, 0), try countNamed(allocator, &jar, "other-name"));
}

test "setCookie - supplying both expires and maxAge fails" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const tomorrow = clock.wallMillis() + ONE_DAY_MS;
    try std.testing.expectError(cookiestore.CookieError.ValidationError, setCookie(
        allocator,
        &jar,
        "example.com",
        .{
            .name = "cookie-name",
            .value = "cookie-value",
            .expires = tomorrow,
            .max_age = 60,
        },
    ));

    try std.testing.expectEqual(@as(usize, 0), try countNamed(allocator, &jar, "cookie-name"));
}

test "setCookie - expiry beyond 400 days is clamped to 400 days" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const ten_years = clock.wallMillis() + 10 * 365 * ONE_DAY_MS;
    const before = clock.wallMillis();
    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .expires = ten_years,
    });

    const cookie = storedCookie(&jar, "cookie-name") orelse return error.CookieMissing;
    const expiry = cookie.expiry_time orelse return error.SessionCookieNotExpected;

    try std.testing.expect(expiry < ten_years);
    try std.testing.expect(expiry >= before + FOUR_HUNDRED_DAYS_MS - 1000);
    try std.testing.expect(expiry <= clock.wallMillis() + FOUR_HUNDRED_DAYS_MS);
}

test "setCookie - a maxAge beyond 400 days is clamped too" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const before = clock.wallMillis();
    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .max_age = 10 * 365 * 24 * 60 * 60,
    });

    const cookie = storedCookie(&jar, "cookie-name") orelse return error.CookieMissing;
    const expiry = cookie.expiry_time orelse return error.SessionCookieNotExpected;

    try std.testing.expect(expiry >= before + FOUR_HUNDRED_DAYS_MS - 1000);
    try std.testing.expect(expiry <= clock.wallMillis() + FOUR_HUNDRED_DAYS_MS);
}

test "setCookie - an expiry inside 400 days is left alone" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const tomorrow = clock.wallMillis() + ONE_DAY_MS;
    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .expires = tomorrow,
    });

    const cookie = storedCookie(&jar, "cookie-name") orelse return error.CookieMissing;
    try std.testing.expectEqual(tomorrow, cookie.expiry_time.?);
}
