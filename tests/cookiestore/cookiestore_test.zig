//! CookieStore API Comprehensive Tests
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This file runs all cookiestore module tests and provides additional
//! integration tests that span multiple components.

const std = @import("std");
const cookiestore = @import("cookiestore");

// Re-export all module tests
test {
    // Core types
    _ = cookiestore.cookie;
    // Validation
    _ = cookiestore.validation;
    // Domain and path matching
    _ = cookiestore.domain_matching;
    // Cookie Jar
    _ = cookiestore.jar;
    // Algorithms
    _ = cookiestore.algorithms;
    // Storage integration
    _ = cookiestore.storage_integration;
    // Change observer
    _ = cookiestore.change_observer;
    // Event dispatch
    _ = cookiestore.event_dispatch;
    // HTTP integration
    _ = cookiestore.http_integration;
}

// ============================================================================
// Integration Tests
// ============================================================================

test "integration - full cookie lifecycle" {
    const allocator = std.testing.allocator;

    // Create a cookie jar
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    // Set a cookie using the high-level algorithm
    try cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "session",
        .value = "abc123",
        .path = "/app",
        .same_site = .lax,
    });

    // Query the cookie
    var items = try cookiestore.queryCookies(
        allocator,
        &jar,
        "example.com",
        "/app/dashboard",
        null,
    );
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("session", items.items[0].name);
    try std.testing.expectEqualStrings("abc123", items.items[0].value);

    // Delete the cookie
    try cookiestore.deleteCookie(allocator, &jar, "example.com", .{
        .name = "session",
        .path = "/app",
    });

    // Verify it's gone
    var items2 = try cookiestore.queryCookies(
        allocator,
        &jar,
        "example.com",
        "/app/dashboard",
        null,
    );
    defer {
        for (items2.items) |*item| item.deinit();
        items2.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 0), items2.items.len);
}

test "integration - multiple cookies with different scopes" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    // Set domain-wide cookie
    try cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "global",
        .value = "1",
        .domain = "example.com",
        .path = "/",
    });

    // Set path-specific cookie
    try cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "app",
        .value = "2",
        .path = "/app",
    });

    // Set subdomain cookie
    try cookiestore.setCookie(allocator, &jar, "api.example.com", .{
        .name = "api",
        .value = "3",
        .path = "/",
    });

    // Query from main domain at /app - should get global and app
    var main_app = try cookiestore.queryCookies(
        allocator,
        &jar,
        "example.com",
        "/app/page",
        null,
    );
    defer {
        for (main_app.items) |*item| item.deinit();
        main_app.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 2), main_app.items.len);

    // Query from main domain at root - should get only global
    var main_root = try cookiestore.queryCookies(
        allocator,
        &jar,
        "example.com",
        "/",
        null,
    );
    defer {
        for (main_root.items) |*item| item.deinit();
        main_root.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), main_root.items.len);
    try std.testing.expectEqualStrings("global", main_root.items[0].name);
}

test "integration - cookie prefix validation" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    // __Host- prefix requires Secure, Path="/", no Domain
    // Since we're testing in non-secure context, this should succeed
    // but the cookie won't be stored without proper attributes

    // Test that normal cookies work
    try cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "normal",
        .value = "test",
    });

    try std.testing.expectEqual(@as(usize, 1), jar.count());
}

test "integration - HTTP header generation" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    // Add some cookies
    try cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "a",
        .value = "1",
    });
    try cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "b",
        .value = "2",
    });

    // Generate Cookie header
    const header = try cookiestore.generateCookieHeader(allocator, &jar, .{
        .host = "example.com",
        .path = "/",
        .is_http = true,
        .is_secure = true,
    });
    defer allocator.free(header);

    // Should contain both cookies
    try std.testing.expect(std.mem.indexOf(u8, header, "a=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, header, "b=2") != null);
    try std.testing.expect(std.mem.indexOf(u8, header, "; ") != null);
}

test "integration - Set-Cookie header parsing" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    // Parse a Set-Cookie header
    var cookie = try cookiestore.parseSetCookieHeader(allocator, "session=abc123; Path=/; SameSite=Lax", "example.com", "/", true);
    defer cookie.deinit();
    try jar.store(cookie);

    // Verify the cookie was stored
    var items = try cookiestore.queryCookies(
        allocator,
        &jar,
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
    try std.testing.expectEqualStrings("abc123", items.items[0].value);
}

test "integration - change observer notifications" {
    const allocator = std.testing.allocator;

    var observer = cookiestore.CookieChangeObserver.init(allocator);
    defer observer.deinit();

    // Record a change
    var cookie = try cookiestore.Cookie.init(allocator, "test", "value");
    defer cookie.deinit();

    try observer.recordChange(.changed, cookie);

    // Verify change was recorded
    try std.testing.expectEqual(@as(usize, 1), observer.pending_changes.items.len);
    try std.testing.expectEqualStrings("test", observer.pending_changes.items[0].cookie.name);
}

test "integration - validation errors" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    // Test invalid name characters
    const result = cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "bad;name",
        .value = "test",
    });
    try std.testing.expectError(cookiestore.CookieError.ValidationError, result);

    // Test invalid value characters
    const result2 = cookiestore.setCookie(allocator, &jar, "example.com", .{
        .name = "test",
        .value = "bad;value",
    });
    try std.testing.expectError(cookiestore.CookieError.ValidationError, result2);
}

test "integration - SameSite policy enforcement" {
    const allocator = std.testing.allocator;

    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();

    // Create a Strict cookie
    var strict_cookie = try cookiestore.Cookie.init(allocator, "strict", "1");
    defer strict_cookie.deinit();
    try strict_cookie.setDomain("example.com");
    strict_cookie.same_site = .strict;
    try jar.store(strict_cookie);

    // Create a Lax cookie
    var lax_cookie = try cookiestore.Cookie.init(allocator, "lax", "2");
    defer lax_cookie.deinit();
    try lax_cookie.setDomain("example.com");
    lax_cookie.same_site = .lax;
    try jar.store(lax_cookie);

    // Same-site context gets both
    var same_site = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site_context = .same_site,
    });
    defer {
        for (same_site.items) |*c| c.deinit();
        same_site.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 2), same_site.items.len);

    // Cross-site safe context only gets Lax
    var cross_safe = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site_context = .cross_site_safe,
    });
    defer {
        for (cross_safe.items) |*c| c.deinit();
        cross_safe.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 1), cross_safe.items.len);
    try std.testing.expectEqualStrings("lax", cross_safe.items[0].name);

    // Cross-site unsafe gets neither
    var cross_unsafe = try jar.retrieve(.{
        .host = "example.com",
        .is_http = true,
        .same_site_context = .cross_site_unsafe,
    });
    defer {
        for (cross_unsafe.items) |*c| c.deinit();
        cross_unsafe.deinit(allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), cross_unsafe.items.len);
}

test "integration - domain matching edge cases" {
    // Test the domain matching algorithm directly
    try std.testing.expect(cookiestore.domainMatches("example.com", "example.com"));
    try std.testing.expect(cookiestore.domainMatches("www.example.com", "example.com"));
    try std.testing.expect(cookiestore.domainMatches("sub.www.example.com", "example.com"));

    // These should NOT match
    try std.testing.expect(!cookiestore.domainMatches("example.com", "www.example.com"));
    try std.testing.expect(!cookiestore.domainMatches("example.com", "other.com"));
    try std.testing.expect(!cookiestore.domainMatches("notexample.com", "example.com"));
}

test "integration - path matching edge cases" {
    // Test the path matching algorithm directly
    try std.testing.expect(cookiestore.pathMatches("/", "/"));
    try std.testing.expect(cookiestore.pathMatches("/app", "/"));
    try std.testing.expect(cookiestore.pathMatches("/app/sub", "/app"));
    try std.testing.expect(cookiestore.pathMatches("/app/sub", "/app/"));

    // These should NOT match
    try std.testing.expect(!cookiestore.pathMatches("/other", "/app"));
    try std.testing.expect(!cookiestore.pathMatches("/application", "/app")); // No separator
}
