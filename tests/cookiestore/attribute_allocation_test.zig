//! Parsing and retrieval release partial cookie allocations on every failure.
const std = @import("std");
const cookiestore = @import("cookiestore");

fn parseDuplicateAttributes(allocator: std.mem.Allocator) !void {
    var parsed = (try cookiestore.parseCookie(allocator, "ck=value; Domain=example.com; Domain=sub.example.com; Path=/first; Path=/second", "/default/path/page")).?;
    defer parsed.deinit();
}

test "duplicate cookie attributes remain valid through every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseDuplicateAttributes, .{});
}

fn retrieveCookie(allocator: std.mem.Allocator) !void {
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    _ = try cookiestore.parseAndStoreCookie(allocator, &jar, "ck=value; Path=/dir", "/dir/page", .{
        .host = "example.com",
        .is_secure = true,
        .http_only_allowed = true,
    });
    const value = try cookiestore.generateCookieHeader(allocator, &jar, .{
        .host = "example.com",
        .path = "/dir/page",
        .is_http = true,
        .is_secure = true,
    });
    defer allocator.free(value);
    try std.testing.expectEqualStrings("ck=value", value);
}

test "cookie storage and retrieval release every partial clone" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, retrieveCookie, .{});
}
