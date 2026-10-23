//! Grid 2 §§8.3–8.4: typed placement values, defaulting and serialization.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingGridProperty;
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(specified, out.items);
    if (computed) |wanted| {
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        out.clearRetainingCapacity();
        switch (property) {
            .longhand => |l| try style.serializeResolved(l, &out, testing.allocator),
            .shorthand => |s| {
                var assigned: [css.properties.max_assignments]css.properties.Assigned = undefined;
                for (s.longhands(), 0..) |l, i| assigned[i] = .{ .value = style.get(l) };
                _ = try css.properties.serializeShorthand(s, assigned[0..s.longhands().len], .computed, &out, testing.allocator);
            },
        }
        try testing.expectEqualStrings(wanted, out.items);
    }
}

test "grid lines canonicalize keyword integer and case sensitive identifier components" {
    for ([_][]const u8{ "grid-row-start", "grid-row-end", "grid-column-start", "grid-column-end" }) |name| {
        try check(name, "AuTo", "auto", "auto");
        try check(name, "--A", "--A", "--A");
        try check(name, "Z -44", "-44 Z", "-44 Z");
        try check(name, "2 i SpAn", "span 2 i", "span 2 i");
        try check(name, "span 1 i", "span i", "span i");
        try check(name, "span 1", "span 1", "span 1");
        try check(name, "\\31st", "\\31 st", "\\31 st");
        for ([_][]const u8{ "0", "1.0", "span", "span -1", "span 0", "auto 1", "span auto", "span span 2", "first last", "1 2", "default", "inherit foo" }) |invalid| try check(name, invalid, "", null);
    }
}

test "grid placement shorthands default named lines and serialize only indispensable components" {
    try check("grid-row", "item / item", "item", "item");
    try check("grid-column", "item / auto", "item / auto", "item / auto");
    try check("grid-row", "2 item / auto", "2 item", "2 item");
    try check("grid-area", "auto / auto / auto / auto", "auto", "auto");
    try check("grid-area", "i / i / i / i", "i", "i");
    try check("grid-area", "auto / i / auto / i", "auto / i", "auto / i");
    try check("grid-area", "1 / auto / 2 / auto", "1 / auto / 2", "1 / auto / 2");
    try check("grid-area", "i / i / auto / auto", "i / i / auto / auto", "i / i / auto / auto");
    for ([_][]const u8{ "1 /", "1 / / 2", "1 / 2 / 3 / 4 / 5", "auto / initial" }) |invalid| try check("grid-area", invalid, "", null);
    try check("grid-row", "1 / 2 / 3", "", null);
}

test "grid integer math preserves specified expressions and applies span range at computation" {
    try check("grid-row-start", "calc(1.5) A", "calc(1.5) A", "2 A");
    try check("grid-column-end", "span calc(-2)", "span calc(-2)", "span 1");
    try check("grid-row", "span min(-1, 6) A", "span calc(-1) A", "span A");
    try check("grid-area", "calc(1em / 1px)", "calc(1em / 1px)", "16");
}

test "grid integer wrappers cannot hide unavailable font metrics from the cascade" {
    if (css.properties.lookup("grid-row-start") == null) return error.MissingGridProperty;
    var base = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "grid-row-start: 7");
    defer base.deinit();
    var later = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "grid-row-start: span calc(1cap / 1px) A");
    defer later.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &base, .source = .{ .origin = .author } },
        .{ .block = &later, .source = .{ .origin = .author, .order = 1 } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(css.properties.lookup("grid-row-start").?.longhand, &out, testing.allocator);
    try testing.expectEqualStrings("7", out.items);
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    if (css.properties.lookup("grid-area") == null) return error.MissingGridProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "grid-area: named / span calc(2.5) other / 3 named / auto; grid-row: broken / span span 3");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(css.properties.lookup("grid-column-start").?.longhand, &out, allocator);
    try testing.expectEqualStrings("span 3 other", out.items);
}

test "grid counted identifiers expressions and partial shorthands release every allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}
