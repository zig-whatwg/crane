//! CSS Typed OM §3; Chrome 156/Safari 27 probe Q57–Q58, 2026-10-27.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Block = css.declarations.DeclarationBlock;

test "Typed OM property-name strings exclude bare double dash and preserve custom case and spaces" {
    if (comptime !@hasDecl(css.typed_om, "property_names")) return std.testing.expect(false);
    const names = css.typed_om.property_names;
    try std.testing.expect(names.lookup("--") == null);
    try std.testing.expect(names.lookup("bogus") == null);
    try std.testing.expect((names.lookup("--x y") orelse return error.MissingProperty) == .custom);
    try std.testing.expectEqualStrings("-- ", (names.lookup("-- ") orelse return error.MissingProperty).custom);
    try std.testing.expectEqualStrings("--X", (names.lookup("--X") orelse return error.MissingProperty).custom);
    try std.testing.expectEqual(css.properties.Longhand.width, (names.lookup("width") orelse return error.MissingProperty).ordinary.longhand);
}

fn nativeWrite(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(Block, "setValidatedProperty")) return std.testing.expect(false);
    var block = try Block.parse(.{ .allocator = allocator }, "width:1px!important;color:red");
    defer block.deinit();
    var committed = false;
    errdefer if (!committed) {
        std.debug.assert(block.entries.items.len == 2);
        std.debug.assert(block.get(.width).?.important);
        std.debug.assert(block.get(.width).?.value.value.length.value == 1);
        std.debug.assert(std.mem.eql(u8, block.item(0).?, "width"));
    };
    const assignment: css.properties.Assignment = .{ .longhand = .width, .value = .{ .value = .{ .length = .{ .value = 2, .unit = .px } } } };
    try std.testing.expect(try block.setValidatedProperty(.{ .longhand = .width }, &.{assignment}));
    committed = true;
    try std.testing.expect(!block.get(.width).?.important);
    try std.testing.expectEqualStrings("width", block.item(0).?);
    try std.testing.expectEqualStrings("color", block.item(1).?);
    try std.testing.expectEqual(@as(f64, 2), block.get(.width).?.value.value.length.value);
    try std.testing.expectError(error.Invalid, block.setValidatedProperty(.{ .longhand = .height }, &.{assignment}));
    try std.testing.expectEqual(@as(f64, 2), block.get(.width).?.value.value.length.value);
    try std.testing.expectEqual(@as(usize, 2), block.entries.items.len);
}

test "native Typed OM writes are atomic and clear important without moving an ordinary declaration" {
    try std.testing.checkAllAllocationFailures(a, nativeWrite, .{});
}

fn customWrite(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(Block, "setValidatedCustom")) return std.testing.expect(false);
    var block = try Block.parse(.{ .allocator = allocator }, "color:red;--X:1!important");
    defer block.deinit();
    const value = (try css.custom_properties.parse(.{ .allocator = allocator }, "var(--y, 2px)")) orelse return error.TestUnexpectedResult;
    defer value.release();
    try std.testing.expectError(error.Invalid, block.setValidatedCustom("--", value));
    try std.testing.expect(block.getCustom("--X").?.important);
    try std.testing.expect(try block.setValidatedCustom("--X", value));
    try std.testing.expect(!block.getCustom("--X").?.important);
    try std.testing.expectEqualStrings("--X", block.item(1).?);
    try std.testing.expect(try block.setValidatedCustom("--x y", value));
    try std.testing.expect(block.getCustom("--x y") != null);
    try std.testing.expect(try block.setValidatedCustom("-- ", value));
    try std.testing.expect(block.getCustom("-- ") != null);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.serialize(&text);
    try std.testing.expect(std.mem.indexOf(u8, text.items, "--x\\ y:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text.items, "--\\ :") != null);
}

test "native custom map writes retain the parsed value and escape string names at every allocation failure" {
    try std.testing.checkAllAllocationFailures(a, customWrite, .{});
}
