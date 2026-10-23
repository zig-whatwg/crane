//! CSS Gaps 1 §2: typed lengths, percentages, math and legacy aliases.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingGapProperty;
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

test "gap lengths retain normal and percentages while computing nonnegative math" {
    for ([_][]const u8{ "row-gap", "column-gap", "grid-row-gap", "grid-column-gap" }) |name| {
        try check(name, "normal", "normal", "normal");
        try check(name, "0", "0px", "0px");
        try check(name, "25%", "25%", "25%");
        try check(name, "2em", "2em", "32px");
        try check(name, "calc(10px - 2em)", "calc(-2em + 10px)", "0px");
        try check(name, "calc(20% + 3px)", "calc(20% + 3px)", "calc(20% + 3px)");
        for ([_][]const u8{ "-1px", "-1%", "auto", "10", "10px 20px", "normal 10px" }) |invalid| try check(name, invalid, "", null);
    }
}

test "gap shorthand and grid aliases share the canonical declaration entries" {
    for ([_][]const u8{ "gap", "grid-gap" }) |name| {
        try check(name, "normal normal", "normal", "normal");
        try check(name, "10px 10px", "10px", "10px");
        try check(name, "1em 20%", "1em 20%", "16px 20%");
    }
    _ = css.properties.lookup("gap") orelse return error.MissingGapProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "grid-row-gap:10px;column-gap:normal");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings("gap: 10px normal;", out.items);
    try testing.expectEqualStrings("row-gap", block.item(0).?);
}

test "counted gap math cleans up both sides under allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}
fn allocationCase(allocator: std.mem.Allocator) !void {
    _ = css.properties.lookup("gap") orelse return error.MissingGapProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "gap:calc(2em + 3px) calc(4% + 5px)");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "grid-gap", "calc(1em + 2%)", "");
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
}
