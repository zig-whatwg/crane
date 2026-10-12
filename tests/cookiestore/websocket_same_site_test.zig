//! WebSockets 2.2 maps ws/wss to HTTP schemes before cookie processing.
const std = @import("std");
const cookies = @import("cookiestore");

test "WebSocket cookie sites use HTTP schemes and registrable domains" {
    const cases = [_]struct { origin: ?[]const u8, target: []const u8, same_site: bool }{
        .{ .origin = "https://example.com", .target = "wss://example.com:9443/", .same_site = true },
        .{ .origin = "http://example.com", .target = "ws://sub.example.com:9000/", .same_site = true },
        .{ .origin = "https://www.example.com", .target = "wss://sub.example.com/", .same_site = true },
        .{ .origin = "http://example.com", .target = "wss://example.com/", .same_site = false },
        .{ .origin = "https://example.com", .target = "ws://example.com/", .same_site = false },
        .{ .origin = "https://a.github.io", .target = "wss://b.github.io/", .same_site = false },
        .{ .origin = "https://other.test", .target = "wss://example.com/", .same_site = false },
        .{ .origin = "https://[::1]:8443", .target = "wss://[::1]:9443/", .same_site = true },
        .{ .origin = "null", .target = "wss://example.com/", .same_site = false },
        .{ .origin = null, .target = "wss://example.com/", .same_site = true },
    };
    for (cases) |case| {
        try std.testing.expectEqual(case.same_site, try cookies.websocketSameSite(std.testing.allocator, case.origin, case.target));
    }
}

test "WebSocket cookie classification restricts retrieval and response storage" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{ "https://www.example.com", "https://other.test" }) |origin| {
        const same_site = try cookies.websocketSameSite(allocator, origin, "wss://example.com/");
        var source = cookies.CookieJar.init(allocator);
        defer source.deinit();
        var response = cookies.CookieJar.init(allocator);
        defer response.deinit();
        const lines = [_][]const u8{
            "strict=1; Secure; Path=/; SameSite=Strict",
            "lax=1; Secure; Path=/; SameSite=Lax",
            "default=1; Secure; Path=/",
            "none=1; Secure; Path=/; SameSite=None",
        };
        for (lines, 0..) |line, i| {
            _ = try cookies.parseAndStoreCookie(allocator, &source, line, "/", .{
                .host = "example.com",
                .is_secure = true,
                .http_only_allowed = true,
            });
            const result = try cookies.parseAndStoreCookie(allocator, &response, line, "/", .{
                .host = "example.com",
                .is_secure = true,
                .http_only_allowed = true,
                .same_site_strict_or_lax_allowed = same_site,
            });
            try std.testing.expectEqual(if (same_site or i >= 2) cookies.StoreResult.stored else cookies.StoreResult.ignored, result);
        }
        const value = try cookies.generateCookieHeader(allocator, &source, .{
            .host = "example.com",
            .is_secure = true,
            .is_http = true,
            .same_site = if (same_site) .strict_or_less else .unset_or_less,
        });
        defer allocator.free(value);
        try std.testing.expectEqualStrings(if (same_site) "strict=1; lax=1; default=1; none=1" else "default=1; none=1", value);
        try std.testing.expectEqual(@as(usize, if (same_site) 4 else 2), response.count());
    }
}
