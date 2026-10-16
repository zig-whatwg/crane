//! Prefix validation follows Cookie Store name/value normalization.
const std = @import("std");
const cookies = @import("cookiestore");
const allocator = std.testing.allocator;

test "Cookie Store normalizes reserved names before prefix validation" {
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    for ([_][]const u8{ "  __Http-token", "\t__hTtP-token", " __Host-Http-token\t", "\t__HOST-HTTP-token " }) |name| {
        try std.testing.expectError(error.ValidationError, cookies.setCookie(allocator, &jar, "example.com", .{ .name = name, .value = "v" }));
        try std.testing.expectEqual(@as(usize, 0), jar.count());
    }
}

test "Cookie Store rejects every reserved prefix in normalized nameless values" {
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    for ([_][]const u8{ " \t__Host-token", " \t__sEcUrE-token", " \t__Http-token", " \t__Host-Http-token" }) |value| {
        try std.testing.expectError(error.ValidationError, cookies.setCookie(allocator, &jar, "example.com", .{ .name = " \t", .value = value }));
        try std.testing.expectEqual(@as(usize, 0), jar.count());
    }
}

test "Cookie Store validates the normalized Host prefix against domain and path" {
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    try std.testing.expectError(error.ValidationError, cookies.setCookie(allocator, &jar, "example.com", .{
        .name = " \t__Host-token ",
        .value = "v",
        .domain = "example.com",
    }));
    try std.testing.expectError(error.ValidationError, cookies.setCookie(allocator, &jar, "example.com", .{
        .name = " \t__hOsT-token ",
        .value = "v",
        .path = "/other",
    }));
    try std.testing.expectEqual(@as(usize, 0), jar.count());
    try cookies.setCookie(allocator, &jar, "example.com", .{ .name = " \t__Host-token ", .value = " v " });
    try std.testing.expectEqualStrings("__Host-token", jar.cookies.items[0].name);
    try std.testing.expectEqualStrings("v", jar.cookies.items[0].value);
    try std.testing.expect(jar.cookies.items[0].secure);
    try std.testing.expect(jar.cookies.items[0].host_only);
}
