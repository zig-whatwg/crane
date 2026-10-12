//! RFC 6265bis 5.6: each duplicate attribute is parsed independently.
const std = @import("std");
const cookiestore = @import("cookiestore");

test "an empty final Domain attribute restores a host-only cookie" {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    const stored = try cookiestore.parseAndStoreCookie(allocator, &jar, "ck=1; Domain=example.com; Domain=", "/dir/page", .{
        .is_secure = true,
        .host = "www.example.com",
        .http_only_allowed = true,
    });
    try std.testing.expectEqual(cookiestore.StoreResult.stored, stored);
    try std.testing.expectEqual(@as(usize, 1), jar.count());
    try std.testing.expect(jar.cookies.items[0].host_only);
    try std.testing.expectEqualStrings("www.example.com", jar.cookies.items[0].domain.?);
}

test "an invalid final Path attribute selects the request default path" {
    for ([_][]const u8{ "", "relative", "bare" }) |last_path| {
        const allocator = std.testing.allocator;
        const input = try std.fmt.allocPrint(allocator, "ck=1; Path=/first; Path={s}", .{last_path});
        defer allocator.free(input);
        var parsed = (try cookiestore.parseCookie(allocator, input, "/dir/page")).?;
        defer parsed.deinit();
        try std.testing.expectEqualStrings("/dir", parsed.cookie.path);
    }
}

test "an invalid final SameSite attribute selects Default" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{ "None", "Strict", "Lax" }) |first| {
        const input = try std.fmt.allocPrint(allocator, "ck=1; Secure; SameSite={s}; SameSite=unknown", .{first});
        defer allocator.free(input);
        var parsed = (try cookiestore.parseCookie(allocator, input, "/")).?;
        defer parsed.deinit();
        try std.testing.expectEqual(cookiestore.SameSite.unset, parsed.cookie.same_site);
    }
}
