//! CSS Box Alignment 3 complete non-geometric property grammar and defaulting.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingAlignmentProperty;
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

test "alignment grammar distinguishes content self and default alignment" {
    for ([_][]const u8{ "align-content", "justify-content", "align-items", "justify-items", "align-self", "justify-self" }) |name| {
        for ([_][]const u8{ "normal", "stretch", "center", "start", "end", "safe start", "unsafe end" }) |value| try check(name, value, value, value);
        for ([_][]const u8{ "safe", "unsafe", "center safe", "stretch center", "safe stretch", "baseline last", "legacy start" }) |value| try check(name, value, "", null);
    }
    for ([_][]const u8{ "align-content", "align-items", "justify-items", "align-self", "justify-self" }) |name| {
        try check(name, "first baseline", "baseline", "baseline");
        try check(name, "last baseline", "last baseline", "last baseline");
    }
    for ([_][]const u8{ "justify-content", "justify-items", "justify-self" }) |name| try check(name, "safe right", "safe right", "safe right");
    for ([_][]const u8{ "align-content", "align-items", "align-self" }) |name| try check(name, "left", "", null);
    for ([_][]const u8{ "align-content", "justify-content" }) |name| try check(name, "space-evenly", "space-evenly", "space-evenly");
    for ([_][]const u8{ "align-self", "justify-self" }) |name| {
        try check(name, "auto", "auto", "auto");
        try check(name, "anchor-center", "anchor-center", "anchor-center");
    }
    try check("justify-content", "baseline", "", null);
    try check("align-items", "auto", "", null);
    try check("align-items", "anchor-center", "", null);
    try check("justify-items", "right legacy", "legacy right", "legacy right");
}

test "place shorthands parse complete components and preserve baseline default serialization" {
    try check("place-content", "baseline", "baseline start", "baseline start");
    try check("place-content", "last baseline stretch", "last baseline stretch", "last baseline stretch");
    try check("place-content", "safe center unsafe right", "safe center unsafe right", "safe center unsafe right");
    try check("place-items", "normal legacy left", "normal legacy left", "normal legacy left");
    try check("place-items", "center center", "center", "center");
    try check("place-self", "baseline last baseline", "baseline last baseline", "baseline last baseline");
    try check("place-self", "auto", "auto", "auto");
    try check("place-items", "left", "", null);
    try check("place-content", "center auto", "", null);
}

test "justify items legacy resolves from the parent while other alignment initials do not inherit" {
    const property = css.properties.lookup("justify-items") orelse return error.MissingAlignmentProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "justify-items:legacy center;align-self:end");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try child.serializeResolved(property.longhand, &out, testing.allocator);
    try testing.expectEqualStrings("legacy center", out.items);
    out.clearRetainingCapacity();
    const self = css.properties.lookup("align-self") orelse return error.MissingAlignmentProperty;
    try child.serializeResolved(self.longhand, &out, testing.allocator);
    try testing.expectEqualStrings("auto", out.items);
    try check("justify-items", "legacy", "legacy", "normal");
}

test "alignment flex aliases preserve specified spelling and compute flow aliases" {
    for ([_][]const u8{ "align-content", "justify-content", "align-items", "justify-items", "align-self", "justify-self" }) |name| {
        try check(name, "flex-start", "flex-start", "flow-start");
        try check(name, "safe flex-end", "safe flex-end", "safe flow-end");
        try check(name, "flow-end", "flow-end", "flow-end");
    }
    try check("place-content", "flex-start flex-end", "flex-start flex-end", "flow-start flow-end");
}
