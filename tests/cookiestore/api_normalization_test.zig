//! Cookie Store normalization runs before validation, lookup and deletion.
//! https://cookiestore.spec.whatwg.org/#normalize-a-cookie-name-or-value
const std = @import("std");
const cookies = @import("cookiestore");
const allocator = std.testing.allocator;
const host = "example.com";

fn freeItems(items: *std.ArrayListUnmanaged(cookies.CookieListItem)) void {
    for (items.items) |*item| item.deinit();
    items.deinit(allocator);
}

test "Cookie Store normalization trims only edge HTTP whitespace" {
    const cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = " \t name \t ", .expected = "name" },
        .{ .input = "\t \t", .expected = "" },
        .{ .input = "", .expected = "" },
        .{ .input = " a b\tc ", .expected = "a b\tc" },
        .{ .input = " \nname\r ", .expected = "\nname\r" },
        .{ .input = "\xc2\xa0name\xc2\xa0", .expected = "\xc2\xa0name\xc2\xa0" },
    };
    for (cases) |case| try std.testing.expectEqualStrings(case.expected, cookies.normalizeCookieNameOrValue(case.input));
}

test "Cookie Store set and query normalize names and values" {
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    try cookies.setCookie(allocator, &jar, host, .{ .name = " \t session\t ", .value = " \t a b\tc \t" });
    var items = try cookies.queryCookies(allocator, &jar, host, "/", "\t session ");
    defer freeItems(&items);
    try std.testing.expectEqual(@as(usize, 1), items.items.len);
    try std.testing.expectEqualStrings("session", items.items[0].name);
    try std.testing.expectEqualStrings("a b\tc", items.items[0].value);
}

test "Cookie Store rejects names and values empty after normalization" {
    const cases = [_]struct { name: []const u8, value: []const u8 }{
        .{ .name = "", .value = " " },
        .{ .name = " \t", .value = "" },
        .{ .name = "\t ", .value = " \t" },
        .{ .name = " \t", .value = "a=b" },
    };
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    for (cases) |case| {
        try std.testing.expectError(error.ValidationError, cookies.setCookie(allocator, &jar, host, .{ .name = case.name, .value = case.value }));
        try std.testing.expectEqual(@as(usize, 0), jar.count());
    }
}

test "Cookie Store whitespace normalization leaves forbidden controls invalid" {
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    for ([_][]const u8{ "\nname", "name\r", "\x0bname", "name\x0c", "name\x7f" }) |name| {
        try std.testing.expectError(error.ValidationError, cookies.setCookie(allocator, &jar, host, .{ .name = name, .value = "v" }));
    }
    try std.testing.expectEqual(@as(usize, 0), jar.count());
}

test "Cookie Store delete normalizes a named cookie" {
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    try cookies.setCookie(allocator, &jar, host, .{ .name = "session", .value = "v" });
    try cookies.deleteCookie(allocator, &jar, host, .{ .name = " \tsession\t " });
    try std.testing.expectEqual(@as(usize, 0), jar.count());
}

test "Cookie Store delete normalizes a whitespace-only name to the empty name" {
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    try cookies.setCookie(allocator, &jar, host, .{ .name = "", .value = "nameless" });
    try std.testing.expectEqual(@as(usize, 1), jar.count());
    try cookies.deleteCookie(allocator, &jar, host, .{ .name = " \t" });
    try std.testing.expectEqual(@as(usize, 0), jar.count());
}
