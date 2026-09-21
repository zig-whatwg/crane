//! Recording cookie changes for `change` event dispatch
//!
//! Cookie Store Standard, "process cookie changes":
//! https://cookiestore.spec.whatwg.org/#process-cookie-changes
//!
//! `CookieChangeObserver`, `processCookieChanges` and
//! `CookieChangeEvent.createFromChanges` were all already here; nothing ever
//! told the observer that a cookie had moved. These tests pin the semantics
//! the WPT event tests require:
//!
//! - a fresh set is a `changed` entry;
//! - overwriting is a single `changed` entry, never a delete plus an add;
//! - deleting a cookie that exists is a `deleted` entry;
//! - deleting one that does not exist records nothing at all, per
//!   `cookieStore_event_delete.https.window.js` ("does not fire change events
//!   for non-existing expired cookies").

const std = @import("std");
const cookiestore = @import("cookiestore");

const CookieJar = cookiestore.CookieJar;
const CookieChangeObserver = cookiestore.CookieChangeObserver;
const setCookieObserved = cookiestore.setCookieObserved;
const deleteCookieObserved = cookiestore.deleteCookieObserved;

const HOST = "example.com";

fn pending(observer: *const CookieChangeObserver) []const cookiestore.CookieChange {
    return observer.pending_changes.items;
}

test "setCookieObserved - a new cookie records one changed entry" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    try setCookieObserved(allocator, &jar, &observer, HOST, .{
        .name = "cookie-name",
        .value = "cookie-value",
    });

    const changes = pending(&observer);
    try std.testing.expectEqual(@as(usize, 1), changes.len);
    try std.testing.expectEqual(cookiestore.CookieChangeType.changed, changes[0].change_type);
    try std.testing.expectEqualStrings("cookie-name", changes[0].cookie.name);
    try std.testing.expectEqualStrings("cookie-value", changes[0].cookie.value);
}

test "setCookieObserved - overwriting records one changed entry, not a delete" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    try setCookieObserved(allocator, &jar, &observer, HOST, .{
        .name = "cookie-name",
        .value = "cookie-value",
    });
    observer.flush(); // drain the first event, as a dispatch would

    try setCookieObserved(allocator, &jar, &observer, HOST, .{
        .name = "cookie-name",
        .value = "new-cookie-value",
    });

    const changes = pending(&observer);
    try std.testing.expectEqual(@as(usize, 1), changes.len);
    try std.testing.expectEqual(cookiestore.CookieChangeType.changed, changes[0].change_type);
    try std.testing.expectEqualStrings("new-cookie-value", changes[0].cookie.value);
}

test "deleteCookieObserved - deleting an existing cookie records a deleted entry" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    try setCookieObserved(allocator, &jar, &observer, HOST, .{
        .name = "cookie-name",
        .value = "cookie-value",
    });
    observer.flush();

    try deleteCookieObserved(allocator, &jar, &observer, HOST, .{ .name = "cookie-name" });

    const changes = pending(&observer);
    try std.testing.expectEqual(@as(usize, 1), changes.len);
    try std.testing.expectEqual(cookiestore.CookieChangeType.deleted, changes[0].change_type);
    try std.testing.expectEqualStrings("cookie-name", changes[0].cookie.name);
}

test "deleteCookieObserved - deleting a cookie that does not exist records nothing" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    try deleteCookieObserved(allocator, &jar, &observer, HOST, .{ .name = "cookie-unknown" });

    try std.testing.expectEqual(@as(usize, 0), pending(&observer).len);
}

test "setCookieObserved - an already-expired set on nothing records nothing" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    // maxAge of zero expires immediately; there is nothing to delete, so it is
    // not an observable change.
    try setCookieObserved(allocator, &jar, &observer, HOST, .{
        .name = "cookie-name",
        .value = "cookie-value",
        .max_age = 0,
    });

    try std.testing.expectEqual(@as(usize, 0), pending(&observer).len);
}

test "setCookieObserved - a null observer behaves exactly like setCookie" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    try setCookieObserved(allocator, &jar, null, HOST, .{
        .name = "cookie-name",
        .value = "cookie-value",
    });

    var items = try cookiestore.queryCookies(allocator, &jar, HOST, "/", "cookie-name");
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), items.items.len);
}

test "setCookie - the unobserved entry point still records nothing" {
    const allocator = std.testing.allocator;

    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    try cookiestore.setCookie(allocator, &jar, HOST, .{
        .name = "cookie-name",
        .value = "cookie-value",
    });
    try cookiestore.deleteCookie(allocator, &jar, HOST, .{ .name = "cookie-name" });

    var items = try cookiestore.queryCookies(allocator, &jar, HOST, "/", null);
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), items.items.len);
}
