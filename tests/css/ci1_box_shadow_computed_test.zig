//! Backgrounds3 API shape only; see BORDERS4-DELTA.md for superseded assumptions.
//! Q170 preparation only. UNRUN. Backgrounds3 §6.1 + Color4 §15.5 + CSSOM §9.
//! Existing public APIs only; no Color implementation or future shadow tag.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = struct { input: []const u8, expected: []const u8 };

fn property() !css.properties.Property {
    return css.properties.lookup("box-shadow") orelse error.BoxShadowNotImplemented;
}

fn computeCase(allocator: Allocator, case: Case) !void {
    const p = try property();
    const style = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:blue;font-size:20px");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "box-shadow", case.input, ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(p.longhand, &out, allocator);
    try testing.expectEqualStrings(case.expected, out.items);
}

test "ci1 box shadow computed defaults signed spread typed math and color" {
    for ([_]Case{
        .{ .input = "none", .expected = "none" },
        .{ .input = "1px 2px", .expected = "rgb(0, 0, 255) 1px 2px 0px 0px" },
        .{ .input = "currentcolor -1em -2em 3em -4em", .expected = "rgb(0, 0, 255) -20px -40px 60px -80px" },
        .{ .input = "rgb(0, 255, 0) 1px 2px 3px 4px inset", .expected = "rgb(0, 255, 0) 1px 2px 3px 4px inset" },
        .{ .input = "red 1px 2px calc(-1px) -4px", .expected = "rgb(255, 0, 0) 1px 2px 0px -4px" },
        .{ .input = "red 1px 2px calc(min(-1px, 2px) + 3px)", .expected = "rgb(255, 0, 0) 1px 2px 2px 0px" },
        .{ .input = "transparent 1in .5in, inset 1em 2em 3em -4em", .expected = "rgba(0, 0, 0, 0) 96px 48px 0px 0px, rgb(0, 0, 255) 20px 40px 60px -80px inset" },
        .{ .input = "color(display-p3 1 0 0) 1px 2px", .expected = "color(display-p3 1 0 0) 1px 2px 0px 0px" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computeCase, .{case});
}

fn inheritance(allocator: Allocator, shadow: []const u8) !void {
    const p = try property();
    var original: ?css.style_values.Value = null;
    defer if (original) |value| value.release();
    const child = blk: {
        var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:red;font-size:20px");
        defer parent_block.deinit();
        const input = try allocator.dupe(u8, shadow);
        defer allocator.free(input);
        try testing.expect(try parent_block.setProperty(.{ .allocator = allocator }, "box-shadow", input, ""));
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        original = parent.get(p.longhand);
        original.?.retain();
        var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:green;font-size:10px;box-shadow:inherit");
        defer child_block.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    // Parent, both declaration blocks, and the authored input are gone.
    try testing.expect(original.?.eql(child.get(p.longhand)));
    var symbolic: std.ArrayList(u8) = .empty;
    defer symbolic.deinit(allocator);
    try css.properties.serializeValue(p.longhand, original.?, &symbolic, allocator);
    try testing.expect(std.mem.indexOf(u8, symbolic.items, "currentcolor") != null);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(p.longhand, &out, allocator);
    try testing.expectEqualStrings("rgb(0, 128, 0) 20px 2px 0px -40px inset", out.items);
    var unchanged: std.ArrayList(u8) = .empty;
    defer unchanged.deinit(allocator);
    try css.properties.serializeValue(p.longhand, original.?, &unchanged, allocator);
    try testing.expectEqualStrings(symbolic.items, unchanged.items);
}

test "ci1 box shadow inherited symbolic color survives parent and declaration destruction" {
    for ([_][]const u8{ "inset 1em 2px 0 -2em", "currentcolor 1em 2px 0 -2em inset" }) |shadow|
        try testing.checkAllAllocationFailures(testing.allocator, inheritance, .{shadow});
}

fn initialAndReset(allocator: Allocator, input: []const u8) !void {
    const p = try property();
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "box-shadow:red 1px 2px");
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(p.longhand, &out, allocator);
    try testing.expectEqualStrings("none", out.items);
    try testing.expect(!p.longhand.inherited());
    try testing.expect(p.longhand.info().initial.isKeyword(.none));
    try testing.expect(css.computed_style.initialComputed(p.longhand).isKeyword(.none));
}

test "ci1 box shadow initial unset revert and all reset use none without inheritance" {
    for ([_][]const u8{ "", "box-shadow:initial", "box-shadow:unset", "box-shadow:revert", "box-shadow:revert-layer", "box-shadow:blue 3px 4px;all:initial", "box-shadow:blue 3px 4px;all:unset" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, initialAndReset, .{input});
}

fn noIntermediateAllocation(allocator: Allocator, input: []const u8, expected: []const u8) !void {
    const p = try property();
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "box-shadow", input, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, 1024);
    var fail = testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try style.serializeResolved(p.longhand, &out, fail.allocator());
    try testing.expectEqualStrings(expected, out.items);
}

test "ci1 box shadow absolute and selected away currentcolor CSSOM avoids intermediate allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, noIntermediateAllocation, .{ "red 1px 2px", "rgb(255, 0, 0) 1px 2px 0px 0px" });
    try testing.checkAllAllocationFailures(testing.allocator, noIntermediateAllocation, .{ "light-dark(red, currentcolor) 1px 2px", "rgb(255, 0, 0) 1px 2px 0px 0px" });
}

fn nestedColor(allocator: Allocator, color: []const u8) !void {
    const p = try property();
    const input = try std.mem.concat(allocator, u8, &.{ color, " 1px 2px" });
    defer allocator.free(input);
    const child = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:red;color-scheme:light");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "box-shadow", input, ""));
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-color", color, ""));
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var inherit = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:blue;color-scheme:dark;box-shadow:inherit;background-color:inherit");
        defer inherit.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherit, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    // The stable public Color owner provides its canonical resolved spelling.
    // This tests the aggregate bridge without inspecting its expression graph.
    try child.serializeResolved(.background_color, &expected, allocator);
    try expected.appendSlice(allocator, " 1px 2px 0px 0px");
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    try child.serializeResolved(p.longhand, &actual, allocator);
    try testing.expectEqualStrings(expected.items, actual.items);
}

test "ci1 box shadow nested Color owner expressions inherit and resolve against the receiver" {
    for ([_][]const u8{ "currentcolor", "rgb(from currentcolor r g b)", "color-mix(in srgb, currentcolor, currentcolor)", "light-dark(currentcolor, red)" }) |color|
        try testing.checkAllAllocationFailures(testing.allocator, nestedColor, .{color});
}
