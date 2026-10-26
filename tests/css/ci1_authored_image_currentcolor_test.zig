//! DRAFT / UNRUN. Depends on accepted Q115 CSSOM helper, after f + Q166.
//! Color4 §15.5: inherited currentcolor stays symbolic until receiver resolution.
//! This is separate from Q166's already evidenced red/transparent computation.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Longhand = css.properties.Longhand;
const Value = css.style_values.Value;

fn inheritance(allocator: Allocator, longhand: Longhand, input: []const u8, expected: []const u8) !void {
    var original: ?Value = null;
    defer if (original) |value| value.release();
    const child = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:red;color-scheme:light");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, longhand.name(), input, ""));
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        original = parent.get(longhand);
        original.?.retain();
        var inherit = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:blue;color-scheme:dark");
        defer inherit.deinit();
        try testing.expect(try inherit.setProperty(.{ .allocator = allocator }, longhand.name(), "inherit", ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherit, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    var symbolic: std.ArrayList(u8) = .empty;
    defer symbolic.deinit(allocator);
    try css.properties.serializeValue(longhand, original.?, &symbolic, allocator);
    try testing.expect(std.mem.indexOf(u8, symbolic.items, "currentcolor") != null);
    var resolved: std.ArrayList(u8) = .empty;
    defer resolved.deinit(allocator);
    try child.serializeResolved(longhand, &resolved, allocator);
    try testing.expectEqualStrings(expected, resolved.items);
    try testing.expect(original.?.eql(child.get(longhand)));
    var unchanged: std.ArrayList(u8) = .empty;
    defer unchanged.deinit(allocator);
    try css.properties.serializeValue(longhand, original.?, &unchanged, allocator);
    try testing.expectEqualStrings(symbolic.items, unchanged.items);
}

test "authored image currentcolor stays symbolic after parent release and resolves at receiver" {
    for ([_]Longhand{ .background_image, .list_style_image, .border_image_source, .mask_image, .mask_border_source, .content }) |longhand|
        try testing.checkAllAllocationFailures(testing.allocator, inheritance, .{ longhand, "image(currentcolor)", "image(rgb(0, 0, 255))" });
}

test "authored image computes light dark before opposite scheme inheritance but retains currentcolor" {
    for ([_]Longhand{ .background_image, .content }) |longhand|
        try testing.checkAllAllocationFailures(testing.allocator, inheritance, .{ longhand, "image(light-dark(currentcolor, red))", "image(rgb(0, 0, 255))" });
}

test "authored image nested relative currentcolor resolves through the Color owner API" {
    for ([_]Longhand{ .background_image, .content }) |longhand|
        try testing.checkAllAllocationFailures(testing.allocator, inheritance, .{ longhand, "image(rgb(from currentcolor r g b))", "image(color(srgb 0 0 1))" });
}

fn noAllocation(longhand: Longhand, input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, longhand.name(), input, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const Style = @TypeOf(style.*);
    if (comptime !@hasDecl(Style, "resolvedImageValue")) return error.Q115ResolvedImageValueNotImplemented;
    var fail = testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const resolved = try style.resolvedImageValue(longhand, fail.allocator());
    defer resolved.release();
    try testing.expect(resolved.eql(style.get(longhand)));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, 4096);
    try style.serializeResolved(longhand, &out, fail.allocator());
    try testing.expectEqualStrings(expected, out.items);
}

test "authored absolute or selected away currentcolor keeps the Q115 no allocation route" {
    for ([_]Longhand{ .background_image, .content }) |longhand| {
        try noAllocation(longhand, "image(red)", "image(rgb(255, 0, 0))");
        try noAllocation(longhand, "image(light-dark(red, currentcolor))", "image(rgb(255, 0, 0))");
    }
}
