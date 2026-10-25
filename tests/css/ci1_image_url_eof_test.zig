//! Syntax3 §5.5.10 closes nested functions at end of a declaration.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(input: []const u8, expected: ?[]const u8) !void {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .list_style_image }, input, &assignments));
    if (expected) |wanted| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try css.properties.serializeValue(.list_style_image, assignments.items[0].value.value, &out, testing.allocator);
        try testing.expectEqualStrings(wanted, out.items);
    }
}

test "quoted URL and src image leaves close at EOF" {
    try check("url('a'", "url(\"a\")");
    try check("src('a'", "url(\"a\")");
}

test "quoted URL EOF closure propagates through image-set" {
    try check("image-set(url('a'", "image-set(url(\"a\") 1x)");
}

test "image URL closure still rejects malformed and trailing tokens" {
    for ([_][]const u8{ "url('bad\n')", "url(bad name)", "url('a' junk", "src('a' junk" }) |input| try check(input, null);
}
