//! Fonts4 §2.3: font-width's computed initial value is the percentage 100%.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectWidth(style: *const css.computed_style.ComputedStyle, wanted: f64) !void {
    const value = style.get(.font_width);
    try testing.expect(value == .length);
    try testing.expectEqual(css.style_values.LengthUnit.percent, value.length.unit);
    try testing.expectEqual(wanted, value.length.value);
}

fn initial(allocator: std.mem.Allocator) !void {
    const style = try css.computed_style.ComputedStyle.initial(allocator);
    defer style.destroy();
    try expectWidth(style, 100);
}
fn cascadeDefaults(allocator: std.mem.Allocator) !void {
    for ([_][]const u8{ "", "font-width:inherit", "font-width:initial", "font-width:unset" }) |input| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try expectWidth(style, 100);
    }
}
fn inherited(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-width:condensed");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    try expectWidth(child, 75);
}

test "font width's initial computed style holds a percentage" {
    try testing.checkAllAllocationFailures(testing.allocator, initial, .{});
}
test "font width's root defaults and CSS wide values use the computed initial percentage" {
    try testing.checkAllAllocationFailures(testing.allocator, cascadeDefaults, .{});
}
test "font width still inherits a parent's computed noninitial percentage" {
    try testing.checkAllAllocationFailures(testing.allocator, inherited, .{});
}
