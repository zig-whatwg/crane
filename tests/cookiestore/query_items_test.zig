//! CookieStore.get()/getAll() query semantics
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/#query-cookies
//!
//! These cover the pure-Zig half of `CookieStore.get`/`getAll`: which cookies
//! the jar is asked for, and that asking leaks nothing. The V8 half - wrapping
//! the answer in a Promise and a `{name, value}` object - needs an isolate and
//! lives in `tests/wpt/crane/cookiestore-promise-shape.https.html`.

const std = @import("std");
const cookiestore = @import("cookiestore");
const impls = @import("impls");

const CookieStoreImpl = impls.CookieStore;

/// Put a cookie straight into the store's jar, the way `set()` would.
fn seed(internal: *CookieStoreImpl.InternalState, name: []const u8, value: []const u8) !void {
    try cookiestore.setCookie(
        internal.allocator,
        &internal.cookie_jar,
        internal.origin_host,
        .{ .name = name, .value = value },
    );
}

test "queryItems returns the named cookie" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    try seed(internal, "cookie-name", "cookie-value");

    var items = try CookieStoreImpl.queryItems(internal, "cookie-name");
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("cookie-name", items.items[0].name);
    try std.testing.expectEqualStrings("cookie-value", items.items[0].value);
}

test "queryItems returns nothing for a name that was never set" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    try seed(internal, "cookie-name", "cookie-value");

    var items = try CookieStoreImpl.queryItems(internal, "absent");
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 0), items.items.len);
}

test "queryItems with a null name returns every cookie" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    try seed(internal, "one", "1");
    try seed(internal, "two", "2");

    var items = try CookieStoreImpl.queryItems(internal, null);
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 2), items.items.len);
}

test "queryItems on an empty jar returns an empty list" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    var items = try CookieStoreImpl.queryItems(internal, null);
    defer CookieStoreImpl.freeItems(allocator, &items);

    try std.testing.expectEqual(@as(usize, 0), items.items.len);
}

// `getAll()` and `getAll("")` are the same call by the time an impl sees them:
// a missing `USVString` argument is defaulted to an empty slice by
// `getDefaultArgValue` in src/runtime/engines/v8/interface.zig. Only the
// `CookieStoreGetOptions` overload, which codegen has not produced, could
// separate them. `getAll()` meaning "every cookie" is the case WPT exercises
// (cookieStore_getAll_multiple.https.any.js), so the empty string reads as the
// wildcard - pin that, because the alternative is a silent behaviour swap.
test "nameFilter reads the empty string as the wildcard" {
    try std.testing.expect(CookieStoreImpl.nameFilter("") == null);
}

test "nameFilter passes a non-empty name through unchanged" {
    const filter = CookieStoreImpl.nameFilter("cookie-name") orelse
        return error.TestExpectedNonNull;
    try std.testing.expectEqualStrings("cookie-name", filter);
}
