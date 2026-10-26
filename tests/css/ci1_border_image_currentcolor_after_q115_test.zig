//! UNRUN Q115-dependent supplement. No future API names; semantic dependency only.
const std = @import("std");
const css = @import("css");
fn receiverCase(allocator: std.mem.Allocator) !void {
    const p = css.properties.lookup("border-image-source") orelse return error.BorderImageNotImplemented;
    if (css.properties.lookup("border-image") == null) return error.BorderImageFamilyNotImplemented;
    const child = blk: {
        var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:red;border-image:linear-gradient(currentcolor,currentcolor) 20 fill / 1em / 2 round");
        defer parent_block.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:blue;font-size:40px;border-image:inherit");
        defer child_block.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(p.longhand, &out, allocator);
    try std.testing.expectEqualStrings("linear-gradient(rgb(0, 0, 255), rgb(0, 0, 255))", out.items);
}
test "ci1 border image Q115 receiver color survives source and parent release all OOM" {
    try receiverCase(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, receiverCase, .{});
}
