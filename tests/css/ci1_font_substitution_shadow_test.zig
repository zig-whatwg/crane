//! Q211 PART 2 E2-only font: full parsed shadow drops, partial shadow stays.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Block = css.declarations.DeclarationBlock;

fn expectValue(allocator: std.mem.Allocator, block: *const Block, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn expectText(allocator: std.mem.Allocator, block: *const Block, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
}

fn shadowed(allocator: std.mem.Allocator, primary: []const u8, secondary: []const u8, full: bool) !void {
    const old_name = if (full) primary else secondary;
    const new_name = if (full) secondary else primary;
    const input = try std.fmt.allocPrint(allocator, "{s}: var(--x) !important; {s}: env(y);", .{ old_name, new_name });
    defer allocator.free(input);
    var block = try Block.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    try expectValue(allocator, &block, old_name, "var(--x)");
    try testing.expect(block.getPropertyPriority(old_name));
    try expectValue(allocator, &block, new_name, "");
    try testing.expect(!block.getPropertyPriority(new_name));
    try testing.expectEqual(@as(usize, if (full) 1 else 2), block.length());
    try testing.expectEqualStrings(old_name, block.item(0).?);
    if (full) {
        try testing.expect(block.item(1) == null);
    } else {
        try testing.expectEqualStrings(new_name, block.item(1).?);
        try testing.expect(block.item(2) == null);
    }
    const expected = if (full)
        try std.fmt.allocPrint(allocator, "{s}: var(--x) !important;", .{old_name})
    else
        try std.fmt.allocPrint(allocator, "{s}: var(--x) !important; {s}: env(y);", .{ old_name, new_name });
    defer allocator.free(expected);
    try expectText(allocator, &block, expected);
}

test "Q211 E2-only font fully shadowed raw shorthand is absent from cssText" {
    try testing.checkAllAllocationFailures(testing.allocator, shadowed, .{ "font", "font-variant", true });
}

test "Q211 E2-only font partially shadowed raw shorthand remains stored" {
    try testing.checkAllAllocationFailures(testing.allocator, shadowed, .{ "font", "font-variant", false });
}

const typed_names = [_][]const u8{ "font", "font-variant", "font-style", "font-variant-caps", "font-weight", "font-width", "font-size", "line-height", "font-family", "font-feature-settings", "font-kerning", "font-language-override", "font-optical-sizing", "font-size-adjust", "font-variant-alternates", "font-variant-east-asian", "font-variant-emoji", "font-variant-ligatures", "font-variant-numeric", "font-variant-position", "font-variation-settings" };

// Q211 PART 2 explicitly includes surviving typed important coverage.
// The independently parsed prefix is the public-API oracle, including cssText.
fn typedCovered(allocator: std.mem.Allocator) !void {
    const prefix = "font: 16px serif !important;";
    var before = try Block.parse(.{ .allocator = allocator }, prefix);
    defer before.deinit();
    const input = try std.fmt.allocPrint(allocator, "{s} font: var(--x);", .{prefix});
    defer allocator.free(input);
    var after = try Block.parse(.{ .allocator = allocator }, input);
    defer after.deinit();
    try testing.expect(before.length() != 0);
    try testing.expect(before.getPropertyPriority("font"));
    try testing.expectEqual(before.length(), after.length());
    for (0..before.length()) |i| try testing.expectEqualStrings(before.item(i).?, after.item(i).?);
    try testing.expect(after.item(after.length()) == null);
    for (typed_names) |name| {
        var old_value: std.ArrayList(u8) = .empty;
        defer old_value.deinit(allocator);
        var new_value: std.ArrayList(u8) = .empty;
        defer new_value.deinit(allocator);
        try before.getPropertyValue(name, &old_value);
        try after.getPropertyValue(name, &new_value);
        try testing.expectEqualStrings(old_value.items, new_value.items);
        try testing.expectEqual(before.getPropertyPriority(name), after.getPropertyPriority(name));
    }
    var old_text: std.ArrayList(u8) = .empty;
    defer old_text.deinit(allocator);
    var new_text: std.ArrayList(u8) = .empty;
    defer new_text.deinit(allocator);
    try before.serialize(&old_text);
    try after.serialize(&new_text);
    try testing.expect(old_text.items.len != 0);
    try testing.expectEqualStrings(old_text.items, new_text.items);
}

test "Q211 E2-only font full typed important coverage drops parsed raw shorthand" {
    try testing.checkAllAllocationFailures(testing.allocator, typedCovered, .{});
}
