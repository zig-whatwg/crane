//! CookieStore.get()/getAll() query semantics
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/#query-cookies
//!
//! These cover the pure-Zig half of `CookieStore.get`/`getAll`: which cookies
//! the user agent's jar answers for the store's creation URL, and that asking
//! leaks nothing. The V8 half - wrapping
//! the answer in a Promise and a `{name, value}` object - needs an isolate and
//! lives in `tests/wpt/crane/cookiestore-promise-shape.https.html`.

const std = @import("std");
const cookiestore = @import("cookiestore");
const impls = @import("impls");

const CookieStoreImpl = impls.CookieStore;

/// The creation URL the queries are for.
const url = "https://example.com/page";

/// Put a cookie straight into the jar, the way `set()` would.
fn seed(jar: *cookiestore.CookieJar, name: []const u8, value: []const u8) !void {
    try cookiestore.setCookie(std.testing.allocator, jar, "example.com", .{ .name = name, .value = value });
}

test "queryItems returns the named cookie" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    try seed(&jar, "cookie-name", "cookie-value");

    var items = try CookieStoreImpl.queryItems(allocator, &jar, url, "cookie-name");
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("cookie-name", items.items[0].name);
    try std.testing.expectEqualStrings("cookie-value", items.items[0].value);
}

test "queryItems returns nothing for a name that was never set" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    try seed(&jar, "cookie-name", "cookie-value");

    var items = try CookieStoreImpl.queryItems(allocator, &jar, url, "absent");
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 0), items.items.len);
}

test "queryItems with a null name returns every cookie" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    try seed(&jar, "one", "1");
    try seed(&jar, "two", "2");

    var items = try CookieStoreImpl.queryItems(allocator, &jar, url, null);
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 2), items.items.len);
}

test "queryItems on an empty jar returns an empty list" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    var items = try CookieStoreImpl.queryItems(allocator, &jar, url, null);
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 0), items.items.len);
}

// The generated dictionary overload now distinguishes an omitted filter
// from a string argument. Query cookies step 3.2 filters every non-null
// name, including the empty string.
test "queryCookies empty name never matches a named cookie" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "named", "value");

    var items = try cookiestore.queryCookies(allocator, &jar, "example.com", "/", "");
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), items.items.len);
}

test "queryCookies empty and null name filters remain distinct" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "named", "value");
    try seed(&jar, "", "nameless");

    var named = try cookiestore.queryCookies(allocator, &jar, "example.com", "/", "");
    defer {
        for (named.items) |*item| item.deinit();
        named.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), named.items.len);
    try std.testing.expectEqualStrings("", named.items[0].name);
    try std.testing.expectEqualStrings("nameless", named.items[0].value);

    var all = try cookiestore.queryCookies(allocator, &jar, "example.com", "/", null);
    defer {
        for (all.items) |*item| item.deinit();
        all.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 2), all.items.len);
}

test "queryItems answers for the URL's host and path, and never with an HttpOnly cookie" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    const http: cookiestore.StoreOptions = .{ .is_secure = true, .host = "example.com", .http_only_allowed = true };
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "visible=1; Path=/", "/", http);
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "hidden=1; Path=/; HttpOnly", "/", http);
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "elsewhere=1; Path=/other", "/", http);

    var items = try CookieStoreImpl.queryItems(allocator, &jar, url, null);
    defer CookieStoreImpl.freeItems(allocator, &items);
    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("visible", items.items[0].name);

    var other_host = try CookieStoreImpl.queryItems(allocator, &jar, "https://other.test/", null);
    defer CookieStoreImpl.freeItems(allocator, &other_host);
    try std.testing.expectEqual(@as(usize, 0), other_host.items.len);
}

test "the Cookie Store API cannot replace an HttpOnly cookie" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "session=http; Path=/; HttpOnly", "/", .{ .is_secure = true, .host = "example.com", .http_only_allowed = true });
    try seed(&jar, "session", "script");
    try std.testing.expectEqual(@as(usize, 1), jar.count());
    try std.testing.expectEqualStrings("http", jar.cookies.items[0].value);
}
