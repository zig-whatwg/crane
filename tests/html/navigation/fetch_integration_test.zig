//! A navigation's fetch (HTML 7.4.5, "create navigation params by
//! fetching"): the request a navigation sends, and what a response tells the
//! commit. (html_core's own test blocks never run - `zig test` collects the
//! root module's only - so these live here.)

const std = @import("std");
const navigation_fetch = @import("html_core").navigation.fetch_integration;
const resultFromResponse = navigation_fetch.resultFromResponse;
const navigationRequest = navigation_fetch.navigationRequest;

test "navigationRequest - the referrer is the request's own copy" {
    const allocator = std.testing.allocator;
    var referrer = try allocator.dupe(u8, "http://a.test/page?pushed");
    const request = try navigationRequest(allocator, "http://a.test/next", .{ .referrer = referrer });
    defer request.deinit();
    // The caller's string can go: the request keeps its own.
    @memset(referrer, 'x');
    allocator.free(referrer);
    referrer = &.{};
    try std.testing.expectEqualStrings("http://a.test/page?pushed", request.referrer.url);
}

test "resultFromResponse - a redirect chain that crosses origins marks the result" {
    const allocator = std.testing.allocator;
    // Out and back again: the final URL is same origin with the first, and
    // the document is still "created via cross-origin redirects".
    const across = try navigation_fetch.InternalResponse.init(allocator);
    defer across.deinit();
    across.status = 200;
    try across.addUrl("http://a.test/start");
    try across.addUrl("https://b.test/redirect");
    try across.addUrl("http://a.test/final");
    var crossed = try resultFromResponse(allocator, "http://a.test/start", across, .{});
    defer crossed.deinit();
    try std.testing.expect(crossed.has_cross_origin_redirects);
    try std.testing.expectEqualStrings("http://a.test/final", crossed.final_url);

    // Redirects within one origin, and no redirect at all, do not.
    const within = try navigation_fetch.InternalResponse.init(allocator);
    defer within.deinit();
    within.status = 200;
    try within.addUrl("http://a.test/start");
    try within.addUrl("http://a.test/next");
    var same = try resultFromResponse(allocator, "http://a.test/start", within, .{});
    defer same.deinit();
    try std.testing.expect(!same.has_cross_origin_redirects);
}

test "fetchNavigationResource - a data: URL's body keeps its plus signs" {
    const allocator = std.testing.allocator;
    var result = try navigation_fetch.fetchNavigationResource(allocator, "data:text/html,<script>f(1 + 2)%3B</script>", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("<script>f(1 + 2);</script>", result.body.?);
}
