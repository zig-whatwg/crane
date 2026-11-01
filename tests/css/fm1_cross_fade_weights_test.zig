//! Images4 §2.6: effective weights do not rewrite the authored CSSOM list.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const a = std.testing.allocator;

fn check(allocator: h.Allocator, input: []const u8, expected: []const f64) anyerror!void {
    var block = try h.Block.parse(.{ .allocator = allocator }, "");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "list-style-image", input, "");
    const specified = (block.get(.list_style_image) orelse return error.MissingCrossFade).value.value;
    try std.testing.expect(specified == .image and specified.image.data == .standard_cross_fade);
    try std.testing.expectEqual(@as(?f64, null), specified.image.data.standard_cross_fade.effectivePercentage(0));
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    const computed = style.get(.list_style_image);
    try std.testing.expect(computed == .image and computed.image.data == .standard_cross_fade);
    const fade = computed.image.data.standard_cross_fade;
    try std.testing.expectEqual(expected.len, fade.items.len);
    for (expected, 0..) |weight, index| try std.testing.expectApproxEqAbs(weight, fade.effectivePercentage(index).?, 1e-10);
    try std.testing.expectEqual(@as(?f64, null), fade.effectivePercentage(expected.len));
}

test "standard cross fade effective weights fill omissions and retain explicit oversums" {
    try check(a, "cross-fade(red, green)", &.{ 50, 50 });
    try check(a, "cross-fade(red 20%, green, blue)", &.{ 20, 40, 40 });
    try check(a, "cross-fade(red 80%, green 70%, blue)", &.{ 80, 70, 0 });
    try check(a, "cross-fade(red 20%, green 20%)", &.{ 20, 20 });
    try check(a, "cross-fade(red 0%, green 0%)", &.{ 0, 0 });
    try check(a, "cross-fade(red calc(101%), green)", &.{ 100, 0 });
}

test "standard cross fade computes nested structure without inventing image equality" {
    try h.check(a, "background-image", "cross-fade(red 20%, cross-fade(blue, green) 80%)", "cross-fade(rgb(255, 0, 0) 20%, cross-fade(rgb(0, 0, 255), rgb(0, 128, 0)) 80%)", true);
    try h.check(a, "background-image", "cross-fade(red, red)", "cross-fade(rgb(255, 0, 0), rgb(255, 0, 0))", true);
}

test "standard cross fade effective weights own no additional allocations" {
    try std.testing.checkAllAllocationFailures(a, check, .{ "cross-fade(red 20%, green, blue)", &[_]f64{ 20, 40, 40 } });
}
