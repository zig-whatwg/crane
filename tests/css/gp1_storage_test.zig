//! Lane gaps1: the 16 gap decoration longhands live in rare groups that an
//! element writing none of them never allocates (computed_groups.zig).
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Longhand = css.properties.Longhand;
const computed = css.computed_style;

const gap_longhands = [_][]const u8{
    "row-rule-color",              "row-rule-style",                   "row-rule-width",
    "column-rule-break",           "row-rule-break",                   "column-rule-inset-cap-start",
    "column-rule-inset-cap-end",   "column-rule-inset-junction-start", "column-rule-inset-junction-end",
    "row-rule-inset-cap-start",    "row-rule-inset-cap-end",           "row-rule-inset-junction-start",
    "row-rule-inset-junction-end", "column-rule-visibility-items",     "row-rule-visibility-items",
    "rule-overlap",
};

fn longhandNamed(name: []const u8) !Longhand {
    const property = css.properties.lookup(name) orelse return error.MissingGapProperty;
    if (property != .longhand) return error.MissingGapProperty;
    return property.longhand;
}

fn styleOf(allocator: Allocator, text: []const u8) !*computed.ComputedStyle {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

test "the gap decoration longhands are non-inherited and stored outside every group a common element writes" {
    const common = try styleOf(testing.allocator, "display: block; margin-left: 2px; color: red; border-top: 1px solid blue; background-color: green; width: 10px; font-size: 20px; column-gap: 4px");
    defer common.destroy();
    for (gap_longhands) |name| {
        const l = try longhandNamed(name);
        try testing.expect(!l.inherited());
        const location = computed.groups.location[@backingInt(l)];
        try testing.expect(location.stored);
        // A rare group, never a hot one.
        try testing.expectEqualStrings("rare", computed.groups.names[location.group]);
        try testing.expect(!common.held.isSet(location.group));
    }
}

test "writing one gap decoration longhand holds exactly its own group" {
    const plain = try styleOf(testing.allocator, "color: red");
    defer plain.destroy();
    const ruled = try styleOf(testing.allocator, "color: red; row-rule-color: blue");
    defer ruled.destroy();
    const row_color = try longhandNamed("row-rule-color");
    try testing.expectEqual(plain.held.count() + 1, ruled.held.count());
    try testing.expect(ruled.held.isSet(computed.groups.location[@backingInt(row_color)].group));
}
