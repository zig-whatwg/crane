//! Nameless cookies: layered-cookies "Parse a Cookie" steps 7-12 (RFC 6265bis,
//! httpwg/http-extensions PR #1018 "Accept nameless cookies", 2020-01-10).
//! An explicitly empty name (`=value`) makes a nameless cookie, as Chrome
//! ships; this replaces codex-cookies Q5's browser-majority rejection
//! (2026-10-12) under the refined golden rule 2 (gr2audit, 2026-10-17).
const std = @import("std");
const cookiestore = @import("cookiestore");

test "an explicitly empty cookie name makes a nameless cookie" {
    const allocator = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "=value", "value" },
        .{ " =value", "value" },
        .{ "\t=with=equals", "with=equals" },
        .{ "===value", "==value" },
        .{ "=test2c; path=/", "test2c" },
    };
    for (cases) |c| {
        var parsed = (try cookiestore.parseCookie(allocator, c[0], "/")) orelse return error.TestExpectedCookie;
        defer parsed.deinit();
        try std.testing.expectEqualStrings("", parsed.cookie.name);
        try std.testing.expectEqualStrings(c[1], parsed.cookie.value);
    }
}

test "an empty name with an empty value is still failure (step 12)" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{ "=", " = ", "" }) |input| {
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
