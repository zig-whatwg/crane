//! A cookie site must not lose its suffix at an implementation label limit.
const std = @import("std");
const url = @import("url");

fn expectSuffix(host: []const u8, suffix: []const u8, registrable: []const u8) !void {
    const allocator = std.testing.allocator;
    const actual_suffix = (try url.public_suffix.getPublicSuffix(allocator, .{ .domain = host })).?;
    defer allocator.free(actual_suffix);
    try std.testing.expectEqualStrings(suffix, actual_suffix);
    const registrable_result = try url.public_suffix.getRegistrableDomain(allocator, .{ .domain = host });
    try std.testing.expect(registrable_result != null);
    const actual_registrable = registrable_result.?;
    defer allocator.free(actual_registrable);
    try std.testing.expectEqualStrings(registrable, actual_registrable);
}

test "exact public suffix survives more than sixty-four labels" {
    try expectSuffix("x." ** 70 ++ "example.com", "com", "example.com");
}

test "private public suffix survives more than sixty-four labels" {
    try expectSuffix("x." ** 70 ++ "tenant.github.io", "github.io", "tenant.github.io");
}

test "wildcard public suffix survives more than sixty-four labels" {
    try expectSuffix("x." ** 70 ++ "tenant.a.ck", "a.ck", "tenant.a.ck");
}

test "exception public suffix survives more than sixty-four labels" {
    try expectSuffix("x." ** 70 ++ "www.ck", "ck", "www.ck");
}

test "unknown suffix and trailing dot survive more than sixty-four labels" {
    try expectSuffix("x." ** 70 ++ "example.invalid.", "invalid.", "example.invalid.");
}

test "public suffix remains correct beyond the old serialized scratch size" {
    try expectSuffix("subdomain." ** 40 ++ "example.co.uk", "co.uk", "example.co.uk");
}
