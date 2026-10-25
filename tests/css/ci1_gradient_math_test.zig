//! Images4 §§3.1–3.5; Q55 typed conic components and Q137 pair positions.
//! Q138 keeps the old opaque-leaf policy without vetoing a typed declaration.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn direct(allocator: Allocator, input: []const u8, expected: []const u8) !void {
    var stream = css.properties.Stream.init(input);
    const value = try css.image_values.parse(.{ .allocator = allocator }, &stream, .{}) orelse return error.ExpectedImage;
    defer value.release();
    try testing.expect(stream.atEnd());
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try css.properties.serializeValue(.background_image, value, &text, allocator);
    try testing.expectEqualStrings(expected, text.items);
}

test "typed gradient grammar accepts angle-percentage math before declaration prefiltering" {
    try testing.checkAllAllocationFailures(testing.allocator, direct, .{ "conic-gradient(red calc(90deg + 50%), blue)", "conic-gradient(red calc(50% + 90deg), blue)" });
    try testing.checkAllAllocationFailures(testing.allocator, direct, .{ "conic-gradient(red, calc(0deg + 100%), blue)", "conic-gradient(red, calc(100% + 0deg), blue)" });
}

fn accepts(allocator: Allocator, name: []const u8, input: []const u8, expected: bool) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expectEqual(expected, try block.setProperty(.{ .allocator = allocator }, name, input, ""));
    if (expected and (std.mem.eql(u8, name, "list-style-image") or std.mem.eql(u8, name, "content")) and
        (std.mem.startsWith(u8, input, "paint(") or std.mem.startsWith(u8, input, "image-set(")))
    {
        var serialized: std.ArrayList(u8) = .empty;
        defer serialized.deinit(allocator);
        try block.getPropertyValue(name, &serialized);
        try testing.expectEqualStrings(input, serialized.items);
    }
}

test "typed gradient math reaches declarations and shorthand images" {
    for ([_][]const u8{ "background-image", "background", "border-image-source", "content" }) |name| {
        for ([_][]const u8{
            "conic-gradient(red calc(90deg + 50%), blue)",
            "linear-gradient(red calc(2px + 3%), blue)",
            "linear-gradient(rgb(calc(100 + 20) 0 0), blue)",
        }) |input| try testing.checkAllAllocationFailures(testing.allocator, accepts, .{ name, input, true });
    }
}

test "opaque generated-image leaves keep their previous background-only math rejection" {
    // These are deliberately the retained opaque grammar, not a claim that
    // paint()'s arguments implement a new Houdini grammar in this delivery.
    const input = "paint(example, calc(1px + 2px))";
    for ([_][]const u8{ "background-image", "background" }) |name|
        try testing.checkAllAllocationFailures(testing.allocator, accepts, .{ name, input, false });
    for ([_][]const u8{ "list-style-image", "content" }) |name|
        try testing.checkAllAllocationFailures(testing.allocator, accepts, .{ name, input, true });
}

fn computed(allocator: Allocator, input: []const u8, expected: []const u8) !void {
    const child = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", input, ""));
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:10px;background-image:inherit");
        defer inherited.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(.background_image, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "computed gradient pair math retains parent lengths and unresolved percentage complements" {
    const Case = struct { input: []const u8, expected: []const u8 };
    for ([_]Case{
        // Pinned background-image-computed.sub.html:42 and
        // border-image-source-computed.sub.html:27, with the same font40px.
        .{ .input = "radial-gradient(circle calc(-0.5em + 10px) at calc(-1em + 10px) calc(-2em + 10px), red, blue)", .expected = "radial-gradient(0px at -30px -70px, rgb(255, 0, 0), rgb(0, 0, 255))" },
        .{ .input = "radial-gradient(circle at calc(50% * 2 / 4) 40%, red, blue)", .expected = "radial-gradient(circle at 25% 40%, rgb(255, 0, 0), rgb(0, 0, 255))" },
        .{ .input = "conic-gradient(at right calc(10% + 1em) bottom calc(20% + 5px), red, blue)", .expected = "conic-gradient(at calc(90% - 40px) calc(80% - 5px), rgb(255, 0, 0), rgb(0, 0, 255))" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{ case.input, case.expected });
}

fn dependencies(allocator: Allocator, input: []const u8, tree: bool, random: bool) !void {
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", input, ""));
        const value = (block.get(.background_image) orelse return error.ExpectedImage).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
    try testing.expect(!value.needsUnavailableMetrics(false));
}

test "gradient pair math forwards real tree and random dependencies after declaration release" {
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "radial-gradient(at calc(sibling-index() * 1px) center, red, blue)", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "conic-gradient(at center random(2px, 4px), red, blue)", false, true });
    try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ "conic-gradient(at random(fixed 0.5, 2px, 4px) center, red, blue)", false, false });
}

test "opaque URL-modifier fallback retains background math rejection and other-property acceptance" {
    // Q81/Q82's old whole-function fallback stays opaque until its owner
    // delivers request modifiers. Q138 must not loosen its background veto.
    const input = "image-set(url('a' junk(calc(1px + 2px))), url('b'))";
    for ([_][]const u8{ "background-image", "background" }) |name|
        try testing.checkAllAllocationFailures(testing.allocator, accepts, .{ name, input, false });
    for ([_][]const u8{ "list-style-image", "content" }) |name|
        try testing.checkAllAllocationFailures(testing.allocator, accepts, .{ name, input, true });
}
