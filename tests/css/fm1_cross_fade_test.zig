//! Images 4 §2.6: standard cross-fade's independently optional percentages.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const a = std.testing.allocator;

test "standard cross fade preserves explicit percentages without normalization" {
    inline for (.{
        .{ "cross-fade(50% red, 50% green)", "cross-fade(red 50%, green 50%)", "cross-fade(rgb(255, 0, 0) 50%, rgb(0, 128, 0) 50%)" },
        .{ "cross-fade(20% red, 20% green)", "cross-fade(red 20%, green 20%)", "cross-fade(rgb(255, 0, 0) 20%, rgb(0, 128, 0) 20%)" },
        .{ "cross-fade(red, green, blue)", "cross-fade(red, green, blue)", "cross-fade(rgb(255, 0, 0), rgb(0, 128, 0), rgb(0, 0, 255))" },
        .{ "cross-fade(50% red, 50% green, 50% blue)", "cross-fade(red 50%, green 50%, blue 50%)", "cross-fade(rgb(255, 0, 0) 50%, rgb(0, 128, 0) 50%, rgb(0, 0, 255) 50%)" },
        .{ "cross-fade(red)", "cross-fade(red)", "cross-fade(rgb(255, 0, 0))" },
    }) |case| {
        try h.check(a, "background-image", case[0], case[1], false);
        try h.check(a, "background-image", case[0], case[2], true);
    }
}

test "standard cross fade computes and clamps percentages at the outer result" {
    inline for (.{
        .{ "cross-fade(calc(101%) red, green)", "cross-fade(rgb(255, 0, 0) 100%, rgb(0, 128, 0))" },
        .{ "cross-fade(calc(-200%) red, green)", "cross-fade(rgb(255, 0, 0) 0%, rgb(0, 128, 0))" },
        .{ "cross-fade(calc(50% + 1% * sign(1em - 10000px)) red, green)", "cross-fade(rgb(255, 0, 0) 49%, rgb(0, 128, 0))" },
    }) |case| try h.check(a, "background-image", case[0], case[1], true);
}

test "standard cross fade rejects malformed weights and components" {
    inline for (.{ "cross-fade()", "cross-fade(red,)", "cross-fade(,red)", "cross-fade(none, red)", "cross-fade(red 101%, green)", "cross-fade(red -1%, green)", "cross-fade(20% red 30%, green)", "cross-fade(red 0.5, green)", "cross-fade(red green)" }) |input|
        try h.check(a, "background-image", input, "", false);
}

fn currentColor(allocator: h.Allocator) !void {
    var block = try h.Block.parse(.{ .allocator = allocator }, "color:red;background-image:cross-fade(30% color-mix(in srgb, currentcolor, blue), white)");
    defer block.deinit();
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, "background-image", "cross-fade(color(srgb 0.5 0 0.5) 30%, rgb(255, 255, 255))", allocator);
}

test "standard cross fade resolves currentcolor through nested color functions" {
    try currentColor(a);
}

fn retained(allocator: h.Allocator) !void {
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://example.test/sheet.css", .referrer_policy = "no-referrer" });
    var source_owned = true;
    defer if (source_owned) source.unref();
    var block = try h.Block.parse(.{ .allocator = allocator, .resource_source = source }, "list-style-image:cross-fade(url(a) 20%, cross-fade(url(b), red) 30%, blue)");
    var block_owned = true;
    defer if (block_owned) block.deinit();
    const original = (block.get(.list_style_image) orelse return error.MissingCrossFade).value.value;
    try std.testing.expect(original == .image);
    const copy = try css.image_values.Image.create(allocator, original.image.data);
    defer copy.unref();
    try std.testing.expect(original.image.eql(copy));
    block.deinit();
    block_owned = false;
    source.unref();
    source_owned = false;
    const urls = copy.text.resource_urls;
    try std.testing.expectEqual(@as(usize, 2), urls.len);
    try std.testing.expectEqualStrings("a", urls[0].url);
    try std.testing.expectEqualStrings("b", urls[1].url);
    try std.testing.expectEqualStrings("https://example.test/sheet.css", urls[0].source.?.base_url);
    try std.testing.expectEqualStrings("no-referrer", urls[1].source.?.referrer_policy);
}

test "standard cross fade copies retain nested images and source metadata" {
    try retained(a);
}

test "legacy cross fade keeps its pair and normalized progress serialization" {
    try h.check(a, "background-image", "-webkit-cross-fade(url(a), url(b), 50%)", "-webkit-cross-fade(url(\"a\"), url(\"b\"), 0.5)", false);
    try h.check(a, "background-image", "-webkit-cross-fade(url(a), url(b), 2)", "-webkit-cross-fade(url(\"a\"), url(\"b\"), 1)", false);
}

test "standard and mixed cross fades share the existing 128 level image bound" {
    // Q29: crossing a legacy/standard boundary never resets image depth.
    inline for (.{ false, true }) |mixed| {
        for ([_]usize{ 128, 129 }) |depth| {
            var input: std.ArrayList(u8) = .empty;
            defer input.deinit(a);
            for (0..depth) |index| try input.appendSlice(a, if (mixed and index % 2 == 1) "-webkit-cross-fade(" else "cross-fade(");
            try input.appendSlice(a, "url(\"a\")");
            var index = depth;
            while (index > 0) {
                index -= 1;
                try input.appendSlice(a, if (mixed and index % 2 == 1) ", url(\"b\"), 0.5)" else ")");
            }
            try h.check(a, "background-image", input.items, if (depth == 128) input.items else "", false);
        }
    }
}

test "cross fade releases nested payloads through all allocation failures" {
    try std.testing.checkAllAllocationFailures(a, currentColor, .{});
    try std.testing.checkAllAllocationFailures(a, retained, .{});
    try std.testing.checkAllAllocationFailures(a, h.check, .{ "background-image", "cross-fade(calc(101%) red, green)", "cross-fade(rgb(255, 0, 0) 100%, rgb(0, 128, 0))", true });
}
