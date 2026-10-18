//! A Request constructor's copy of a top-level navigation request - a
//! service worker's fetch(event.request), whose destination step 12 makes ""
//! - is still a top-level navigation for SameSite cookies, as Chrome, Firefox
//! and Safari treat it (navigation-sets-cookie.https.html's "Cross-site
//! top-level with passthrough service worker POST ...",
//! same-site-cookies.https.html's "cross-site, window.open with
//! passthrough"; whatwg/fetch#1327 - the spec has no "main frame navigation"
//! concept yet): a cross-site safe one sends Lax cookies, and its response
//! may set Strict and Lax ones. Without the bit, a navigate-mode request
//! with no destination is a cross-site subresource request.
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
}

/// A worker's copy of a cross-site top-level navigation, made by the Request
/// constructor: mode "navigate", no destination, the navigation's origin.
fn passthrough(allocator: std.mem.Allocator, jar: *CookieJar, main_frame: bool) !*Request {
    const request = try Request.init(allocator, "https://example.com/");
    errdefer request.deinit();
    request.cookie_jar = jar;
    try request.setOrigin("https://other.test");
    request.mode = .navigate;
    request.destination = .empty;
    request.main_frame_navigation = main_frame;
    return request;
}

test "a passthrough copy of a cross-site top-level GET navigation sends Lax cookies" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "https://example.com/");
    for ([_]bool{ true, false }) |main_frame| {
        const request = try passthrough(allocator, &jar, main_frame);
        defer request.deinit();
        const value = (try cookies.requestCookieHeader(allocator, request)).?;
        defer allocator.free(value);
        try std.testing.expectEqualStrings(if (main_frame) "lax=1; default=1; none=1" else "default=1; none=1", value);
    }
}

test "a passthrough copy of a cross-site top-level POST navigation may set Strict and Lax cookies" {
    const allocator = std.testing.allocator;
    for ([_]bool{ true, false }) |main_frame| {
        var jar = CookieJar.init(allocator);
        defer jar.deinit();
        const request = try passthrough(allocator, &jar, main_frame);
        defer request.deinit();
        try request.setMethod("POST");
        var headers = fetch.HeaderList.init(allocator);
        defer headers.deinit();
        try headers.append("Set-Cookie", "strict=1; Secure; SameSite=Strict");
        try headers.append("Set-Cookie", "lax=1; Secure; SameSite=Lax");
        try headers.append("Set-Cookie", "default=1; Secure");
        try headers.append("Set-Cookie", "none=1; Secure; SameSite=None");
        try cookies.storeResponseCookies(allocator, request, &headers);
        try std.testing.expectEqual(@as(usize, if (main_frame) 4 else 2), jar.count());
    }
}

test "the bit is copied by clone" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const request = try passthrough(allocator, &jar, true);
    defer request.deinit();
    const copy = try request.clone();
    defer copy.deinit();
    try std.testing.expect(copy.main_frame_navigation);
}
