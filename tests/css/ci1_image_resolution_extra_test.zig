//! DRAFT / UNRUN. Supplement to the immutable Q147 native7/Crane48 package.
//! Q146 semantics; Syntax3 §5.5.10 EOF; Values4 §§2.2,7.4.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn requireProperty() !void {
    if (css.properties.lookup("image-resolution") == null) return error.ImageResolutionNotImplemented;
}

fn eofAndConversion(allocator: Allocator, input: []const u8, specified: []const u8, computed: []const u8) !void {
    const property = css.properties.lookup("image-resolution").?;
    const style = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "image-resolution", input, ""));
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try block.getPropertyValue("image-resolution", &text);
        try testing.expectEqualStrings(specified, text.items);
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try style.serializeResolved(property.longhand, &text, allocator);
    try testing.expectEqualStrings(computed, text.items);
}

test "image resolution closes valid math at EOF and converts nonzero dpcm" {
    try requireProperty();
    try testing.checkAllAllocationFailures(testing.allocator, eofAndConversion, .{ "calc(96dpi", "calc(1dppx)", "1dppx" });
    try testing.checkAllAllocationFailures(testing.allocator, eofAndConversion, .{ "4800dpcm", "4800dpcm", "127dppx" });
}

fn invalidDoesNotReplace(allocator: Allocator, input: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = allocator };
    try testing.expect(try block.setProperty(options, "image-resolution", "2dppx", "important"));
    try testing.expect(!try block.setProperty(options, "image-resolution", input, ""));
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue("image-resolution", &text);
    try testing.expectEqualStrings("2dppx", text.items);
}

test "image resolution rejects malformed EOF and unmatched delimiters without replacing a declaration" {
    try requireProperty();
    for ([_][]const u8{ "calc(", "calc(1dppx +", "calc(1dppx]", "1dppx)", "1dppx extra", "from-image snap 2dppx", "2dppx snap from-image" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, invalidDoesNotReplace, .{input});
}
