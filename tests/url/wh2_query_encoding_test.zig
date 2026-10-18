//! Location.search supplies both a document encoding and query-state override.
const std = @import("std");
const testing = std.testing;
const url = @import("url");
const encoding = @import("encoding");
const parser = url.parser.basic_url_parser;

fn check(address: []const u8, input: []const u8, expected: []const u8, charset: *const encoding.Encoding) !void {
    var record = try parser.parse(testing.allocator, address, null);
    defer record.deinit();
    _ = try parser.parseWithEncodingAndStateOverride(testing.allocator, input, &record, .query, charset);
    try testing.expectEqualStrings(expected, record.query().?);
    try testing.expectEqualStrings("saved", record.fragment().?);
}

test "query state uses windows-1252 and preserves literal hash and spaces" {
    try check("https://example.test/p?old#saved", " \xc3\x9f# ", "%20%DF%23%20", &encoding.encoding.WINDOWS_1252);
}

test "query state keeps an empty query and uses UTF-8 by default" {
    try check("https://example.test/p?old#saved", "", "", &encoding.encoding.UTF_8);
    try check("https://example.test/p?old#saved", "\xc3\x9f", "%C3%9F", &encoding.encoding.UTF_8);
}

test "WebSocket and non-special queries force UTF-8 despite a legacy encoding" {
    try check("wss://example.test/p#saved", "\xc3\x9f", "%C3%9F", &encoding.encoding.WINDOWS_1252);
    try check("custom:opaque#saved", "\xc3\x9f", "%C3%9F", &encoding.encoding.WINDOWS_1252);
}
