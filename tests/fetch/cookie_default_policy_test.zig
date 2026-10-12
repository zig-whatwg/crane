//! Browser-majority defaults keep an omitted or invalid SameSite unrestricted.
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

test "Default cookies survive cross-site retrieval and age while explicit Lax does not" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const request = try Request.init(allocator, "https://example.com/");
    defer request.deinit();
    request.cookie_jar = &jar;
    var headers = fetch.HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Set-Cookie", "default=1; Secure; Path=/");
    try headers.append("Set-Cookie", "invalid=1; Secure; Path=/; SameSite=bogus");
    try headers.append("Set-Cookie", "lax=1; Secure; Path=/; SameSite=Lax");
    try headers.append("Set-Cookie", "strict=1; Secure; Path=/; SameSite=Strict");
    try cookies.storeResponseCookies(allocator, request, &headers);
    for (jar.cookies.items) |*cookie| cookie.creation_time -= 180_000;
    try request.setOrigin("https://other.test");
    for ([_]bool{ false, true }) |navigation| {
        if (navigation) {
            request.mode = .navigate;
            request.destination = .document;
            request.top_level_navigation_initiator_origin = "https://other.test";
            try request.setMethod("POST");
        }
        const value = try cookies.requestCookieHeader(allocator, request);
        defer if (value) |v| allocator.free(v);
        try std.testing.expectEqualStrings("default=1; invalid=1", value orelse "");
    }
}

test "cross-site storage accepts Default without weakening explicit SameSite or Secure" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const request = try Request.init(allocator, "http://example.com/");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("http://other.test");
    var headers = fetch.HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Set-Cookie", "default=1; Path=/");
    try headers.append("Set-Cookie", "invalid=1; Path=/; SameSite=bogus");
    try headers.append("Set-Cookie", "lax=1; Path=/; SameSite=Lax");
    try headers.append("Set-Cookie", "strict=1; Path=/; SameSite=Strict");
    try headers.append("Set-Cookie", "none=1; Path=/; SameSite=None");
    try headers.append("Set-Cookie", "secure=1; Path=/; Secure");
    try cookies.storeResponseCookies(allocator, request, &headers);
    try std.testing.expectEqual(@as(usize, 2), jar.count());
    const value = try cookies.requestCookieHeader(allocator, request);
    defer if (value) |v| allocator.free(v);
    try std.testing.expectEqualStrings("default=1; invalid=1", value orelse "");
}
