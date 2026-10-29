//! Q87: existing property grammars admit native URL images, including content.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn check(allocator: std.mem.Allocator, name: []const u8, accepted: bool) anyerror!void {
    if (comptime !@hasDecl(css.properties, "parseTypedImage")) return std.testing.expect(false);
    var original: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (original.items) |item| item.value.release();
        original.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, .{ .longhand = .list_style_image }, "url(a.png)", &original));
    const property = (css.properties.lookup(name) orelse return error.MissingProperty);
    var result: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (result.items) |item| item.value.release();
        result.deinit(allocator);
    }
    try std.testing.expectEqual(accepted, try css.properties.parseTypedImage(.{ .allocator = allocator }, property, original.items[0].value.value, &result));
    for (original.items) |item| item.value.release();
    original.clearRetainingCapacity();
    if (accepted) {
        try std.testing.expectEqual(@as(usize, 1), result.items.len);
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try css.properties.serializeAssigned(property.longhand, result.items[0].value, &text, allocator);
        try std.testing.expectEqualStrings("url(\"a.png\")", text.items);
        try std.testing.expectEqual(@as(usize, 1), result.items[0].value.value.resourceUrls().len);
    } else try std.testing.expectEqual(@as(usize, 0), result.items.len);
}

test "Q87 native URL image property matrix agrees with the probe and spec split" {
    for ([_][]const u8{ "background-image", "list-style-image", "border-image-source", "mask-image", "content" }) |name|
        try std.testing.checkAllAllocationFailures(a, check, .{ name, true });
    try std.testing.checkAllAllocationFailures(a, check, .{ "cursor", false });
}
