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

test "URLSearchParams - entries iterator" {
    const allocator = std.testing.allocator;
    const URLSearchParams = @import("../webidl/src/url/URLSearchParams.zig").URLSearchParams;
    
    var params = try URLSearchParams.initWithString(allocator, "a=1&b=2&a=3");
    defer params.deinit();
    
    var iter = params.entries();
    var count: usize = 0;
    
    while (iter.next()) |entry| {
        count += 1;
        if (count == 1) {
            try std.testing.expectEqualStrings("a", entry.name);
            try std.testing.expectEqualStrings("1", entry.value);
        } else if (count == 2) {
            try std.testing.expectEqualStrings("b", entry.name);
            try std.testing.expectEqualStrings("2", entry.value);
        } else if (count == 3) {
            try std.testing.expectEqualStrings("a", entry.name);
            try std.testing.expectEqualStrings("3", entry.value);
        }
    }
    
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "URLSearchParams - keys iterator" {
    const allocator = std.testing.allocator;
    const URLSearchParams = @import("../webidl/src/url/URLSearchParams.zig").URLSearchParams;
    
    var params = try URLSearchParams.initWithString(allocator, "a=1&b=2&c=3");
    defer params.deinit();
    
    var iter = params.keys();
    
    const key1 = iter.next().?;
    try std.testing.expectEqualStrings("a", key1);
    
    const key2 = iter.next().?;
    try std.testing.expectEqualStrings("b", key2);
    
    const key3 = iter.next().?;
    try std.testing.expectEqualStrings("c", key3);
    
    try std.testing.expect(iter.next() == null);
}

test "URLSearchParams - values iterator" {
    const allocator = std.testing.allocator;
    const URLSearchParams = @import("../webidl/src/url/URLSearchParams.zig").URLSearchParams;
    
    var params = try URLSearchParams.initWithString(allocator, "a=1&b=2&c=3");
    defer params.deinit();
    
    var iter = params.values();
    
    const val1 = iter.next().?;
    try std.testing.expectEqualStrings("1", val1);
    
    const val2 = iter.next().?;
    try std.testing.expectEqualStrings("2", val2);
    
    const val3 = iter.next().?;
    try std.testing.expectEqualStrings("3", val3);
    
    try std.testing.expect(iter.next() == null);
}

test "URLSearchParams - forEach" {
    const allocator = std.testing.allocator;
    const URLSearchParams = @import("../webidl/src/url/URLSearchParams.zig").URLSearchParams;
    
    var params = try URLSearchParams.initWithString(allocator, "a=1&b=2");
    defer params.deinit();
    
    const TestContext = struct {
        var call_count: usize = 0;
        fn callback(value: []const u8, name: []const u8, _: *const URLSearchParams) void {
            call_count += 1;
            if (call_count == 1) {
                std.testing.expectEqualStrings("a", name) catch unreachable;
                std.testing.expectEqualStrings("1", value) catch unreachable;
            } else if (call_count == 2) {
                std.testing.expectEqualStrings("b", name) catch unreachable;
                std.testing.expectEqualStrings("2", value) catch unreachable;
            }
        }
    };
    
    TestContext.call_count = 0;
    params.forEach(TestContext.callback);
    try std.testing.expectEqual(@as(usize, 2), TestContext.call_count);
}

test "URLSearchParams - default iterator (same as entries)" {
    const allocator = std.testing.allocator;
    const URLSearchParams = @import("../webidl/src/url/URLSearchParams.zig").URLSearchParams;
    
    var params = try URLSearchParams.initWithString(allocator, "x=100&y=200");
    defer params.deinit();
    
    var iter = params.iterator();
    
    const entry1 = iter.next().?;
    try std.testing.expectEqualStrings("x", entry1.name);
    try std.testing.expectEqualStrings("100", entry1.value);
    
    const entry2 = iter.next().?;
    try std.testing.expectEqualStrings("y", entry2.name);
    try std.testing.expectEqualStrings("200", entry2.value);
    
    try std.testing.expect(iter.next() == null);
}
