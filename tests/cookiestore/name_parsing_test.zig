//! Browser-majority and split handling: codex-cookies Q5, 2026-10-12.
const std = @import("std");
const cookiestore = @import("cookiestore");

test "an explicitly empty cookie name is rejected" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{ "=value", " =value", "\t=with=equals", "===value" }) |input| {
        var parsed = try cookiestore.parseCookie(allocator, input, "/");
        defer if (parsed) |*cookie| cookie.deinit();
        try std.testing.expect(parsed == null);
    }
}

test "a token without equals retains the spec's nameless-cookie behavior" {
    const allocator = std.testing.allocator;
    var parsed = (try cookiestore.parseCookie(allocator, "  token  ;ignored=attribute", "/")).?;
    defer parsed.deinit();
    try std.testing.expectEqualStrings("", parsed.cookie.name);
    try std.testing.expectEqualStrings("token", parsed.cookie.value);
}
