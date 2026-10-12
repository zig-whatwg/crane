//! RFC 6265bis 5.8.3: order cookies by path length, then creation time.
const std = @import("std");
const cookiestore = @import("cookiestore");

test "longer serialized cookie paths sort first even at equal segment count" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    for ([_][]const u8{ "short=1; Path=/dir/", "long=1; Path=/dir/page" }) |input| {
        _ = try cookiestore.parseAndStoreCookie(allocator, &jar, input, "/dir/page", .{
            .is_secure = true,
            .host = "example.com",
            .http_only_allowed = true,
        });
    }
    // Explicit time ordering makes the test independent of clock resolution.
    jar.cookies.items[0].creation_time = 1;
    jar.cookies.items[1].creation_time = 2;
    const header = try cookiestore.generateCookieHeader(allocator, &jar, .{
        .host = "example.com",
        .path = "/dir/page",
        .is_http = true,
        .is_secure = true,
    });
    defer allocator.free(header);
    try std.testing.expectEqualStrings("long=1; short=1", header);
}

test "replacement retains order when creation timestamps have the same millisecond" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    const options: cookiestore.StoreOptions = .{ .host = "example.com", .is_secure = true, .http_only_allowed = true };
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "first=old; Path=/", "/", options);
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "second=1; Path=/", "/", options);
    for (jar.cookies.items) |*cookie| cookie.creation_time = 1;
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "first=new; Path=/", "/", options);
    const header = try cookiestore.generateCookieHeader(allocator, &jar, .{
        .host = "example.com",
        .is_http = true,
        .is_secure = true,
    });
    defer allocator.free(header);
    try std.testing.expectEqualStrings("first=new; second=1", header);
}
