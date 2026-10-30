//! Lane rendering3: combining computed values through the real cascade.
//! Each case computes both endpoints with the cascade, combines them with
//! css.interpolation, then feeds the result back as a declaration (the way
//! the animation origin will) and reads the resolved value: so it pins both
//! the combination and that a combined computed value recomputes to itself.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Style = css.computed_style.ComputedStyle;
const Block = css.declarations.DeclarationBlock;
const Value = css.style_values.Value;
const interpolation = css.interpolation;

const Op = enum { interpolate, add };

fn computeOne(allocator: Allocator, name: []const u8, text: []const u8, parent: ?*const Style) !*Style {
    var block = Block.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, name, text, "")) return error.Rejected;
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn combined(allocator: Allocator, op: Op, name: []const u8, from: []const u8, to: []const u8, p: f64, expected: []const u8) !void {
    const l = (css.properties.lookup(name) orelse return error.Unknown).longhand;
    const a = try computeOne(allocator, name, from, null);
    defer a.destroy();
    const b = try computeOne(allocator, name, to, null);
    defer b.destroy();
    const raw = switch (op) {
        .interpolate => try interpolation.interpolate(allocator, l, a.get(l), b.get(l), p),
        .add => try interpolation.add(allocator, l, a.get(l), b.get(l)),
    };
    const result = interpolation.clampFinal(l, raw);
    // The block takes the reference.
    var block = Block.init(allocator);
    defer block.deinit();
    block.entries.append(allocator, .{ .typed = .{ .longhand = l, .value = .{ .value = result }, .important = false } }) catch |err| {
        result.release();
        return err;
    };
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

const cases = .{
    .{ Op.interpolate, "opacity", "0", "1", 0.25, "0.25" },
    .{ Op.interpolate, "opacity", "0", "1", 1.5, "1" },
    .{ Op.interpolate, "width", "10px", "30px", 0.5, "20px" },
    .{ Op.interpolate, "width", "1em", "2em", 0.5, "24px" },
    .{ Op.interpolate, "width", "10px", "50%", 0.5, "calc(25% + 5px)" },
    .{ Op.interpolate, "width", "10px", "30px", -2, "0px" },
    .{ Op.interpolate, "margin-left", "10px", "30px", -2, "-30px" },
    .{ Op.interpolate, "color", "rgb(255, 0, 0)", "rgb(0, 0, 255)", 0.5, "rgb(128, 0, 128)" },
    .{ Op.interpolate, "background-color", "transparent", "rgb(0, 128, 0)", 0.5, "rgba(0, 128, 0, 0.5)" },
    .{ Op.interpolate, "font-weight", "100", "900", 0.3, "340" },
    .{ Op.interpolate, "z-index", "1", "4", 0.5, "3" },
    .{ Op.interpolate, "visibility", "hidden", "visible", 0.1, "visible" },
    .{ Op.interpolate, "float", "left", "right", 0.4, "left" },
    .{ Op.interpolate, "float", "left", "right", 0.5, "right" },
    .{ Op.interpolate, "translate", "10px 20px", "30px 40px", 0.5, "20px 30px" },
    .{ Op.interpolate, "translate", "none", "100px", 0.5, "50px" },
    .{ Op.interpolate, "scale", "1", "3", 0.5, "2" },
    .{ Op.interpolate, "rotate", "0deg", "90deg", 0.5, "45deg" },
    .{ Op.interpolate, "rotate", "none", "1turn", 0.25, "90deg" },
    .{ Op.interpolate, "transform-origin", "10px 20px", "30px 40px", 0.5, "20px 30px" },
    .{ Op.interpolate, "perspective-origin", "10px 10px", "30px 50px", 0.5, "20px 30px" },
    .{ Op.interpolate, "perspective-origin", "0% 10px", "100% 30px", 0.25, "25% 15px" },
    .{ Op.interpolate, "box-shadow", "rgb(0, 0, 0) 10px 10px 10px 10px", "rgb(200, 100, 0) 30px 30px 30px 30px", 0.5, "rgb(100, 50, 0) 20px 20px 20px 20px" },
    .{ Op.interpolate, "box-shadow", "none", "rgb(200, 100, 0) 20px 20px", 0.5, "rgba(200, 100, 0, 0.5) 10px 10px 0px 0px" },
    .{ Op.add, "box-shadow", "rgb(0, 0, 0) 1px 1px", "rgb(255, 0, 0) 2px 2px", 0, "rgb(0, 0, 0) 1px 1px 0px 0px, rgb(255, 0, 0) 2px 2px 0px 0px" },
    .{ Op.interpolate, "filter", "blur(10px) brightness(0)", "blur(30px) brightness(1)", 0.5, "blur(20px) brightness(0.5)" },
    .{ Op.interpolate, "filter", "none", "grayscale(1) hue-rotate(90deg)", 0.5, "grayscale(0.5) hue-rotate(45deg)" },
    .{ Op.interpolate, "filter", "blur(10px)", "sepia(1)", 0.6, "sepia(1)" },
    .{ Op.add, "scale", "2", "3", 0, "6" },
    .{ Op.add, "translate", "10px", "5px 1px", 0, "15px 1px" },
    .{ Op.add, "transform", "translateX(10px)", "none", 0, "matrix(1, 0, 0, 1, 10, 0)" },
    .{ Op.add, "transform", "none", "translateX(10px)", 0, "matrix(1, 0, 0, 1, 10, 0)" },
    .{ Op.add, "margin-left", "10px", "5px", 0, "15px" },
    .{ Op.add, "opacity", "0.5", "0.75", 0, "1" },
    .{ Op.add, "color", "rgb(128, 128, 128)", "rgb(128, 0, 0)", 0, "rgb(255, 128, 128)" },
};

fn allCases(allocator: Allocator) !void {
    inline for (cases) |c| try combined(allocator, c[0], c[1], c[2], c[3], c[4], c[5]);
}

test "r3: combined computed values round-trip through the cascade" {
    try allCases(testing.allocator);
}

test "r3: combining under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allCases, .{});
}
