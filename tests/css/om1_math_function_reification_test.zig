//! Typed OM §5.2 and Q95,2026-10-27. Existing math, retained ownership,
//! and native classification; no serializer output is parsed here.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn verify(allocator: std.mem.Allocator, source: []const u8, unsupported: bool) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_reification")) return std.testing.expect(false);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try std.testing.expect(try block.setProperty(.{ .allocator = allocator }, "width", source, ""));
    const declaration = block.get(.width) orelse return error.TestExpectedValue;
    const shape = css.typed_om.native_reification.shape(.width, declaration.value.value);
    try std.testing.expectEqual(unsupported, shape == .unsupported);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try block.getPropertyValue("width", &expected);
    const assignments = [_]css.properties.Assignment{.{ .longhand = .width, .value = declaration.value }};
    var retained = try css.typed_om.native_values.Opaque.init(allocator, .{ .longhand = .width }, &assignments, false, null);
    defer retained.deinit();
    block.clear();
    const text = try retained.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings(expected.items, text);
    try std.testing.expect(css.typed_om.native_values.sameProperty(retained.property, .{ .longhand = .width }));
    try std.testing.expect(!css.typed_om.native_values.sameProperty(retained.property, .{ .longhand = .height }));
}

test "Q95 native round(1em, 1px) is unsupported but retained" {
    try std.testing.checkAllAllocationFailures(a, verify, .{ "round(1em, 1px)", true });
}

test "Q95 native calc(round(1em, 1px) + 2px) is unsupported but retained" {
    try std.testing.checkAllAllocationFailures(a, verify, .{ "calc(round(1em, 1px) + 2px)", true });
}

test "Q95 native mod(1em, 1px) is unsupported but retained" {
    try std.testing.checkAllAllocationFailures(a, verify, .{ "mod(1em, 1px)", true });
}

test "Q95 native hypot(1em, 1px) is unsupported but retained" {
    try std.testing.checkAllAllocationFailures(a, verify, .{ "hypot(1em, 1px)", true });
}

test "Q95 native round(2px, 1px) is representable after simplification" {
    try std.testing.checkAllAllocationFailures(a, verify, .{ "round(2px, 1px)", false });
}

test "Q95 native calc(sin(90deg) * 1px) is representable after simplification" {
    try std.testing.checkAllAllocationFailures(a, verify, .{ "calc(sin(90deg) * 1px)", false });
}
