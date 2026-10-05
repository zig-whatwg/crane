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

test "resultFromResponse - the content type is Fetch's extracted MIME type: the last valid Content-Type" {
    const allocator = std.testing.allocator;
    // cookies/resources/postToParent.py: `application/json` then
    // `text/html` - the document is HTML. The first header is not the type.
    const response = try navigation_fetch.InternalResponse.init(allocator);
    defer response.deinit();
    response.status = 200;
    try response.addUrl("http://a.test/page");
    try response.header_list.append("Content-Type", "application/json");
    try response.header_list.append("Content-Type", "text/html");
    var result = try resultFromResponse(allocator, "http://a.test/page", response, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("text/html", result.content_type.?);

    // One header with two values, the second invalid: the valid one stays
    // (fetch/content-type/response.window.js "text/html;", "text/plain"
    // style cases), and its charset parameter is kept.
    const charset = try navigation_fetch.InternalResponse.init(allocator);
    defer charset.deinit();
    charset.status = 200;
    try charset.addUrl("http://a.test/page");
    try charset.header_list.append("Content-Type", "text/html;charset=gbk, x");
    var kept = try resultFromResponse(allocator, "http://a.test/page", charset, .{});
    defer kept.deinit();
    try std.testing.expectEqualStrings("text/html;charset=gbk", kept.content_type.?);

    // No valid type: none, and the commit falls back as before.
    const none = try navigation_fetch.InternalResponse.init(allocator);
    defer none.deinit();
    none.status = 200;
    try none.addUrl("http://a.test/page");
    try none.header_list.append("Content-Type", "nonsense");
    var missing = try resultFromResponse(allocator, "http://a.test/page", none, .{});
    defer missing.deinit();
    try std.testing.expect(missing.content_type == null);
}
