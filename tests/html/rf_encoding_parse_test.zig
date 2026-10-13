//! Moving URL reflection's helper preserves document-relative encoding.
const std = @import("std");
const dom = @import("dom");
const fixture = @import("rf_fixture.zig");

test "DOM encoding-parse-and-serialize uses the node document's base and encoding" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try dom.document_internals.setURL(page.document, "https://example.test/dir/page");
    for ([_]struct { encoding: []const u8, expected: []const u8 }{
        .{ .encoding = "UTF-8", .expected = "https://example.test/dir/%C3%A9?q=%C3%A9" },
        .{ .encoding = "windows-1252", .expected = "https://example.test/dir/%C3%A9?q=%E9" },
    }) |case| {
        try dom.document_internals.setEncoding(page.document, case.encoding);
        const url = (try dom.encoding_parse.encodingParseAndSerialize(page.element, "é?q=é")) orelse return error.InvalidURL;
        defer std.testing.allocator.free(url);
        try std.testing.expectEqualStrings(case.expected, url);
    }
    try std.testing.expect((try dom.encoding_parse.encodingParseAndSerialize(page.element, "http://[")) == null);
}
