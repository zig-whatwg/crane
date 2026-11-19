//! Lane maj1: CSS Values 4 §5 - "If an <angle> must be converted due to
//! exceeding the implementation-defined range of supported values, it must be
//! clamped to the nearest supported multiple of 360deg." An infinite rotation
//! is therefore a whole number of turns: Chrome, Firefox and Safari all read
//! rotate(calc(±infinity * 1deg|turn|rad|grad)) and rotate(calc(1deg /
//! sign(0))) as rotate(0deg) (wpt.fyi css/css-values/
//! calc-infinity-nan-computed.html). Crane clamped to the largest double,
//! which is no multiple of 360.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;

fn resolved(name: []const u8, input: []const u8, out: *std.ArrayList(u8)) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, name, input, "")) {
        std.debug.print("{s}: \"{s}\" did not parse\n", .{ name, input });
        return error.TestUnexpectedResult;
    }
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const property = css.properties.lookup(name) orelse return error.UnsupportedProperty;
    out.clearRetainingCapacity();
    try style.serializeResolved(property.longhand, out, allocator);
}

test "an infinite rotation is a whole number of turns" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    const inputs = [_][]const u8{
        "rotate(calc(infinity * 1deg))",
        "rotate(calc(-infinity * 1deg))",
        "rotate(calc(infinity * 1turn))",
        "rotate(calc(-infinity * 1turn))",
        "rotate(calc(infinity * 1rad))",
        "rotate(calc(-infinity * 1rad))",
        "rotate(calc(infinity * 1grad))",
        "rotate(calc(-infinity * 1grad))",
        // A 16px font: sign(0) is 0, and 1deg / 0 is infinite.
        "rotate(calc(1deg / sign(1em - 16px)))",
        "rotate(calc(1deg / (-1 * sign(1em - 16px))))",
    };
    for (inputs) |input| {
        try resolved("transform", input, &out);
        if (!std.mem.eql(u8, "matrix(1, 0, 0, 1, 0, 0)", out.items)) std.debug.print("transform: \"{s}\" resolved\n", .{input});
        try testing.expectEqualStrings("matrix(1, 0, 0, 1, 0, 0)", out.items);
    }
}

test "a NaN rotation is zero and a finite one keeps its turn" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try resolved("transform", "rotate(calc(NaN * 1deg))", &out);
    try testing.expectEqualStrings("matrix(1, 0, 0, 1, 0, 0)", out.items);
    try resolved("transform", "rotate(calc(90deg + 3 * 360deg))", &out);
    try testing.expectEqualStrings("matrix(0, 1, -1, 0, 0, 0)", out.items);
}

test "a literal angle past the range clamps like a calculation's result" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try resolved("transform", "rotate(1e300deg)", &out);
    try testing.expectEqualStrings("matrix(1, 0, 0, 1, 0, 0)", out.items);
    try resolved("transform", "rotate(-1e300turn)", &out);
    try testing.expectEqualStrings("matrix(1, 0, 0, 1, 0, 0)", out.items);
}

test "the clamp is a whole number of turns and leaves other units alone" {
    const math = css.math_values;
    try testing.expectEqual(@as(f64, 0), @mod(math.max_angle_degrees, 360));
    try testing.expectEqual(math.max_angle_degrees, math.clampAngle(.{ .value = std.math.inf(f64), .unit = .deg }).value);
    try testing.expectEqual(-math.max_angle_degrees, math.clampAngle(.{ .value = -std.math.floatMax(f64), .unit = .deg }).value);
    try testing.expectEqual(@as(f64, 1e300), math.clampAngle(.{ .value = 1e300, .unit = .px }).value);
}
