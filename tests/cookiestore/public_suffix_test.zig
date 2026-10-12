//! Cookie Domain validation uses the URL Standard's complete public-suffix list.
const std = @import("std");
const cookiestore = @import("cookiestore");

test "cookie domains reject private, wildcard and unlisted public suffixes" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{ "github.io", "s3.amazonaws.com", "a.ck", "test" }) |suffix| {
        try std.testing.expect(try cookiestore.isPublicSuffix(allocator, suffix));
        var jar = cookiestore.CookieJar.init(allocator);
        defer jar.deinit();
        const host = try std.fmt.allocPrint(allocator, "tenant.{s}", .{suffix});
        defer allocator.free(host);
        const input = try std.fmt.allocPrint(allocator, "ck=1; Domain={s}", .{suffix});
        defer allocator.free(input);
        try std.testing.expectEqual(cookiestore.StoreResult.ignored, try cookiestore.parseAndStoreCookie(allocator, &jar, input, "/", .{
            .is_secure = true,
            .host = host,
            .http_only_allowed = true,
        }));
    }
}

test "public-suffix exceptions and IP literals are not suffixes" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{ "www.ck", "tenant.github.io", "127.0.0.1", "[::1]" }) |domain| {
        try std.testing.expect(!try cookiestore.isPublicSuffix(allocator, domain));
    }
}

test "a Domain equal to the public-suffix request host becomes host-only" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    try std.testing.expectEqual(cookiestore.StoreResult.stored, try cookiestore.parseAndStoreCookie(allocator, &jar, "ck=1; Domain=github.io", "/", .{
        .is_secure = true,
        .host = "github.io",
        .http_only_allowed = true,
    }));
    try std.testing.expect(jar.cookies.items[0].host_only);
}

test "Domain strips exactly one leading dot" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    try std.testing.expectEqual(cookiestore.StoreResult.ignored, try cookiestore.parseAndStoreCookie(allocator, &jar, "ck=1; Domain=..example.com", "/", .{
        .is_secure = true,
        .host = "www.example.com",
        .http_only_allowed = true,
    }));
}

test "schemeful cookie sites use the suffix beyond sixty-four labels" {
    // Both valid serialized hosts are shorter than 253 bytes. Their common
    // registrable domain is example.com, however many labels precede it.
    const prefix = "x." ** 70;
    try std.testing.expect(try cookiestore.sameSite(std.testing.allocator, "https://" ++ prefix ++ "a.example.com/", "https://" ++ prefix ++ "b.example.com/"));
}
