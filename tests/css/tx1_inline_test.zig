//! CSS Inline3 grammars, computed values and shorthand bookkeeping.
const std = @import("std");
const css = @import("css");

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, specified: []const u8, computed: []const u8, quirks: bool) !void {
    const property = css.properties.lookup(name) orelse return error.MissingInlineProperty;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator, .quirks = quirks }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try std.testing.expectEqualStrings(specified, out.items);
    if (specified.len == 0) return;
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:10px");
    defer child_block.deinit();
    _ = try child_block.setProperty(.{ .allocator = allocator }, name, "inherit", "");
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    for ([_]*const css.computed_style.ComputedStyle{ parent, child }) |style| {
        out.clearRetainingCapacity();
        switch (property) {
            .longhand => |l| try style.serializeResolved(l, &out, allocator),
            .shorthand => |s| {
                var assigned: [3]css.properties.Assigned = undefined;
                for (s.longhands(), 0..) |l, i| assigned[i] = .{ .value = style.get(l) };
                try std.testing.expect(try css.properties.serializeShorthand(s, assigned[0..s.longhands().len], .computed, &out, allocator));
            },
        }
        try std.testing.expectEqualStrings(computed, out.items);
    }
}

test "vertical alignment expands unordered groups and computes lengths before inheritance" {
    const cases = .{
        .{ "baseline 0px", "baseline", "baseline" },
        .{ "super middle first", "first middle super", "first middle super" },
        .{ "1em last", "last 1em", "last 20px" },
        .{ "calc(10% - 2em)", "calc(10% - 2em)", "calc(10% - 40px)" },
        .{ "top", "top", "top" },
    };
    inline for (cases) |row| try check(std.testing.allocator, "vertical-align", row[0], row[1], row[2], false);
    inline for (.{ "auto", "first last", "middle alphabetic", "1px 2px", "sub super", "text-before-edge" }) |input|
        try check(std.testing.allocator, "vertical-align", input, "", "", false);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "vertical-align", "calc(10% - 2em)", "calc(10% - 2em)", "calc(10% - 40px)", false });
}

test "vertical-align's unitless quirk does not apply to longhands or math numbers" {
    try check(std.testing.allocator, "vertical-align", "-1.5", "-1.5px", "-1.5px", true);
    try check(std.testing.allocator, "vertical-align", "-1.5", "", "", false);
    try check(std.testing.allocator, "vertical-align", "calc(1)", "", "", true);
    try check(std.testing.allocator, "baseline-shift", "1", "", "", true);
    try check(std.testing.allocator, "baseline-shift", "0", "0px", "0px", true);
}

test "initial-letter preserves sink spelling and computes numeric children" {
    const cases = .{
        .{ "normal", "normal", "normal" },
        .{ "1.23", "1.23", "1.23" },
        .{ "drop 1.23", "1.23 drop", "1.23 drop" },
        .{ "raise 1.23", "1.23 raise", "1.23 raise" },
        .{ "1.23 calc(45.6)", "1.23 calc(45.6)", "1.23 46" },
        .{ "calc(0.5) calc(-2)", "calc(0.5) calc(-2)", "1 1" },
    };
    inline for (cases) |row| try check(std.testing.allocator, "initial-letter", row[0], row[1], row[2], false);
    inline for (.{ "0.5", "1 0", "1 1.5", "drop", "drop 1 2", "1 raise 3" }) |input|
        try check(std.testing.allocator, "initial-letter", input, "", "", false);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "initial-letter", "1.23 calc(45.6)", "1.23 calc(45.6)", "1.23 46", false });
}

test "text box defaulting and edge serialization follow the shipped groups" {
    const cases = .{
        .{ "text-box", "none auto", "normal" },
        .{ "text-box", "auto", "trim-both" },
        .{ "text-box", "cap alphabetic trim-start", "trim-start cap alphabetic" },
        .{ "text-box", "trim-both text text", "text" },
        .{ "text-box", "none cap text", "none cap" },
        .{ "text-box-edge", "text alphabetic", "alphabetic" },
        .{ "text-box-edge", "ex text", "ex" },
        .{ "text-box-edge", "ideographic-ink ideographic-ink", "ideographic-ink" },
    };
    inline for (cases) |row| try check(std.testing.allocator, row[0], row[1], row[2], row[2], false);
    inline for (.{ "auto text", "alphabetic text", "text ex", "text text text" }) |input|
        try check(std.testing.allocator, "text-box-edge", input, "", "", false);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "text-box", "cap alphabetic trim-start", "trim-start cap alphabetic", "trim-start cap alphabetic", false });
}

fn checkInheritance(allocator: std.mem.Allocator) !void {
    const cases = .{
        .{ "alignment-baseline", "hanging", "baseline" },
        .{ "baseline-shift", "super", "0px" },
        .{ "baseline-source", "last", "auto" },
        .{ "dominant-baseline", "mathematical", "mathematical" },
        .{ "initial-letter", "2 raise", "normal" },
        .{ "text-box-edge", "cap alphabetic", "cap alphabetic" },
        .{ "text-box-trim", "trim-start", "none" },
    };
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    inline for (cases) |entry| {
        _ = try block.setProperty(.{ .allocator = allocator }, entry[0], entry[1], "");
    }
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    inline for (cases) |entry| {
        const property = css.properties.lookup(entry[0]) orelse return error.MissingInlineProperty;
        out.clearRetainingCapacity();
        try parent.serializeResolved(property.longhand, &out, allocator);
        try std.testing.expectEqualStrings(entry[1], out.items);
        out.clearRetainingCapacity();
        try child.serializeResolved(property.longhand, &out, allocator);
        try std.testing.expectEqualStrings(entry[2], out.items);
    }
}

test "inline inheritance separates inherited edges from noninherited trim and shifts" {
    try checkInheritance(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkInheritance, .{});
}

test "legacy SVG baseline spellings survive specified and computed CSSOM" {
    // Q19's Chrome+Safari majority; Firefox alone aliases or rejects these.
    inline for (.{ "alignment-baseline", "dominant-baseline" }) |property| {
        inline for (.{ "text-before-edge", "text-after-edge" }) |value| {
            try check(std.testing.allocator, property, value, value, value, false);
        }
    }
}
