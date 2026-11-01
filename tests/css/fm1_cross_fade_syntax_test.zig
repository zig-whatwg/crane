//! Images4 §2.6: registered image computation supplies typed math weights.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn check(allocator: std.mem.Allocator, input: []const u8, expected: []const f64, css_text: []const u8) anyerror!void {
    var definition = try css.syntax_definitions.parse(allocator, "<image>");
    defer definition.deinit();
    var specified = (try definition.parseValue(.{ .allocator = allocator }, input)) orelse return error.ExpectedImage;
    defer specified.deinit();
    const authored = specified.data.single.image.value.image.data.standard_cross_fade;
    try std.testing.expectEqual(@as(?f64, null), authored.effectivePercentage(0));
    var computed = try specified.compute(allocator, .{});
    defer computed.deinit();
    const fade = computed.data.single.image.value.image.data.standard_cross_fade;
    try std.testing.expectEqual(expected.len, fade.items.len);
    for (expected, 0..) |weight, index| {
        const actual = fade.effectivePercentage(index) orelse return error.ExpectedEffectiveWeight;
        try std.testing.expectApproxEqAbs(weight, actual, 1e-10);
    }
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try specified.serialize(&out, allocator);
    try std.testing.expectEqualStrings(input, out.items);
    out.clearRetainingCapacity();
    try computed.serialize(&out, allocator);
    try std.testing.expectEqualStrings(css_text, out.items);
}

test "registered image cross fade exposes computed math weights without rewriting CSSOM omissions" {
    try check(a, "cross-fade(red calc(20%), blue)", &.{ 20, 80 }, "cross-fade(rgb(255, 0, 0) 20%, rgb(0, 0, 255))");
    try check(a, "cross-fade(red calc(150%), blue)", &.{ 100, 0 }, "cross-fade(rgb(255, 0, 0) 100%, rgb(0, 0, 255))");
    try check(a, "cross-fade(red calc(-10%), blue)", &.{ 0, 100 }, "cross-fade(rgb(255, 0, 0) 0%, rgb(0, 0, 255))");
    try check(a, "cross-fade(red calc(80%), blue 70%, green)", &.{ 80, 70, 0 }, "cross-fade(rgb(255, 0, 0) 80%, rgb(0, 0, 255) 70%, rgb(0, 128, 0))");
}

test "registered image cross fade computed math weight accessor survives every allocation failure" {
    try std.testing.checkAllAllocationFailures(a, check, .{ "cross-fade(red calc(20%), blue)", &[_]f64{ 20, 80 }, "cross-fade(rgb(255, 0, 0) 20%, rgb(0, 0, 255))" });
}
