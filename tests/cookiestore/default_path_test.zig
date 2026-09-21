//! Default-path derivation for "set a cookie"
//!
//! RFC 6265bis §5.1.4 "Paths and Path-Match":
//! https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis#section-5.1.4
//!
//! When no Path attribute is supplied the cookie takes the *default-path*,
//! which is computed from the path component of the creation URL — everything
//! up to but not including the rightmost "/". It is not derived from the host.

const std = @import("std");
const cookiestore = @import("cookiestore");

const CookieJar = cookiestore.CookieJar;
const setCookie = cookiestore.setCookie;
const queryCookies = cookiestore.queryCookies;

fn storedPath(jar: *CookieJar, name: []const u8) ?[]const u8 {
    for (jar.cookies.items) |cookie| {
        if (std.mem.eql(u8, cookie.name, name)) return cookie.path;
    }
    return null;
}

fn countAt(allocator: std.mem.Allocator, jar: *CookieJar, path: []const u8) !usize {
    var items = try queryCookies(allocator, jar, "example.com", path, null);
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }
    return items.items.len;
}

test "setCookie - an empty path falls back to the creation URL's default-path" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .path = "",
        .url_path = "/a/b/c",
    });

    try std.testing.expectEqualStrings("/a/b", storedPath(&jar, "cookie-name").?);

    // Observable through path-match: visible under /a/b, not at the root.
    try std.testing.expectEqual(@as(usize, 1), try countAt(allocator, &jar, "/a/b/c"));
    try std.testing.expectEqual(@as(usize, 0), try countAt(allocator, &jar, "/"));
}

test "setCookie - a creation URL with one path segment defaults to root" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .path = "",
        .url_path = "/index.html",
    });

    try std.testing.expectEqualStrings("/", storedPath(&jar, "cookie-name").?);
    try std.testing.expectEqual(@as(usize, 1), try countAt(allocator, &jar, "/"));
}

test "setCookie - an explicit path still wins over the default-path" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .path = "/explicit",
        .url_path = "/a/b/c",
    });

    try std.testing.expectEqualStrings("/explicit", storedPath(&jar, "cookie-name").?);
}

test "setCookie - the Cookie Store default of \"/\" is unaffected by the creation URL" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    // CookieStore.set() passes "/" explicitly, so a deep creation URL must not
    // narrow the cookie. https://cookiestore.spec.whatwg.org/#dom-cookiestore-set
    try setCookie(allocator, &jar, "example.com", .{
        .name = "cookie-name",
        .value = "cookie-value",
        .url_path = "/a/b/c",
    });

    try std.testing.expectEqualStrings("/", storedPath(&jar, "cookie-name").?);
    try std.testing.expectEqual(@as(usize, 1), try countAt(allocator, &jar, "/"));
}
