//! A cookie jar owns retrieved list storage; the caller owns serialized output.
const std = @import("std");
const cookiestore = @import("cookiestore");

fn seed(jar: *cookiestore.CookieJar) !void {
    try cookiestore.setCookie(std.testing.allocator, jar, "example.com", .{
        .name = "session",
        .value = "value",
    });
}

test "cookie header releases retrieved list through the jar allocator" {
    var jar = cookiestore.CookieJar.init(std.testing.allocator);
    defer jar.deinit();
    try seed(&jar);
    // A different output allocator must not absorb a jar-owned list free.
    var output = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer output.deinit();
    const value = try cookiestore.generateCookieHeader(output.allocator(), &jar, .{
        .host = "example.com",
        .path = "/",
        .is_http = true,
        .is_secure = true,
        .same_site = .strict_or_less,
    });
    try std.testing.expectEqualStrings("session=value", value);
}

test "cookie query releases retrieved list through the jar allocator" {
    var jar = cookiestore.CookieJar.init(std.testing.allocator);
    defer jar.deinit();
    try seed(&jar);
    var output = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer output.deinit();
    var values = try cookiestore.queryCookies(output.allocator(), &jar, "example.com", "/", null);
    defer {
        for (values.items) |*value| value.deinit();
        values.deinit(output.allocator());
    }
    try std.testing.expectEqual(@as(usize, 1), values.items.len);
    try std.testing.expectEqualStrings("session", values.items[0].name);
    try std.testing.expectEqualStrings("value", values.items[0].value);
}
