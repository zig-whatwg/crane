//! Q211 item 2 E2-only font removal controls; expected PASS before the fix.
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

const names = [_][]const u8{
    "font",                    "font-variant",           "font-style",             "font-variant-caps",    "font-weight",
    "font-width",              "font-size",              "line-height",            "font-family",          "font-feature-settings",
    "font-kerning",            "font-language-override", "font-optical-sizing",    "font-size-adjust",     "font-variant-alternates",
    "font-variant-east-asian", "font-variant-emoji",     "font-variant-ligatures", "font-variant-numeric", "font-variant-position",
    "font-variation-settings",
};

fn expectRemoved(allocator: std.mem.Allocator, input: []const u8, removed_name: []const u8, expected_return: []const u8, names_to_check: []const []const u8) !void {
    var block = try Block.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    // Q211 item 2 / PART 2: pin only post-removal cssText in these controls.
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty(removed_name, &removed));
    try testing.expectEqualStrings(expected_return, removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
    try testing.expect(block.item(0) == null);
    for (names_to_check) |name| {
        try expectValue(allocator, &block, name, "");
        try testing.expect(!block.getPropertyPriority(name));
    }
    try expectText(allocator, &block, "");
}

test "Q211 E2-only font remove overlapping narrower shorthand returns empty and leaves no declarations" {
    try testing.checkAllAllocationFailures(testing.allocator, expectRemoved, .{ "font: var(--x) !important; font-variant: env(y);", "font-variant", "", &names });
}

test "Q211 E2-only font remove covering shorthand returns raw text and leaves no declarations" {
    try testing.checkAllAllocationFailures(testing.allocator, expectRemoved, .{ "font: var(--x) !important; font-variant: env(y);", "font", "var(--x)", &names });
}

test "Q211 E2-only font removal clears important typed survivor and raw shorthand" {
    try testing.checkAllAllocationFailures(testing.allocator, expectRemoved, .{ "font-weight: 700 !important; font: var(--x);", "font", "", &names });
}
