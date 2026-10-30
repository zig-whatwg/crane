//! Typed OM §§2.1, 5.2 and 6: opaque values retain their native owner.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn checkOpaque(allocator: std.mem.Allocator, name: []const u8, input: []const u8, index: ?usize, expected: []const u8) !void {
    if (comptime !@hasDecl(css.typed_om, "native_values")) return std.testing.expect(false);
    const property = (css.properties.lookup(name) orelse return error.MissingProperty);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, input, &assignments));
    var retained = try css.typed_om.native_values.Opaque.init(allocator, property, assignments.items, false, index);
    defer retained.deinit();
    // Discard the source parse completely before reading the new owner.
    for (assignments.items) |assignment| assignment.value.release();
    assignments.clearRetainingCapacity();
    const text = try retained.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn opaqueOwnership(allocator: std.mem.Allocator) anyerror!void {
    try checkOpaque(allocator, "font-family", "\"A B\", serif", null, "A B, serif");
    try checkOpaque(allocator, "background", "blue", null, "blue");
    try checkOpaque(allocator, "transition-timing-function", "ease, cubic-bezier(0.1, 0.2, 0.3, 0.4)", 1, "cubic-bezier(0.1, 0.2, 0.3, 0.4)");
    try checkOpaque(allocator, "animation-range-start", "normal, entry 20%", 1, "entry 20%");
    try checkOpaque(allocator, "animation-timeline", "auto, scroll(root block)", 1, "scroll(root)");
}

test "opaque reified values and animation list items outlive the source parse at every allocation failure" {
    try std.testing.checkAllAllocationFailures(a, opaqueOwnership, .{});
}

fn computedOwnership(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_values")) return std.testing.expect(false);
    const assignments = [_]css.properties.Assignment{.{ .longhand = .color, .value = .{ .value = .{ .color = .{ .rgba = .{ .r = 255, .g = 0, .b = 0, .a = 1 } } } } }};
    var retained = try css.typed_om.native_values.Opaque.init(allocator, .{ .longhand = .color }, &assignments, true, null);
    defer retained.deinit();
    const text = try retained.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings("rgb(255, 0, 0)", text);
    try std.testing.expect(css.typed_om.native_values.sameProperty(retained.property, .{ .longhand = .color }));
    try std.testing.expect(!css.typed_om.native_values.sameProperty(retained.property, .{ .longhand = .background_color }));
    try std.testing.expect(!css.typed_om.native_values.sameProperty(retained.property, .{ .shorthand = .background }));
}

test "opaque computed serialization and associated property use the retained representation" {
    try std.testing.checkAllAllocationFailures(a, computedOwnership, .{});
}

test "numeric reification preserves unit sentinels without reparsing serialization" {
    if (comptime !@hasDecl(css.typed_om, "native_values")) return std.testing.expect(false);
    const native = css.typed_om.native_values;
    const width = native.numericLeaf(.width, .{ .length = .{ .value = 2, .unit = .cm } }).?;
    try std.testing.expectEqual(css.math_values.Unit.cm, width.unit);
    try std.testing.expectEqual(@as(f64, 2), width.value);
    const duration = native.numericLeaf(.transition_duration, .{ .number = 0 }).?;
    try std.testing.expectEqual(css.math_values.Unit.s, duration.unit);
    try std.testing.expectEqual(@as(f64, 0), duration.value);
    try std.testing.expect(native.numericLeaf(.width, .{ .keyword = .auto }) == null);
}
