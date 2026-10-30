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
