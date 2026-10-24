//! Color API holders must preserve references and forward dependency queries.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Value = css.style_values.Value;
const Paint = std.meta.Child(@FieldType(Value, "paint"));
const Filter = std.meta.Child(@FieldType(Value, "filter"));

// This contract deliberately gates future Color variants: aggregate code does
// not inspect or enumerate Color's representation.
test "paint and filter expose both Color dependency queries" {
    if (comptime !@hasDecl(Paint, "needsTreeCounts") or !@hasDecl(Paint, "needsUnavailableMetrics") or
        !@hasDecl(Filter, "needsTreeCounts") or !@hasDecl(Filter, "needsUnavailableMetrics"))
        return error.MissingColorDependencyQueries;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(testing.allocator);
    }
    for ([_]struct { name: []const u8, text: []const u8 }{
        .{ .name = "fill", .text = "url(a) red" },
        .{ .name = "filter", .text = "drop-shadow(CanvasText 1px 2px)" },
    }) |case| {
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, css.properties.lookup(case.name).?, case.text, &assignments));
        const value = assignments.items[assignments.items.len - 1].value.value;
        switch (value) {
            .paint => |paint| if (comptime @hasDecl(Paint, "needsTreeCounts")) {
                try testing.expect(!paint.needsTreeCounts());
                try testing.expect(!paint.needsUnavailableMetrics(false));
            },
            .filter => |filter| if (comptime @hasDecl(Filter, "needsTreeCounts")) {
                try testing.expect(!filter.needsTreeCounts());
                try testing.expect(!filter.needsUnavailableMetrics(false));
            },
            else => return error.MissingAggregate,
        }
    }
}

fn borrowedColorLifetime(allocator: std.mem.Allocator) !void {
    const color_text = try css.style_values.SharedText.create(allocator, "red");
    var color_owned = true;
    defer if (color_owned) color_text.unref();
    const url_text = try css.style_values.SharedText.create(allocator, "url(\"a\")");
    var url_owned = true;
    defer if (url_owned) url_text.unref();
    const named: Value = .{ .color = .{ .named = .{ .rgba = .{ .r = 255, .g = 0, .b = 0 }, .name = color_text } } };
    const paint = try Paint.create(allocator, .{ .text = url_text }, named);
    defer paint.unref();
    named.release();
    color_owned = false;
    url_text.unref();
    url_owned = false;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try paint.serialize(&out, allocator, null);
    try testing.expectEqualStrings("url(\"a\") red", out.items);
    out.clearRetainingCapacity();
    try paint.serialize(&out, allocator, .{ .rgba = .{ .r = 0, .g = 255, .b = 0 } });
    try testing.expectEqualStrings("url(\"a\") rgb(255, 0, 0)", out.items);
}

test "paint owns a borrowed named Color and resolves it through the API" {
    try testing.checkAllAllocationFailures(testing.allocator, borrowedColorLifetime, .{});
}
