//! Q87 Chrome156/Safari27 probe,2026-10-27: only native URL leaves
//! become CSSImageValue; generated images retain their existing owners.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Case = struct { property: []const u8, text: []const u8, image: bool, keyword: bool = false };
const cases = [_]Case{
    .{ .property = "list-style-image", .text = "url(a.png)", .image = true },
    .{ .property = "list-style-image", .text = "linear-gradient(red, blue)", .image = false },
    .{ .property = "list-style-image", .text = "image-set(url(a.png) 1x)", .image = false },
    .{ .property = "list-style-image", .text = "light-dark(url(a.png), url(b.png))", .image = false },
    .{ .property = "list-style-image", .text = "none", .image = false, .keyword = true },
    .{ .property = "content", .text = "url(a.png)", .image = true },
    .{ .property = "content", .text = "url(a.png) 'suffix'", .image = false },
    .{ .property = "content", .text = "url(a.png) / 'alternate'", .image = false },
    .{ .property = "content", .text = "linear-gradient(red, blue)", .image = false },
};
fn check(allocator: std.mem.Allocator, case: Case) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_reification")) return std.testing.expect(false);
    const property = (css.properties.lookup(case.property) orelse return error.MissingProperty);
    var assigned: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assigned.items) |item| item.value.release();
        assigned.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, case.text, &assigned));
    const value = assigned.items[0].value.value;
    const shape = css.typed_om.native_reification.shape(property.longhand, value);
    try std.testing.expectEqual(case.image, shape == .image);
    try std.testing.expectEqual(case.keyword, shape == .keyword);
    if (!case.image and !case.keyword) try std.testing.expect(shape == .unsupported);
}
test "Q87 only URL images reify as image objects and compound content stays whole" {
    for (cases) |case| try check(a, case);
}
test "Q87 image classification retains no allocation or resource on failure" {
    for (cases) |case| try std.testing.checkAllAllocationFailures(a, check, .{case});
}

test "Q87 ordinary computation turns light-dark into a URL before classification" {
    if (comptime !@hasDecl(css.typed_om, "native_reification")) return std.testing.expect(false);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "color-scheme: light; list-style-image: light-dark(url(a.png), url(b.png))");
    defer block.deinit();
    const computed = try css.cascade.cascade(.{ .allocator = a, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer computed.destroy();
    try std.testing.expect(css.typed_om.native_reification.shape(.list_style_image, computed.get(.list_style_image)) == .image);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(a);
    try computed.serializeResolved(.list_style_image, &text, a);
    try std.testing.expectEqualStrings("url(\"a.png\")", text.items);
}
