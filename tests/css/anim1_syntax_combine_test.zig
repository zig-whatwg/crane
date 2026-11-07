//! Lane anim1: registered custom properties combine "by computed value, in
//! accordance with the type that they parsed as" (CSS Properties and Values
//! API 1 2.5): css.interpolation.combineSyntax over two computed syntax
//! values, serialized as getComputedStyle returns them. Lists combine item by
//! item and only at equal lengths; <transform-list> (and
//! <transform-function>+) combine as the transform property (Transforms 2
//! 14-15: addition concatenates, accumulation is per function with one-based
//! scale parameters; different functions as decomposed matrices); a pair
//! with no smooth rule is null, for the caller to
//! combine discretely.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const interpolation = css.interpolation;

fn computed(allocator: Allocator, definition: *const css.syntax_definitions.Definition, text: []const u8) !css.syntax_values.Value {
    var specified = (try definition.parseValue(.{ .allocator = allocator }, text)) orelse return error.Rejected;
    defer specified.deinit();
    return specified.compute(allocator, .{});
}

/// combineSyntax(from, to, p, op) under `syntax`, serialized; "" for null.
fn combine(allocator: Allocator, syntax: []const u8, from: []const u8, to: []const u8, p: f64, op: interpolation.SyntaxOp, expected: []const u8) !void {
    var definition = try css.syntax_definitions.parse(allocator, syntax);
    defer definition.deinit();
    var a = try computed(allocator, &definition, from);
    defer a.deinit();
    var b = try computed(allocator, &definition, to);
    defer b.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (try interpolation.combineSyntax(allocator, &a, &b, p, op)) |result| {
        var r = result;
        defer r.deinit();
        try r.serialize(&out, allocator);
    }
    try testing.expectEqualStrings(expected, out.items);
}

test "numeric syntaxes interpolate, add and accumulate as their type" {
    const a = testing.allocator;
    try combine(a, "<length>", "100px", "200px", 0.5, .interpolate, "150px");
    try combine(a, "<length>", "100px", "250px", 1, .add, "350px");
    try combine(a, "<number>", "100", "200", 0.5, .interpolate, "150");
    try combine(a, "<percentage>", "100%", "200%", 0.5, .interpolate, "150%");
    try combine(a, "<angle>", "100deg", "200deg", 0.5, .interpolate, "150deg");
    try combine(a, "<time>", "100s", "200s", 0.5, .interpolate, "150s");
    try combine(a, "<resolution>", "100dppx", "200dppx", 0.5, .interpolate, "150dppx");
    try combine(a, "<length>", "100px", "100px", 1, .accumulate, "200px");
}

test "an <integer> interpolates as a real number, then rounds half up" {
    const a = testing.allocator;
    try combine(a, "<integer>", "100", "200", 0.5, .interpolate, "150");
    try combine(a, "<integer>", "0", "1", 0.5, .interpolate, "1");
    try combine(a, "<integer>", "100", "250", 1, .add, "350");
}

test "a <length-percentage> of two units is a calc() mix" {
    const a = testing.allocator;
    try combine(a, "<length-percentage>", "100px", "100%", 0.5, .interpolate, "calc(50% + 50px)");
    try combine(a, "<length-percentage>", "50px", "100%", 1, .add, "calc(100% + 50px)");
}

test "legacy colors interpolate and add in premultiplied sRGB" {
    const a = testing.allocator;
    try combine(a, "<color>", "rgb(100, 100, 100)", "rgb(200, 200, 200)", 0.5, .interpolate, "rgb(150, 150, 150)");
    try combine(a, "<color>", "rgb(100, 100, 100)", "rgb(100, 100, 100)", 1, .add, "rgb(200, 200, 200)");
}

test "lists combine item by item, only at equal lengths" {
    const a = testing.allocator;
    try combine(a, "<length>+", "100px 150px", "200px 250px", 0.5, .interpolate, "150px 200px");
    try combine(a, "<percentage>#", "100%, 150%", "200%, 250%", 0.5, .interpolate, "150%, 200%");
    try combine(a, "<length>+", "100px", "200px 250px", 0.5, .interpolate, "");
}

test "a <transform-function> combines argument by argument" {
    const a = testing.allocator;
    try combine(a, "<transform-function>", "translateX(100px)", "translateX(200px)", 0.5, .interpolate, "translateX(150px)");
    // A single function's addition is the function's: the sum of its arguments.
    try combine(a, "<transform-function>", "translateX(100px)", "translateX(250px)", 1, .add, "translateX(350px)");
    // Different functions interpolate as decomposed matrices (Transforms 2
    // section 14, 2D: Transforms 1 11.2): translate 50px, rotate 5deg.
    try combine(a, "<transform-function>", "translateX(100px)", "rotate(10deg)", 0.5, .interpolate, "matrix(0.996195, 0.087156, -0.087156, 0.996195, 50, 0)");
}

test "a <transform-list> combines as the transform property" {
    const a = testing.allocator;
    try combine(a, "<transform-list>", "translateX(100px) scale(2)", "translateX(200px) scale(4)", 0.5, .interpolate, "translateX(150px) scale(3)");
    // Addition appends (Transforms 2 15).
    try combine(a, "<transform-list>", "translateX(100px) scale(2)", "translateX(250px) scale(3.5)", 1, .add, "translateX(100px) scale(2) translateX(250px) scale(3.5)");
    // Accumulation adds each argument; a scale parameter is one-based: a + b - 1.
    try combine(a, "<transform-list>", "translateX(100px) scale(4)", "translateX(150px) scale(3.5)", 1, .accumulate, "translateX(250px) scale(6.5)");
    // Transforms 1 9: the shorter list is extended with identity functions
    // matching the longer list's.
    try combine(a, "<transform-list>", "translateX(100px)", "translateX(100px) translateX(300px)", 0.5, .interpolate, "translateX(100px) translateX(150px)");
    try combine(a, "<transform-list>", "scale(2) rotate(90deg)", "scale(4)", 0.5, .interpolate, "scale(3) rotate(45deg)");
    // Different functions at one position: the rest of each list
    // interpolates as a decomposed matrix (Transforms 1 section 9).
    try combine(a, "<transform-list>", "translateX(100px) scale(2)", "rotate(180deg)", 0.5, .interpolate, "matrix(0, -1.5, 1.5, 0, 50, 0)");
}

test "discrete syntaxes have no smooth combination" {
    const a = testing.allocator;
    try combine(a, "<custom-ident>", "foo", "bar", 0.5, .interpolate, "");
    try combine(a, "*", "foo", "bar", 0.5, .interpolate, "");
}

test "combining survives every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, combine, .{ "<length-percentage>", "100px", "100%", 0.5, interpolation.SyntaxOp.interpolate, "calc(50% + 50px)" });
    try testing.checkAllAllocationFailures(testing.allocator, combine, .{ "<transform-list>", "translateX(100px) scale(2)", "translateX(200px) scale(4)", 0.5, interpolation.SyntaxOp.interpolate, "translateX(150px) scale(3)" });
    try testing.checkAllAllocationFailures(testing.allocator, combine, .{ "<transform-list>", "translateX(100px)", "translateX(100px) translateX(300px)", 0.5, interpolation.SyntaxOp.interpolate, "translateX(100px) translateX(150px)" });
}
