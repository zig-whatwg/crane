//! Interim Q81 compatibility, removed by the queued CSS URL REQUEST MODIFIERS row.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn checkFallback(allocator: std.mem.Allocator) !void {
    const text = "image-set(url(\"a.png\" cross-origin(anonymous)) 1x, \"b.png\" 2x)";
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", text, ""));
    const value = block.get(.background_image).?.value.value;
    try testing.expect(value == .text);
    try testing.expectEqualStrings(text, value.text.bytes);
    try testing.expectEqual(@as(usize, 2), value.resourceUrls().len);
    try testing.expectEqualStrings("a.png", value.resourceUrls()[0].url);
    try testing.expectEqualStrings("b.png", value.resourceUrls()[1].url);
    const range = value.resourceUrls()[0].argument_range orelse return error.ExpectedOriginalArgumentRange;
    try testing.expectEqualStrings("\"a.png\"", text[range.start..range.end]);
}

test "quoted URL modifier preserves only its whole image-set through the interim opaque path" {
    try testing.checkAllAllocationFailures(testing.allocator, checkFallback, .{});
}

test "plain image-set stays typed and unrelated invalid forms never take the fallback" {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = testing.allocator };
    try testing.expect(try block.setProperty(options, "background-image", "image-set(url(\"a.png\") 1x, \"b.png\" 2x)", ""));
    try testing.expect(block.get(.background_image).?.value.value == .image);
    for ([_][]const u8{
        "url(\"a\" b)",          "src(\"a\" b)",            "image-set()",        "image-set(none)",
        "image-set(url(a) -1x)", "image-set(url(a) 1x 2x)", "image-set(url(a),)", "image-set(image-set(url(a)))",
        "image-set(\"bad\n\")",
    }) |input| try testing.expect(!try block.setProperty(options, "background-image", input, ""));
}

test "unknown nested URL tail keeps its preexisting opaque acceptance until the modifier row" {
    // Q82: the queued CSS URL REQUEST MODIFIERS row makes this INVALID.
    // Until then, Q81 preserves the old whole-function text without parsing
    // any modifier. Direct url()/src() controls remain invalid above.
    const text = "image-set(url('a' junk";
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = testing.allocator }, "background-image", text, ""));
    const value = block.get(.background_image).?.value.value;
    try testing.expect(value == .text);
    try testing.expectEqualStrings(text, value.text.bytes);
}
