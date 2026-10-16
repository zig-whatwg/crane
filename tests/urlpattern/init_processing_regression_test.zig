//! URLPatternInit defaults and base-URL inheritance are independent of matching.
const std = @import("std");
const up = @import("urlpattern");

test "URLPatternInit defaults every absent component to a wildcard" {
    var pattern = try up.URLPattern.create(std.testing.allocator, .{ .init = .{ .protocol = "https" } }, .{});
    defer pattern.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("*", pattern.pathname.pattern_string);
    try std.testing.expectEqualStrings("*", pattern.hostname.pattern_string);
    try std.testing.expectEqualStrings("*", pattern.port.pattern_string);
}

test "URLPatternInit inherits parsed and pattern-escaped base components" {
    var pattern = try up.URLPattern.create(std.testing.allocator, .{ .init = .{
        .hash = "section",
        .base_url = "HTTPS://EXAMPLE.COM:443/a/+/b?q=*&v={x}",
    } }, .{});
    defer pattern.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    try std.testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    try std.testing.expectEqualStrings("", pattern.port.pattern_string);
    try std.testing.expectEqualStrings("/a/\\+/b", pattern.pathname.pattern_string);
    try std.testing.expectEqualStrings("q=\\*&v=\\{x\\}", pattern.search.pattern_string);
    try std.testing.expectEqualStrings("*", pattern.username.pattern_string);
    try std.testing.expectEqualStrings("*", pattern.password.pattern_string);
}

test "URLPatternInit resolves relative paths against the base directory" {
    const cases = [_][2][]const u8{
        .{ "child", "/a/child" },
        .{ "../child", "/child" },
        .{ "{/child}", "/child" },
        .{ "\\/child", "/child" },
    };
    for (cases) |case| {
        var pattern = try up.URLPattern.create(std.testing.allocator, .{ .init = .{ .pathname = case[0], .base_url = "https://example.com/a/b" } }, .{});
        defer pattern.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(case[1], pattern.pathname.pattern_string);
    }
}

test "URLPattern input canonicalization uses parsed URL strings and dictionary inheritance" {
    var pattern = try up.URLPattern.create(std.testing.allocator, .{ .init = .{ .protocol = "https", .hostname = "example.com", .pathname = "/b" } }, .{});
    defer pattern.deinit(std.testing.allocator);
    try std.testing.expect(up.testMatch(std.testing.allocator, &pattern, "HTTPS://EXAMPLE.COM:443/a/../b", null));
    try std.testing.expect(up.testMatch(std.testing.allocator, &pattern, "../b", "https://example.com/a/c"));
    try std.testing.expect(up.testMatchInput(std.testing.allocator, &pattern, .{ .init = .{ .hostname = "EXAMPLE.COM", .pathname = "../b", .baseURL = "https://old.example/a/c" } }, null));
    try std.testing.expect(!up.testMatch(std.testing.allocator, &pattern, "not a URL", null));
}
