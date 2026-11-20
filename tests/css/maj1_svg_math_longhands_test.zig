//! Lane maj1: the longhands Chrome, Firefox and Safari ship that Crane did
//! not have - SVG 2's painting, gradient, text and geometry properties (Fill
//! and Stroke 3, SVG 2 §§9-13), Filter Effects 1 flood-opacity, MathML Core
//! §3 math-depth / math-shift / math-style, Pointer Events touch-action and
//! the Logical 1 border-*-*-radius longhands: grammar, specified and computed
//! serialization, initial value and inheritance. The expectations are the
//! browsers' (wpt.fyi 2358bd4835: svg/painting/parsing, svg/pservers/parsing,
//! svg/geometry/parsing, svg/text/parsing, mathml/relations/css-styling/
//! parsing, pointerevents/parsing - all three pass, except where a comment
//! names the majority).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;

fn longhandOf(name: []const u8) !css.properties.Longhand {
    const property = css.properties.lookup(name) orelse return error.UnsupportedProperty;
    if (property != .longhand) return error.NotALonghand;
    return property.longhand;
}

fn resolved(style: *const Style, name: []const u8, out: *std.ArrayList(u8)) !void {
    out.clearRetainingCapacity();
    try style.serializeResolved(try longhandOf(name), out, testing.allocator);
}

/// `input` is valid: it reads back as `specified` and computes to `computed`
/// (a 16px font: 0.5em is 8px).
fn valid(name: []const u8, input: []const u8, specified: []const u8, computed: []const u8) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, name, input, "")) {
        std.debug.print("{s}: \"{s}\" did not parse\n", .{ name, input });
        return error.TestUnexpectedResult;
    }
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    if (!std.mem.eql(u8, specified, text.items)) std.debug.print("{s}: \"{s}\" specified\n", .{ name, input });
    try testing.expectEqualStrings(specified, text.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try resolved(style, name, &text);
    if (!std.mem.eql(u8, computed, text.items)) std.debug.print("{s}: \"{s}\" computed\n", .{ name, input });
    try testing.expectEqualStrings(computed, text.items);
}

fn invalid(name: []const u8, input: []const u8) !void {
    _ = try longhandOf(name);
    var block = Block.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try block.getPropertyValue(name, &text);
    if (text.items.len != 0) std.debug.print("{s}: \"{s}\" should be invalid\n", .{ name, input });
    try testing.expectEqualStrings("", text.items);
}

fn initial(name: []const u8, expected: []const u8, inherited: bool) !void {
    const l = try longhandOf(name);
    try testing.expectEqual(inherited, l.info().inherited);
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try resolved(style, name, &text);
    if (!std.mem.eql(u8, expected, text.items)) std.debug.print("{s}: initial\n", .{name});
    try testing.expectEqualStrings(expected, text.items);
}

test "keyword longhands: their keywords, their initial values and inheritance" {
    const groups = .{
        .{ "fill-rule", &[_][]const u8{ "nonzero", "evenodd" }, true },
        .{ "stroke-linecap", &[_][]const u8{ "butt", "round", "square" }, true },
        // miter-clip and arcs (Fill and Stroke 3) ship in no browser.
        .{ "stroke-linejoin", &[_][]const u8{ "miter", "round", "bevel" }, true },
        .{ "color-interpolation", &[_][]const u8{ "srgb", "auto", "linearrgb" }, true },
        .{ "shape-rendering", &[_][]const u8{ "auto", "optimizespeed", "crispedges", "geometricprecision" }, true },
        .{ "text-anchor", &[_][]const u8{ "start", "middle", "end" }, true },
        .{ "vector-effect", &[_][]const u8{ "none", "non-scaling-stroke" }, false },
        // Chrome and Safari; Firefox does not ship it.
        .{ "buffered-rendering", &[_][]const u8{ "auto", "dynamic", "static" }, true },
        .{ "math-shift", &[_][]const u8{ "normal", "compact" }, true },
        .{ "math-style", &[_][]const u8{ "normal", "compact" }, true },
    };
    inline for (groups) |group| {
        for (group[1]) |keyword| try valid(group[0], keyword, keyword, keyword);
        try initial(group[0], group[1][0], group[2]);
        try invalid(group[0], "unknown-keyword");
        try invalid(group[0], "1");
        try invalid(group[0], group[1][0] ++ " " ++ group[1][1]);
    }
    try valid("color-interpolation", "sRGB", "srgb", "srgb");
    try valid("shape-rendering", "optimizeSpeed", "optimizespeed", "optimizespeed");
    try invalid("stroke-linejoin", "miter-clip");
    try invalid("stroke-linejoin", "arcs");
    try invalid("shape-rendering", "optimizelegibility");
    try invalid("color-interpolation", "none");
}

test "the opacity longhands clamp at computed-value time" {
    inline for (.{ .{ "fill-opacity", true }, .{ "stroke-opacity", true }, .{ "stop-opacity", false }, .{ "flood-opacity", false } }) |entry| {
        try initial(entry[0], "1", entry[1]);
        try valid(entry[0], "0.5", "0.5", "0.5");
        try valid(entry[0], "50%", "0.5", "0.5");
        try valid(entry[0], "3", "3", "1");
        try valid(entry[0], "-1", "-1", "0");
        try valid(entry[0], "-100%", "-1", "0");
        try invalid(entry[0], "2 3");
        try invalid(entry[0], "auto");
    }
}

test "stop-color is a color" {
    try initial("stop-color", "rgb(0, 0, 0)", false);
    try valid("stop-color", "white", "white", "rgb(255, 255, 255)");
    try valid("stop-color", "rgba(255, 255, 255, 0.4)", "rgba(255, 255, 255, 0.4)", "rgba(255, 255, 255, 0.4)");
    try invalid("stop-color", "none");
}

test "stroke-miterlimit is a non-negative number" {
    try initial("stroke-miterlimit", "4", true);
    for ([_][]const u8{ "0", "0.5", "1", "7.5" }) |n| try valid("stroke-miterlimit", n, n, n);
    try invalid("stroke-miterlimit", "-4");
    try invalid("stroke-miterlimit", "2 3");
    try invalid("stroke-miterlimit", "1px");
}

test "stroke-dashoffset is a length-percentage or a number, which computes to px" {
    try initial("stroke-dashoffset", "0px", true);
    try valid("stroke-dashoffset", "10px", "10px", "10px");
    try valid("stroke-dashoffset", "-20%", "-20%", "-20%");
    try valid("stroke-dashoffset", "30", "30", "30px");
    try valid("stroke-dashoffset", "0.5em", "0.5em", "8px");
    for ([_][]const u8{ "auto", "30deg", "40px 50%", "calc(2px + 3)" }) |bad| try invalid("stroke-dashoffset", bad);
}

test "the geometry properties: x, y, cx, cy any length-percentage; r, rx, ry non-negative; rx, ry also auto" {
    inline for (.{ "x", "y", "cx", "cy" }) |name| {
        try initial(name, "0px", false);
        try valid(name, "0", "0px", "0px");
        try valid(name, "-1px", "-1px", "-1px");
        try valid(name, "4%", "4%", "4%");
        try valid(name, "0.5em", "0.5em", "8px");
        try invalid(name, "10");
        try invalid(name, "auto");
        try invalid(name, "10px 20px");
    }
    try initial("r", "0px", false);
    try valid("r", "1px", "1px", "1px");
    try invalid("r", "-1px");
    try invalid("r", "auto");
    inline for (.{ "rx", "ry" }) |name| {
        try initial(name, "auto", false);
        try valid(name, "auto", "auto", "auto");
        try valid(name, "4%", "4%", "4%");
        try invalid(name, "-10%");
        try invalid(name, "10");
    }
}

test "paint-order serializes its shortest equivalent" {
    try initial("paint-order", "normal", true);
    const cases = [_][2][]const u8{
        .{ "normal", "normal" },                      .{ "fill", "fill" },                          .{ "stroke", "stroke" },
        .{ "markers", "markers" },                    .{ "fill stroke", "fill" },                   .{ "fill markers", "fill markers" },
        .{ "stroke fill", "stroke" },                 .{ "stroke markers", "stroke markers" },      .{ "markers fill", "markers" },
        .{ "markers stroke", "markers stroke" },      .{ "fill stroke markers", "fill" },           .{ "fill markers stroke", "fill markers" },
        .{ "stroke fill markers", "stroke" },         .{ "stroke markers fill", "stroke markers" }, .{ "markers fill stroke", "markers" },
        .{ "markers stroke fill", "markers stroke" },
    };
    for (cases) |case| try valid("paint-order", case[0], case[1], case[1]);
    for ([_][]const u8{ "normal stroke", "fill fill", "markers normal", "none" }) |bad| try invalid("paint-order", bad);
}

test "math-depth: auto-add, add() and integers" {
    try initial("math-depth", "0", true);
    try valid("math-depth", "auto-add", "auto-add", "0");
    try valid("math-depth", "add(0)", "add(0)", "0");
    try valid("math-depth", "add(1)", "add(1)", "1");
    try valid("math-depth", "add(-2)", "add(-2)", "-2");
    try valid("math-depth", "0", "0", "0");
    try valid("math-depth", "3", "3", "3");
    for ([_][]const u8{ "auto", "invalid", "add", "add(0.5)", "add(1px)", "0.5", "1px", "auto-add add(1)", "auto-add 1", "add(1) 1" }) |bad| try invalid("math-depth", bad);
}

test "touch-action: auto, none, manipulation or pan-x || pan-y || pinch-zoom" {
    try initial("touch-action", "auto", false);
    for ([_][]const u8{ "auto", "none", "manipulation", "pan-x", "pan-y", "pinch-zoom", "pan-x pan-y", "pan-x pinch-zoom", "pan-x pan-y pinch-zoom" }) |v| try valid("touch-action", v, v, v);
    try valid("touch-action", "pan-y pan-x", "pan-x pan-y", "pan-x pan-y");
    try valid("touch-action", "pinch-zoom pan-y pan-x", "pan-x pan-y pinch-zoom", "pan-x pan-y pinch-zoom");
    // Chrome alone ships pan-left, pan-right, pan-up and pan-down.
    for ([_][]const u8{ "auto none", "manipulation pan-x", "pan-y pan-x pan-y", "pan-left", "none pan-x" }) |bad| try invalid("touch-action", bad);
}

test "the logical border radii are longhands that map to the physical corners" {
    inline for (.{ "border-start-start-radius", "border-start-end-radius", "border-end-start-radius", "border-end-end-radius" }) |name| {
        try valid(name, "10px", "10px", "10px");
        try valid(name, "10px 20%", "10px 20%", "10px 20%");
        try invalid(name, "-1px");
    }
}
