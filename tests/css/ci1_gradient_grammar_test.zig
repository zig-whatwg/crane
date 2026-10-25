//! CSS Images3/4 gradient grammars and Syntax3 §5.5.10 EOF closure.
//! Q31 pins Images3 radial radii; Q55 pins typed angle-percentage stops.
//! Expected positions match css/css-images/parsing/gradient-position-computed.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn specified(allocator: std.mem.Allocator, property: []const u8, input: []const u8, expected: ?[]const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expectEqual(expected != null, try block.setProperty(.{ .allocator = allocator }, property, input, ""));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(property, &out);
    try testing.expectEqualStrings(expected orelse "", out.items);
}

fn computed(allocator: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
    // The child outlives BOTH the source declaration and the parent that
    // computed it. Its explicit inherit must keep the full typed value alive.
    const child = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", input, ""));
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:10px;background-image:inherit");
        defer inherited.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(.background_image, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

fn singleStop(allocator: std.mem.Allocator) !void {
    // Q56: color-stops-parsing.html is 162/162 in all three browsers.
    for ([_][]const u8{ "linear-gradient", "radial-gradient", "conic-gradient", "repeating-linear-gradient", "repeating-radial-gradient", "repeating-conic-gradient" }) |name| {
        const value = try std.fmt.allocPrint(allocator, "{s}(red)", .{name});
        defer allocator.free(value);
        try specified(allocator, "background-image", value, value);
    }
}

test "strict gradients keep a single color in every standard gradient family" {
    try testing.checkAllAllocationFailures(testing.allocator, singleStop, .{});
}

test "radial radius grammar retains the Q31 browser ruling and circle omission" {
    for ([_][]const u8{
        "radial-gradient(circle 50%, red, blue)",
        "radial-gradient(ellipse closest-side farthest-side, red, blue)",
        "radial-gradient(ellipse 10px, red, blue)",
        "radial-gradient(50%, red, blue)",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, specified, .{ "background-image", input, @as(?[]const u8, null) });
    try testing.checkAllAllocationFailures(testing.allocator, specified, .{ "background-image", "radial-gradient(circle 10px, red, blue)", @as(?[]const u8, "radial-gradient(10px, red, blue)") });
    try testing.checkAllAllocationFailures(testing.allocator, computed, .{ "radial-gradient(circle 10px, red, blue)", "radial-gradient(10px, rgb(255, 0, 0), rgb(0, 0, 255))" });
}

test "conic gradient stops preserve typed angle-percentage canonicalization" {
    const Case = struct { input: []const u8, expected: []const u8 };
    // Q55/Q56: Chrome/Safari pass all six; Firefox does not ship the mix.
    for ([_]Case{
        .{ .input = "conic-gradient(red, calc(0deg + 100%), blue)", .expected = "conic-gradient(red, calc(100% + 0deg), blue)" },
        .{ .input = "conic-gradient(red calc(0deg + 100%), blue)", .expected = "conic-gradient(red calc(100% + 0deg), blue)" },
        .{ .input = "conic-gradient(red calc(90deg + 50%), blue)", .expected = "conic-gradient(red calc(50% + 90deg), blue)" },
        .{ .input = "conic-gradient(red calc(90deg + 0%), blue)", .expected = "conic-gradient(red calc(0% + 90deg), blue)" },
        .{ .input = "conic-gradient(red calc(100% - 45deg), blue)", .expected = "conic-gradient(red calc(100% - 45deg), blue)" },
        .{ .input = "repeating-conic-gradient(red calc(90deg + 50%), blue)", .expected = "repeating-conic-gradient(red calc(50% + 90deg), blue)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, specified, .{ "background-image", case.input, @as(?[]const u8, case.expected) });
}

test "angle-percentage is rejected in linear radial and conic from grammars" {
    for ([_][]const u8{
        "linear-gradient(red calc(50% + 30deg), blue)",
        "radial-gradient(red calc(50% + 30deg), blue)",
        "conic-gradient(from calc(50% + 30deg), red, blue)",
        "conic-gradient(red calc(50% + 0), blue)",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, specified, .{ "background-image", input, @as(?[]const u8, null) });
}

test "shared gradient grammar closes EOF for content and image properties" {
    for ([_][]const u8{ "content", "background-image" }) |property| {
        try testing.checkAllAllocationFailures(testing.allocator, specified, .{ property, "linear-gradient(red, blue", @as(?[]const u8, "linear-gradient(red, blue)") });
        for ([_][]const u8{ "linear-gradient(red, url(bad name))", "linear-gradient(red, 'bad\n')", "linear-gradient(red], blue)" }) |input|
            try testing.checkAllAllocationFailures(testing.allocator, specified, .{ property, input, @as(?[]const u8, null) });
    }
}

test "gradient stop grammar rejects edge hints adjacent hints and incomplete stops" {
    for ([_][]const u8{
        "linear-gradient()",                              "linear-gradient(10%, red)",                    "linear-gradient(red, 10%)",
        "linear-gradient(red, 10%, 20%, blue)",           "linear-gradient(red 10% 20% 30%, blue)",       "linear-gradient(red,,blue)",
        "linear-gradient(red,)",                          "linear-gradient(to left right, red, blue)",    "radial-gradient(at top 0px, red, blue)",
        "radial-gradient(at right 3% center, red, blue)", "conic-gradient(at top from 20deg, red, blue)",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, specified, .{ "background-image", input, @as(?[]const u8, null) });
}

test "computed gradient positions preserve unresolved percentages without layout and survive inheritance" {
    const Case = struct { input: []const u8, expected: []const u8 };
    for ([_]Case{
        .{ .input = "radial-gradient(at bottom 10% right 20%, red, blue)", .expected = "radial-gradient(at 80% 90%, rgb(255, 0, 0), rgb(0, 0, 255))" },
        .{ .input = "conic-gradient(at right 10px top 20px, red, blue)", .expected = "conic-gradient(at calc(100% - 10px) 20px, rgb(255, 0, 0), rgb(0, 0, 255))" },
        .{ .input = "conic-gradient(at 150% -20%, red, blue)", .expected = "conic-gradient(at 150% -20%, rgb(255, 0, 0), rgb(0, 0, 255))" },
        .{ .input = "radial-gradient(at 1em center, red, blue)", .expected = "radial-gradient(at 40px 50%, rgb(255, 0, 0), rgb(0, 0, 255))" },
        .{ .input = "linear-gradient(red 80%, blue 20%)", .expected = "linear-gradient(rgb(255, 0, 0) 80%, rgb(0, 0, 255) 20%)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{ case.input, case.expected });
}
