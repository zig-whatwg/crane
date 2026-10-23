//! Position-try restrictions are block context, including subsequent CSSOM writes.
const std = @import("std");
const css = @import("css");
const Block = css.declarations.DeclarationBlock;
const a = std.testing.allocator;

fn serialized(block: *const Block, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try block.serialize(&out);
    try std.testing.expectEqualStrings(expected, out.items);
}

test "default context preserves ordinary and unparsed font descriptor behavior" {
    var block = try Block.parse(.{ .allocator = a }, "color:red!important;src:url(font.woff2);--x:y");
    defer block.deinit();
    try std.testing.expectEqual(Block.Context.style, block.context);
    try std.testing.expectEqual(@as(usize, 3), block.length());
    try std.testing.expect(block.get(.color).?.important);
    try std.testing.expectEqualStrings("src", block.item(1).?);
    try block.setCssText(.{ .allocator = a }, "font-display:swap;color:blue!important");
    try std.testing.expectEqual(@as(usize, 2), block.length());
    try std.testing.expectEqualStrings("font-display", block.item(0).?);
    try std.testing.expect(block.get(.color).?.important);
}

test "position try accepts only positioning descriptors and rejects important at every mutation entry" {
    var block = try Block.parseInContext(.{ .allocator = a }, "top:1px; color:red; --x:y; left:2px!important; margin:3px; width:fit-content(4px); position-area:top left", .position_try);
    defer block.deinit();
    try serialized(&block, "top: 1px; margin: 3px; width: fit-content(4px); position-area: left top;");
    try std.testing.expect(!try block.setProperty(.{ .allocator = a }, "left", "5px", "important"));
    try std.testing.expect(!try block.setProperty(.{ .allocator = a }, "color", "red", ""));
    try std.testing.expect(!try block.setProperty(.{ .allocator = a }, "all", "inherit", ""));
    try std.testing.expect(try block.setProperty(.{ .allocator = a }, "inset", "6px", ""));
    try block.setCssText(.{ .allocator = a }, "right:7px; background:red; bottom:8px!important; @media all {top:9px}");
    try std.testing.expectEqual(Block.Context.position_try, block.context);
    try serialized(&block, "right: 7px;");
}

test "position try context releases every partial parse and replacement on allocation failure" {
    try std.testing.checkAllAllocationFailures(a, allocationCase, .{});
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    var block = try Block.parseInContext(.{ .allocator = allocator }, "margin:calc(2em + 3px);position-anchor:--Foo;left:anchor(--Foo left);color:red", .position_try);
    defer block.deinit();
    try block.setCssText(.{ .allocator = allocator }, "inset:1px 2px 3px 4px; position-area:top left; width:fit-content(1em)");
}
