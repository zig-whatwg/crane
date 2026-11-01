//! Q61(4): specified font-stretch calculations become shorthand keywords only when context-free.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn shorthand(allocator: std.mem.Allocator, width: []const u8, expected: []const u8, expected_stretch: []const u8) !void {
    const declaration = try std.fmt.allocPrint(allocator, "font:medium serif;font-stretch:{s}", .{width});
    defer allocator.free(declaration);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, declaration);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("font-stretch", &out);
    try testing.expectEqualStrings(expected_stretch, out.items);
    out.clearRetainingCapacity();
    try block.getPropertyValue("font", &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn keywordWidths(allocator: std.mem.Allocator) !void {
    // Same valid shorthand setup as the WPT; only font-stretch is then changed.
    try shorthand(allocator, "calc(50%)", "ultra-condensed medium serif", "calc(50%)");
    try shorthand(allocator, "calc(62.5%)", "extra-condensed medium serif", "calc(62.5%)");
    try shorthand(allocator, "calc(100%)", "medium serif", "calc(100%)");
    try shorthand(allocator, "calc(50.01%)", "", "calc(50.01%)");
    try shorthand(allocator, "calc(50% + 25% * sign(100em - 1px))", "", "calc(50% + (25% * sign(100em - 1px)))");
}

test "font shorthand reduces only context-free calculation widths to keywords" {
    try testing.checkAllAllocationFailures(testing.allocator, keywordWidths, .{});
}

fn literalWidths(allocator: std.mem.Allocator) !void {
    const declaration = "font:medium serif;font-stretch:62.5%";
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, declaration);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("font-stretch", &out);
    try testing.expectEqualStrings("62.5%", out.items);
    out.clearRetainingCapacity();
    try block.getPropertyValue("font", &out);
    try testing.expectEqualStrings("extra-condensed medium serif", out.items);
}

test "existing literal font-width shorthand serialization remains available" {
    try testing.checkAllAllocationFailures(testing.allocator, literalWidths, .{});
}
