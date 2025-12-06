//! CookieStore WebIDL Integration Tests
//!
//! These tests verify the WebIDL impl layer types and internal state management.
//! Full runtime integration requires V8, so these tests focus on unit-level verification.
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/

const std = @import("std");
const cookiestore = @import("cookiestore");
const impls = @import("impls");

const CookieStoreImpl = impls.CookieStore;
const CookieStoreManagerImpl = impls.CookieStoreManager;
const CookieChangeEventImpl = impls.CookieChangeEvent;

// ============================================================================
// CookieStore InternalState Tests
// ============================================================================

test "CookieStore.InternalState - init and deinit" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    try std.testing.expectEqualStrings("example.com", internal.origin_host);
    try std.testing.expect(internal.is_secure_context);
    try std.testing.expect(internal.onchange_handler == null);
}

test "CookieStore.InternalState - non-secure context" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "localhost", false);
    defer internal.deinit();

    try std.testing.expect(!internal.is_secure_context);
}

test "CookieStore.InternalState - cookie jar integration" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    // Store a cookie in the jar
    var cookie = try cookiestore.Cookie.init(allocator, "test", "value");
    defer cookie.deinit();
    try cookie.setDomain("example.com");
    try cookie.setPath("/");
    try internal.cookie_jar.store(cookie);

    // Verify cookie count
    try std.testing.expectEqual(@as(usize, 1), internal.cookie_jar.cookies.items.len);
}

// ============================================================================
// CookieStoreManager InternalState Tests
// ============================================================================

test "CookieStoreManager.InternalState - init and deinit" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreManagerImpl.InternalState.init(allocator, "https://example.com/app/", true);
    defer internal.deinit();

    try std.testing.expectEqualStrings("https://example.com/app/", internal.scope_url.?);
    try std.testing.expect(internal.is_secure_context);
}

test "CookieStoreManager.InternalState - add subscription" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreManagerImpl.InternalState.init(allocator, "https://example.com/", true);
    defer internal.deinit();

    try internal.addSubscription("session", null);
    try std.testing.expectEqual(@as(usize, 1), internal.subscriptions.items.len);
    try std.testing.expectEqualStrings("session", internal.subscriptions.items[0].name.?);
}

test "CookieStoreManager.InternalState - subscription deduplication" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreManagerImpl.InternalState.init(allocator, "https://example.com/", true);
    defer internal.deinit();

    // Add same subscription twice
    try internal.addSubscription("session", null);
    try internal.addSubscription("session", null);

    // Should only have one
    try std.testing.expectEqual(@as(usize, 1), internal.subscriptions.items.len);
}

test "CookieStoreManager.InternalState - remove subscription" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreManagerImpl.InternalState.init(allocator, "https://example.com/", true);
    defer internal.deinit();

    try internal.addSubscription("session", null);
    try internal.addSubscription("other", null);
    try std.testing.expectEqual(@as(usize, 2), internal.subscriptions.items.len);

    internal.removeSubscription("session", null);
    try std.testing.expectEqual(@as(usize, 1), internal.subscriptions.items.len);
    try std.testing.expectEqualStrings("other", internal.subscriptions.items[0].name.?);
}

test "CookieStoreManager.InternalState - scope URL validation" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreManagerImpl.InternalState.init(allocator, "https://example.com/app/", true);
    defer internal.deinit();

    // Within scope
    try std.testing.expect(internal.isWithinScope("https://example.com/app/page"));
    try std.testing.expect(internal.isWithinScope("https://example.com/app/sub/page"));

    // Outside scope
    try std.testing.expect(!internal.isWithinScope("https://example.com/other/"));
    try std.testing.expect(!internal.isWithinScope("https://different.com/app/"));
}

test "CookieStoreManager.CookieSubscription - equality" {
    const allocator = std.testing.allocator;

    var sub1 = try CookieStoreManagerImpl.CookieSubscription.init(allocator, "session", null);
    defer sub1.deinit();

    var sub2 = try CookieStoreManagerImpl.CookieSubscription.init(allocator, "session", null);
    defer sub2.deinit();

    var sub3 = try CookieStoreManagerImpl.CookieSubscription.init(allocator, "other", null);
    defer sub3.deinit();

    try std.testing.expect(sub1.eql(sub2));
    try std.testing.expect(!sub1.eql(sub3));
}

// ============================================================================
// CookieChangeEvent InternalState Tests
// ============================================================================

test "CookieChangeEvent.InternalState - init and deinit" {
    const allocator = std.testing.allocator;

    const internal = try CookieChangeEventImpl.InternalState.init(allocator);
    defer internal.deinit();

    try std.testing.expectEqual(@as(usize, 0), internal.changed.items.len);
    try std.testing.expectEqual(@as(usize, 0), internal.deleted.items.len);
}

test "CookieChangeEvent.InternalState - add changed cookies" {
    const allocator = std.testing.allocator;

    const internal = try CookieChangeEventImpl.InternalState.init(allocator);
    defer internal.deinit();

    const item = cookiestore.CookieListItem{
        .name = try allocator.dupe(u8, "session"),
        .value = try allocator.dupe(u8, "abc123"),
        .allocator = allocator,
    };
    try internal.addChanged(item);

    try std.testing.expectEqual(@as(usize, 1), internal.changed.items.len);
    try std.testing.expectEqualStrings("session", internal.changed.items[0].name);
}

test "CookieChangeEvent.InternalState - add deleted cookies" {
    const allocator = std.testing.allocator;

    const internal = try CookieChangeEventImpl.InternalState.init(allocator);
    defer internal.deinit();

    const item = cookiestore.CookieListItem{
        .name = try allocator.dupe(u8, "old_cookie"),
        .value = try allocator.dupe(u8, ""),
        .allocator = allocator,
    };
    try internal.addDeleted(item);

    try std.testing.expectEqual(@as(usize, 1), internal.deleted.items.len);
    try std.testing.expectEqualStrings("old_cookie", internal.deleted.items[0].name);
}

// ============================================================================
// Memory Management Tests
// ============================================================================

test "CookieStore.InternalState - no memory leaks" {
    const allocator = std.testing.allocator;

    for (0..10) |_| {
        const internal = try CookieStoreImpl.InternalState.init(allocator, "localhost", true);

        // Add some cookies
        var cookie1 = try cookiestore.Cookie.init(allocator, "test1", "value1");
        defer cookie1.deinit();
        try cookie1.setDomain("localhost");
        try cookie1.setPath("/");
        try internal.cookie_jar.store(cookie1);

        var cookie2 = try cookiestore.Cookie.init(allocator, "test2", "value2");
        defer cookie2.deinit();
        try cookie2.setDomain("localhost");
        try cookie2.setPath("/");
        try internal.cookie_jar.store(cookie2);

        internal.deinit();
    }
}

test "CookieStoreManager.InternalState - no memory leaks" {
    const allocator = std.testing.allocator;

    for (0..10) |_| {
        const internal = try CookieStoreManagerImpl.InternalState.init(allocator, "https://example.com/", true);

        try internal.addSubscription("session", null);
        try internal.addSubscription("auth", "https://example.com/app/");

        internal.removeSubscription("session", null);

        internal.deinit();
    }
}

test "CookieChangeEvent.InternalState - no memory leaks" {
    const allocator = std.testing.allocator;

    for (0..10) |_| {
        const internal = try CookieChangeEventImpl.InternalState.init(allocator);

        const item1 = cookiestore.CookieListItem{
            .name = try allocator.dupe(u8, "cookie1"),
            .value = try allocator.dupe(u8, "value1"),
            .allocator = allocator,
        };
        try internal.addChanged(item1);

        const item2 = cookiestore.CookieListItem{
            .name = try allocator.dupe(u8, "cookie2"),
            .value = try allocator.dupe(u8, ""),
            .allocator = allocator,
        };
        try internal.addDeleted(item2);

        internal.deinit();
    }
}

// ============================================================================
// Cross-Component Integration Tests (without runtime)
// ============================================================================

test "Integration - CookieStore internal state with CookieJar" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    // Set a cookie using the algorithms
    try cookiestore.setCookie(allocator, &internal.cookie_jar, "example.com", .{
        .name = "session",
        .value = "abc123",
    });

    // Query the cookie
    var items = try cookiestore.queryCookies(
        allocator,
        &internal.cookie_jar,
        "example.com",
        "/",
        "session",
    );
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("session", items.items[0].name);
}

test "Integration - CookieStore internal state with change observer" {
    const allocator = std.testing.allocator;

    const internal = try CookieStoreImpl.InternalState.init(allocator, "example.com", true);
    defer internal.deinit();

    // Record a change
    var cookie = try cookiestore.Cookie.init(allocator, "test", "value");
    defer cookie.deinit();

    try internal.change_observer.recordChange(.changed, cookie);

    // Verify change was recorded
    try std.testing.expectEqual(@as(usize, 1), internal.change_observer.pending_changes.items.len);
}
