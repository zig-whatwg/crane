//! Encoding callbacks operate on each fixed value, prefix and suffix.
const std = @import("std");
const up = @import("urlpattern");
const A = std.testing.allocator;

test "URLPattern encoding callbacks use URL parser states" {
    const cases = .{
        .{ up.canonicalize.canonicalizeHostname, "0x7f.1", "127.0.0.1" },
        .{ up.canonicalize.canonicalizeHostname, "%65XAMPLE.com", "example.com" },
        .{ up.canonicalize.canonicalizePathname, "/a/../b", "/b" },
        .{ up.canonicalize.canonicalizePathname, "/%2e/b", "/b" },
        .{ up.canonicalize.canonicalizePathname, "/a\\b", "/a/b" },
        .{ up.canonicalize.canonicalizePathname, "a\tb", "ab" },
        .{ up.canonicalize.canonicalizeOpaquePathname, "a\nb", "ab" },
        .{ up.canonicalize.canonicalizeSearch, "?q='", "?q=%27" },
        .{ up.canonicalize.canonicalizeHash, "#x", "#x" },
    };
    inline for (cases) |case| {
        const actual = try case[0](A, case[1]);
        defer A.free(actual);
        try std.testing.expectEqualStrings(case[2], actual);
    }
}

test "URLPattern IPv6 encoding validates a single character too" {
    if (up.canonicalize.canonicalizeIPv6Hostname(A, "g")) |value| {
        A.free(value);
        return error.TestUnexpectedResult;
    } else |err| try std.testing.expectEqual(error.InvalidIPv6, err);
}

test "URLPattern port callback uses the leading digit run" {
    const value = try up.canonicalizePort(A, "8\t0x", null);
    defer A.free(value);
    try std.testing.expectEqualStrings("80", value);
    try std.testing.expectError(error.InvalidPort, up.canonicalizePort(A, "65536", null));
    try std.testing.expectError(error.InvalidPort, up.canonicalizePort(A, "invalid80", null));
}

fn checkAllocation(allocator: std.mem.Allocator, callback: up.parser.EncodingCallback, input: []const u8) !void {
    const value = try callback(allocator, input);
    defer allocator.free(value);
}

test "URLPattern encoding callbacks release temporary URLs on allocation failure" {
    const cases = .{
        .{ up.canonicalizeProtocol, "https" },
        .{ up.canonicalizeHostname, "%65xample.com" },
        .{ up.canonicalizePathname, "a/../b" },
        .{ up.canonicalizeOpaquePathname, "hello world" },
        .{ up.canonicalizeSearch, "?q='" },
        .{ up.canonicalizeHash, "#hash" },
    };
    inline for (cases) |case| try std.testing.checkAllAllocationFailures(A, checkAllocation, .{ case[0], case[1] });
}

test "URLPattern protocol callback leaves delimiter stripping to init processing" {
    try std.testing.expectError(error.InvalidProtocol, up.canonicalizeProtocol(A, "https:"));
    var result = try up.process_init.process(A, .{ .protocol = "https:" }, .pattern);
    defer result.deinit();
    try std.testing.expectEqualStrings("https", result.init.protocol.?);
}
