//! CSS Transforms 2 §5–5.1; values without layout or matrix evaluation.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(specified, out.items);
    if (computed) |expected| {
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        out.clearRetainingCapacity();
        const property = css.properties.lookup(name) orelse return error.MissingTransformProperty;
        try style.serializeResolved(property.longhand, &out, allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
}

test "scale normalizes literal percentages and omits only default axes" {
    try check(testing.allocator, "scale", "50% 50% 100%", "0.5", "0.5");
    try check(testing.allocator, "scale", "2 2 3", "2 2 3", "2 2 3");
    try check(testing.allocator, "scale", "-100% 200% 1", "-1 2", "-1 2");
    try check(testing.allocator, "scale", "none", "none", "none");
}

test "scale keeps calculated percent units until computed value time" {
    try check(testing.allocator, "scale", "calc(200%) calc(3)", "calc(200%) calc(3)", "2 3");
    try check(testing.allocator, "scale", "calc(200% * sign(1em - 1px))", "calc(200% * sign(1em - 1px))", "2");
}

test "rotate serializes reversed principal axes and computes canonical angles" {
    try check(testing.allocator, "rotate", "-0.5 0 0 400grad", "x -400grad", "x -360deg");
    try check(testing.allocator, "rotate", "400grad 0 0 -2", "-400grad", "-360deg");
    try check(testing.allocator, "rotate", "0 0 0 400grad", "0 0 0 400grad", "0 0 0 360deg");
    try check(testing.allocator, "rotate", "400grad 1 2 3", "1 2 3 400grad", "1 2 3 360deg");
}

test "translate keeps percentages in resolved values and distinguishes zero percent" {
    try check(testing.allocator, "translate", "2em 0px 0px", "2em", "32px");
    try check(testing.allocator, "translate", "2em 0%", "2em 0%", "32px 0%");
    try check(testing.allocator, "translate", "10% 2em 3em", "10% 2em 3em", "10% 32px 48px");
    try check(testing.allocator, "translate", "0", "0px", "0px");
    try check(testing.allocator, "translate", "none", "none", "none");
}

test "individual transform grammars reject extra axes and wrong numeric types" {
    inline for (.{
        .{ "scale", "1 2 3 4" },      .{ "scale", "1px" },
        .{ "rotate", "1 2 3" },       .{ "rotate", "1 2 3 4 45deg" },
        .{ "rotate", "x y 45deg" },   .{ "translate", "1px 2px 3%" },
        .{ "translate", "none 0px" },
    }) |c| try check(testing.allocator, c[0], c[1], "", null);
}

test "individual transform calculations release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    try check(allocator, "translate", "calc(10% + 2em) 1em", "calc(10% + 2em) 1em", "calc(10% + 32px) 16px");
    try check(allocator, "scale", "calc(200%) calc(3)", "calc(200%) calc(3)", "2 3");
}

test "rotate keeps calculated axes until computation and negates owned calculated angles" {
    try check(testing.allocator, "rotate", "calc(-1) 0 0 calc(90deg)", "calc(-1) 0 0 calc(90deg)", "x -90deg");
    try check(testing.allocator, "rotate", "-1 0 0 calc(10deg)", "x calc(-10deg)", "x -10deg");
    try check(testing.allocator, "rotate", "calc(0) calc(0) calc(0) 400grad", "calc(0) calc(0) calc(0) 400grad", "0 0 0 360deg");
}
