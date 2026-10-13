//! Direct coverage of URLPattern §3.2, independent of regexp execution.
const std = @import("std");
const up = @import("urlpattern");
const A = std.testing.allocator;

test "URLPatternInit distinguishes missing and explicit empty patterns" {
    var result = try up.process_init.process(A, .{ .protocol = "https", .search = "?", .hash = "#" }, .pattern);
    defer result.deinit();
    try std.testing.expectEqual(@as(?[]const u8, null), result.init.pathname);
    try std.testing.expectEqualStrings("", result.init.search.?);
    try std.testing.expectEqualStrings("", result.init.hash.?);
}

test "URLPatternInit inherits parsed and escaped base components" {
    var result = try up.process_init.process(A, .{ .base_url = "HTTPS://user:pass@EXAMPLE.COM:443/a/+/b?q=*&v={x}#end" }, .pattern);
    defer result.deinit();
    try std.testing.expectEqualStrings("https", result.init.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.init.hostname.?);
    try std.testing.expectEqualStrings("", result.init.port.?);
    try std.testing.expectEqualStrings("/a/\\+/b", result.init.pathname.?);
    try std.testing.expectEqualStrings("q=\\*&v=\\{x\\}", result.init.search.?);
    try std.testing.expect(result.init.username == null and result.init.password == null);
}

test "URLPatternInit inherits credentials only for URL matching" {
    var result = try up.process_init.process(A, .{ .base_url = "https://user:pass@example.com/a", .pathname = "b" }, .url);
    defer result.deinit();
    try std.testing.expectEqualStrings("user", result.init.username.?);
    try std.testing.expectEqualStrings("pass", result.init.password.?);
    try std.testing.expectEqualStrings("/b", result.init.pathname.?);
    var overridden = try up.process_init.process(A, .{ .base_url = "https://user:pass@example.com/a", .username = "new" }, .url);
    defer overridden.deinit();
    try std.testing.expectEqualStrings("", overridden.init.password.?);
}

test "URLPatternInit resolves only relative pattern paths" {
    const cases = [_][2][]const u8{
        .{ "child", "/a/child" },
        .{ "\\/child", "\\/child" },
        .{ "{/child}", "{/child}" },
        .{ "/child", "/child" },
    };
    for (cases) |case| {
        var result = try up.process_init.process(A, .{ .pathname = case[0], .base_url = "https://example.com/a/b" }, .pattern);
        defer result.deinit();
        try std.testing.expectEqualStrings(case[1], result.init.pathname.?);
    }
}

test "URLPatternInit canonicalizes URL input after stripping one delimiter" {
    var result = try up.process_init.process(A, .{ .protocol = "HTTPS:", .hostname = "EXAMPLE.COM", .port = "443", .pathname = "/a/../b", .search = "??q='", .hash = "##x" }, .url);
    defer result.deinit();
    try std.testing.expectEqualStrings("https", result.init.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.init.hostname.?);
    try std.testing.expectEqualStrings("", result.init.port.?);
    try std.testing.expectEqualStrings("/b", result.init.pathname.?);
    try std.testing.expectEqualStrings("?q=%27", result.init.search.?);
    try std.testing.expectEqualStrings("#x", result.init.hash.?);
}

fn allocationFailures(allocator: std.mem.Allocator) !void {
    var result = try up.process_init.process(allocator, .{ .base_url = "https://example.com/a/*/b", .pathname = "../x", .search = "?a'b" }, .url);
    defer result.deinit();
}

test "URLPatternInit releases temporary parser storage on every failure" {
    try std.testing.checkAllAllocationFailures(A, allocationFailures, .{});
}
