//! Request cookie work depends on relevant cookies and distinct sites.
const std = @import("std");
const fetch = @import("fetch");
const cookies = fetch.algorithms.cookies;
const Request = fetch.internal.InternalRequest;
const CookieJar = fetch.internal.CookieJar;

fn seed(jar: *CookieJar, target: []const u8) !void {
    const request = try Request.init(std.testing.allocator, target);
    defer request.deinit();
    request.cookie_jar = jar;
    var headers = fetch.HeaderList.init(std.testing.allocator);
    defer headers.deinit();
    try headers.append("Set-Cookie", "strict=1; Secure; Path=/; SameSite=Strict");
    try cookies.storeResponseCookies(std.testing.allocator, request, &headers);
}

test "an empty or unrelated jar requires no request cookie allocation" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const request = try Request.init(allocator, "https://sub.example.com/page");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("https://www.example.com");
    for (0..2) |i| {
        if (i == 1) try seed(&jar, "https://unrelated.test/");
        var denied = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
        try std.testing.expect(try cookies.requestCookieHeader(denied.allocator(), request) == null);
        try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    }
}

test "repeated redirect hosts do not repeat cookie site allocations" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "https://sub.example.com/");
    const request = try Request.init(allocator, "https://sub.example.com/start");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("https://www.example.com");

    var direct = std.testing.FailingAllocator.init(allocator, .{});
    const first = (try cookies.requestCookieHeader(direct.allocator(), request)).?;
    defer direct.allocator().free(first);
    try std.testing.expectEqualStrings("strict=1", first);

    for (0..8) |_| try request.addUrl("https://sub.example.com/redirect");
    var redirected = std.testing.FailingAllocator.init(allocator, .{});
    const last = (try cookies.requestCookieHeader(redirected.allocator(), request)).?;
    defer redirected.allocator().free(last);
    try std.testing.expectEqualStrings("strict=1", last);
    try std.testing.expectEqual(direct.alloc_index, redirected.alloc_index);
}

fn requestWithAllocationFailures(output: std.mem.Allocator) !void {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    try seed(&jar, "https://third.example.com/");
    const request = try Request.init(allocator, "https://first.example.com/");
    defer request.deinit();
    request.cookie_jar = &jar;
    try request.setOrigin("https://www.example.com");
    try request.addUrl("https://second.example.com/");
    try request.addUrl("https://third.example.com/");
    const value = (try cookies.requestCookieHeader(output, request)).?;
    defer output.free(value);
    try std.testing.expectEqualStrings("strict=1", value);
}

test "request site comparison releases all allocations on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, requestWithAllocationFailures, .{});
}

test "request cookie host shortcut includes Domain cookies on a subdomain" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    const request = try Request.init(allocator, "https://example.com/");
    defer request.deinit();
    request.cookie_jar = &jar;
    var headers = fetch.HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Set-Cookie", "shared=1; Secure; Path=/; Domain=example.com; SameSite=Strict");
    try cookies.storeResponseCookies(allocator, request, &headers);
    try request.setOrigin("https://example.com");
    try request.addUrl("https://sub.example.com/");
    const value = (try cookies.requestCookieHeader(allocator, request)).?;
    defer allocator.free(value);
    try std.testing.expectEqualStrings("shared=1", value);
}
