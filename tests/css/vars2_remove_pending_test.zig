//! removeProperty of a shorthand whose value is a pending substitution
//! returns "" - integrator probe 1026a (tmp/analysis/integrator-probes-
//! 1026a/RULINGS.md): Chrome 155 and Safari 27 return "" for
//! removeProperty('border') and removeProperty('font') after
//! `border: var(--x)` / `font: var(--x)`; Firefox 158 returns "var(--x)",
//! CSSOM's literal step 3. No newer spec: golden rule 2, the majority. The
//! value read before removal and the longhands cleared are unchanged.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const DeclarationBlock = css.declarations.DeclarationBlock;

/// `before`/`after` null: not asserted (border's and font's longhand counts
/// are Codex row 119's to settle, probe 1026a's 17 and 19).
fn removeCase(text: []const u8, property: []const u8, readback: []const u8, returned: []const u8, before: ?usize, after: ?usize) !void {
    var block = try DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    var read: std.ArrayList(u8) = .empty;
    defer read.deinit(testing.allocator);
    try block.getPropertyValue(property, &read);
    try testing.expectEqualStrings(readback, read.items);
    if (before) |n| try testing.expectEqual(n, block.length());
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    _ = try block.removeProperty(property, &out);
    try testing.expectEqualStrings(returned, out.items);
    if (after) |n| try testing.expectEqual(n, block.length());
}

test "removeProperty of a var() shorthand returns \"\" and clears its longhands" {
    try removeCase("border: var(--x) !important", "border", "var(--x)", "", null, 0);
    try removeCase("font: var(--x) !important", "font", "var(--x)", "", null, 0);
    try removeCase("margin: var(--x)", "margin", "var(--x)", "", 4, 0);
}

test "removeProperty of a longhand of a var() shorthand, and of ordinary values, is unchanged" {
    try removeCase("border: var(--x)", "border-color", "", "", null, null);
    try removeCase("margin: 1px 2px", "margin", "1px 2px", "1px 2px", 4, 0);
    try removeCase("color: var(--x)", "color", "var(--x)", "var(--x)", 1, 0);
}
