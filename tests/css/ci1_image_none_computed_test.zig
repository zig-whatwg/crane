//! CSS Color 5 §7: selected none computes as image(transparent).
//! CSS Color 4 §15.5: transparent computes to transparent black.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Longhand = css.properties.Longhand;

fn expectTransparent(style: *const css.computed_style.ComputedStyle, longhand: Longhand, allocator: Allocator) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try style.serializeResolved(longhand, &text, allocator);
    try testing.expectEqualStrings("image(rgba(0, 0, 0, 0))", text.items);
}

fn computedNone(allocator: Allocator, longhand: Longhand, dark: bool) !void {
    const name = if (longhand == .background_image) "background-image" else "content";
    const scheme = if (dark) "dark" else "light";
    const choice = if (dark) "light-dark(url(unused),none)" else "light-dark(none,url(unused))";
    const declaration = try std.fmt.allocPrint(allocator, "color:red;color-scheme:{s};{s}:{s}", .{ scheme, name, choice });
    defer allocator.free(declaration);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, declaration);
    var block_owned = true;
    defer if (block_owned) block.deinit();
    try testing.expect(block.get(longhand) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.deinit();
    block_owned = false;

    // The real cascade owns its computed image after the declaration dies.
    try expectTransparent(style, longhand, allocator);
    try testing.expectEqual(@as(usize, 0), style.get(longhand).resourceUrls().len);

    // Color 5 §7 selects and computes before inheritance, so the child's
    // opposite color scheme cannot revive the unchosen URL.
    const inherited = try std.fmt.allocPrint(allocator, "color-scheme:{s};{s}:inherit", .{ if (dark) "light" else "dark", name });
    defer allocator.free(inherited);
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, inherited);
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = style }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    try expectTransparent(child, longhand, allocator);
    try testing.expectEqual(@as(usize, 0), child.get(longhand).resourceUrls().len);
}

test "selected none background image computes transparent black before inheritance at every allocation failure" {
    for ([_]bool{ false, true }) |dark| {
        try testing.checkAllAllocationFailures(testing.allocator, computedNone, .{ .background_image, dark });
    }
}

test "selected none content image computes transparent black before inheritance at every allocation failure" {
    for ([_]bool{ false, true }) |dark| {
        try testing.checkAllAllocationFailures(testing.allocator, computedNone, .{ .content, dark });
    }
}
