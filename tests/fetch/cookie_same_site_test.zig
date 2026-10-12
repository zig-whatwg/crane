//! RFC 6265bis 5.2/5.7/5.8 and Fetch 3.1: use the request's captured facts.
//! Browser deviation (2026-10-12), 2-1: default is None.
//! Firefox release laxByDefault=false:
//! https://github.com/mozilla-firefox/firefox/blob/release/modules/libpref/init/StaticPrefList.yaml
//! WebKit coreSameSitePolicy(nil) -> None:
//! https://github.com/WebKit/WebKit/blob/main/Source/WebCore/platform/network/cocoa/CookieCocoa.mm
//! Chromium GetEffectiveSameSite -> Lax:
//! https://github.com/chromium/chromium/blob/main/net/cookies/cookie_base.cc
const std = @import("std");
const fetch = @import("fetch");
const cookies = fetch.algorithms.cookies;
const Request = fetch.internal.InternalRequest;
const CookieJar = fetch.internal.CookieJar;

fn seed(jar: *CookieJar, url: []const u8) !void {
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, url);
    defer request.deinit();
    request.cookie_jar = jar;
    var headers = fetch.HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Set-Cookie", "strict=1; Secure; Path=/; SameSite=Strict");
    try headers.append("Set-Cookie", "lax=1; Secure; Path=/; SameSite=Lax");
    try headers.append("Set-Cookie", "default=1; Secure; Path=/");
    try headers.append("Set-Cookie", "none=1; Secure; Path=/; SameSite=None");
    try cookies.storeResponseCookies(allocator, request, &headers);
    try std.testing.expectEqual(@as(usize, 4), jar.count());
}

fn expectHeader(request: *const Request, expected: []const u8) !void {
    const allocator = std.testing.allocator;
    const value = (try cookies.requestCookieHeader(allocator, request)) orelse return error.MissingCookieHeader;
    defer allocator.free(value);
    try std.testing.expectEqualStrings(expected, value);
}

test "cookie requests compare schemeful registrable domains and ignore ports" {
    const allocator = std.testing.allocator;
    const cases = [_]struct { origin: []const u8, target: []const u8, expected: []const u8 }{
        .{ .origin = "https://www.example.com", .target = "https://sub.example.com/page", .expected = "strict=1; lax=1; default=1; none=1" },
        .{ .origin = "https://example.com:8443", .target = "https://example.com:9443/page", .expected = "strict=1; lax=1; default=1; none=1" },
        .{ .origin = "http://example.com", .target = "https://example.com/page", .expected = "default=1; none=1" },
        .{ .origin = "https://other.test", .target = "https://example.com/page", .expected = "default=1; none=1" },
        .{ .origin = "https://a.github.io", .target = "https://b.github.io/page", .expected = "default=1; none=1" },
        .{ .origin = "null", .target = "https://example.com/page", .expected = "default=1; none=1" },
    };
    for (cases) |case| {
        var jar = CookieJar.init(allocator);
        defer jar.deinit();
        try seed(&jar, case.target);
        const request = try Request.init(allocator, case.target);
        defer request.deinit();
        request.cookie_jar = &jar;
        try request.setOrigin(case.origin);
        try expectHeader(request, case.expected);
    }
}

test "a cross-site redirect taints a request that returns to its original site" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "https://example.com/");
    const request = try Request.init(allocator, "https://example.com/start");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("https://example.com");
    try request.addUrl("https://other.test/redirect");
    try request.addUrl("https://example.com/end");
    try expectHeader(request, "default=1; none=1");
}

test "safe cross-site top-level navigations send Lax cookies but nested ones do not" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "https://example.com/");
    const request = try Request.init(allocator, "https://example.com/");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("https://other.test");
    request.top_level_navigation_initiator_origin = "https://other.test";
    request.mode = .navigate;
    request.destination = .document;
    for ([_][]const u8{ "GET", "HEAD" }) |method| {
        try request.setMethod(method);
        try expectHeader(request, "lax=1; default=1; none=1");
    }
    request.destination = .iframe;
    request.top_level_navigation_initiator_origin = null;
    try expectHeader(request, "default=1; none=1");
}

test "same-site top-level navigation retains Strict cookies" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "https://example.com/");
    const request = try Request.init(allocator, "https://example.com/");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("https://www.example.com");
    request.top_level_navigation_initiator_origin = "https://www.example.com";
    request.mode = .navigate;
    request.destination = .document;
    try expectHeader(request, "strict=1; lax=1; default=1; none=1");
}

test "unsafe cross-site top-level navigation sends Default regardless of age" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "https://example.com/");
    const request = try Request.init(allocator, "https://example.com/");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("https://other.test");
    request.top_level_navigation_initiator_origin = "https://other.test";
    request.mode = .navigate;
    request.destination = .document;
    try request.setMethod("POST");
    try expectHeader(request, "default=1; none=1");
    for (jar.cookies.items) |*cookie| cookie.creation_time -= 120_001;
    try expectHeader(request, "default=1; none=1");
}

test "cross-site subresources cannot set explicit Strict or Lax but top-level responses can" {
    const allocator = std.testing.allocator;
    for ([_]bool{ false, true }) |top_level| {
        var jar = CookieJar.init(allocator);
        defer jar.deinit();
        const request = try Request.init(allocator, "https://example.com/");
        defer request.deinit();
        request.cookie_jar = &jar;
        try request.setOrigin("https://other.test");
        if (top_level) {
            request.mode = .navigate;
            request.destination = .document;
            request.top_level_navigation_initiator_origin = "https://other.test";
            try request.setMethod("POST");
        }
        var headers = fetch.HeaderList.init(allocator);
        defer headers.deinit();
        try headers.append("Set-Cookie", "strict=1; Secure; SameSite=Strict");
        try headers.append("Set-Cookie", "lax=1; Secure; SameSite=Lax");
        try headers.append("Set-Cookie", "default=1; Secure");
        try headers.append("Set-Cookie", "none=1; Secure; SameSite=None");
        try cookies.storeResponseCookies(allocator, request, &headers);
        try std.testing.expectEqual(@as(usize, if (top_level) 4 else 2), jar.count());
    }
}
