//! Lane maj6: CSS Values 4 §10.10.1 step 4 for mod() and rem() whose
//! arguments are all percentages: computable at computed-value time whatever
//! the percentages' basis (mod(aB, bB) = B·mod(a, b)), so the computed value
//! is a percentage; the specified value keeps the function. Chrome 157,
//! Firefox 160 and Safari 27.2 give mod(18%, 5%) the used value of 3%
//! (css/css-values/round-mod-rem-computed.html).
const std = @import("std");
const css = @import("css");
const math = css.math_values;
const testing = std.testing;

fn serial(text: []const u8, kind: math.Kind, want: []const u8, computed_want: []const u8) !void {
    const parsed = try math.parse(testing.allocator, text, .{ .kind = kind }) orelse return error.InvalidMath;
    defer parsed.expression.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try parsed.expression.serialize(&out, testing.allocator);
    try testing.expectEqualStrings(want, out.items);
    const computed = try parsed.expression.compute(testing.allocator, .{});
    defer computed.unref();
    out.clearRetainingCapacity();
    try computed.serialize(&out, testing.allocator);
    try testing.expectEqualStrings(computed_want, out.items);
}

test "mod() and rem() of percentages alone compute to a percentage" {
    try serial("mod(18%, 5%)", .length_percentage, "mod(18%, 5%)", "3%");
    try serial("mod(-19%, 5%)", .length_percentage, "mod(-19%, 5%)", "1%");
    try serial("rem(-18%, 5%)", .length_percentage, "rem(-18%, 5%)", "-3%");
    // A percentage beside a length still waits for the basis.
    try serial("mod(10%, 1px)", .length_percentage, "mod(10%, 1px)", "mod(10%, 1px)");
}
