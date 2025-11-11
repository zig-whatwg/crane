const std = @import("std");
const URL = @import("../webidl/src/url/URL.zig").URL;
const URLSearchParams = @import("../webidl/src/url/URLSearchParams.zig").URLSearchParams;

test "URL - basic initialization" {
    const allocator = std.testing.allocator;

    // Test: Simple URL construction
    var url = try URL.init(allocator, "https://example.com/path?query=value#fragment", null);
    defer url.deinit();

    const href = try url.href();
    defer allocator.free(href);

    try std.testing.expect(href.len > 0);
}

test "URL - initialization with base" {
    const allocator = std.testing.allocator;

    var url = try URL.init(allocator, "/relative", "https://example.com");
    defer url.deinit();

    const href = try url.href();
    defer allocator.free(href);

    // Should resolve to https://example.com/relative
    try std.testing.expect(std.mem.indexOf(u8, href, "example.com") != null);
}

test "URL.parse - returns null on failure" {
    const allocator = std.testing.allocator;

    // Valid URL should parse
    if (URL.parse(allocator, "https://test.com", null)) |url| {
        defer url.deinit();
        const href = try url.href();
        defer allocator.free(href);
        try std.testing.expect(href.len > 0);
    } else {
        try std.testing.expect(false); // Should not happen
    }

    // Invalid relative URL without base should return null
    const result = URL.parse(allocator, "/relative", null);
    try std.testing.expect(result == null);
}

test "URL.canParse - boolean result" {
    const allocator = std.testing.allocator;

    // Valid URL
    try std.testing.expect(URL.canParse(allocator, "https://example.com", null) == true);

    // Invalid relative URL without base
    try std.testing.expect(URL.canParse(allocator, "/relative", null) == false);
}

test "URL.toJSON" {
    const allocator = std.testing.allocator;

    var url = try URL.init(allocator, "https://json.example", null);
    defer url.deinit();

    const json = try url.toJSON();
    defer allocator.free(json);

    try std.testing.expect(std.mem.eql(u8, json, "https://json.example/"));
}

test "URL.searchParams - access query object" {
    const allocator = std.testing.allocator;

    var url = try URL.init(allocator, "https://example.com?a=b&c=d", null);
    defer url.deinit();

    const params = url.searchParams();

    // Should have parsed 2 parameters
    try std.testing.expectEqual(@as(usize, 2), params.size());
}

test "URLSearchParams - basic initialization" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.init(allocator);
    defer params.deinit();

    try std.testing.expectEqual(@as(usize, 0), params.size());
}

test "URLSearchParams - initialize with string" {
    const allocator = std.testing.allocator;

    var params = try URLSearchParams.initWithString(allocator, "key1=value1&key2=value2");
    defer params.deinit();

    try std.testing.expectEqual(@as(usize, 2), params.size());
}
