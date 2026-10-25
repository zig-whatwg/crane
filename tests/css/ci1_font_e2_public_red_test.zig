//! Font family and size-adjust regression checks through public CSS APIs.
//! Fonts4 section 2.1.1, Fonts5 section 3.4, CSSOM sections 6.7.1-6.7.2.
//! Q39 chooses Firefox/Safari's optional-quote serialization. Q27/Q46/Q111
//! distinguish an absent metric capability from a provider's missing font.
//! Existing saved tests and all their assertions remain unchanged.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn specified(allocator: Allocator, name: []const u8, input: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup(name);
    try testing.expect(property != null);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = allocator }, property.?, input, &assignments));
    try testing.expectEqual(@as(usize, if (expected != null) 1 else 0), assignments.items.len);
    if (expected) |text| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try css.properties.serializeValue(assignments.items[0].longhand, assignments.items[0].value.value, &out, allocator);
        try testing.expectEqualStrings(text, out.items);
    }
}

fn family(allocator: Allocator) !void {
    // Controls precede the optional-quote assertion, so that assertion cannot
    // hide required quotes or grammar rejection on the pre-e2 parent.
    try specified(allocator, "font-family", "'serif'", "\"serif\"");
    try specified(allocator, "font-family", "'21st Century'", "\"21st Century\"");
    try specified(allocator, "font-family", "'Lucida' Grande", null);
    try specified(allocator, "font-family", "'Helvetica Neue', serif", "Helvetica Neue, serif");
}

fn resolved(style: *const css.computed_style.ComputedStyle, allocator: Allocator, name: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup(name);
    try testing.expect(property != null);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.?.longhand, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

fn numericAdjust(allocator: Allocator) !void {
    try specified(allocator, "font-size-adjust", "none", "none");
    try specified(allocator, "font-size-adjust", "0.4", "0.4");
    try specified(allocator, "font-size-adjust", "cap-height 0.6", "cap-height 0.6");
    try specified(allocator, "font-size-adjust", "-0.1", null);
    try specified(allocator, "font-size-adjust", "50%", null);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:24px;font-size-adjust:cap-height 0.6");
    var block_owned = true;
    defer if (block_owned) block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    var parent_owned = true;
    defer if (parent_owned) parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    parent.destroy();
    parent_owned = false;
    block.deinit();
    block_owned = false;
    try resolved(child, allocator, "font-size-adjust", "cap-height 0.6");
    try resolved(child, allocator, "font-size", "24px");
}

fn unavailableMetric(allocator: Allocator) !void {
    // Q27/Q46: the default Context is an unknown capability. The higher
    // candidate is retained as specified syntax but cannot replace 0.4.
    try specified(allocator, "font-size-adjust", "cap-height from-font", "cap-height from-font");
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size-adjust:0.4");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:24px;font-family:'Kept Font';font-size-adjust:cap-height from-font");
    defer high.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &low, .source = .{ .origin = .user } },
        .{ .block = &high, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    try resolved(style, allocator, "font-size-adjust", "0.4");
    try resolved(style, allocator, "font-size", "24px");
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = style }, &.{});
    defer child.destroy();
    try resolved(child, allocator, "font-size-adjust", "0.4");
}

test "e2 family serialization exposes optional quotes after required quote and syntax controls" {
    try testing.checkAllAllocationFailures(testing.allocator, family, .{});
}

test "e2 numeric size adjust retains strict syntax and inheritance without changing font size" {
    try testing.checkAllAllocationFailures(testing.allocator, numericAdjust, .{});
}

test "e2 default missing metric capability retains the lower candidate and inherited ratio" {
    try testing.checkAllAllocationFailures(testing.allocator, unavailableMetric, .{});
}
