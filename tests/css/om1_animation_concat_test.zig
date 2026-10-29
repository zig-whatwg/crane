//! Q61: native animation-list ownership for Typed OM set/append.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Case = struct { property: []const u8, left: []const u8, right: []const u8 };
const cases = [_]Case{
    .{ .property = "transition-duration", .left = "1s", .right = "calc(2s + 1s), 4s" },
    .{ .property = "transition-property", .left = "opacity", .right = "--foo, all" },
    .{ .property = "animation-name", .left = "foo", .right = "\"a b\", none" },
    .{ .property = "animation-timing-function", .left = "cubic-bezier(.1,.2,.3,.4)", .right = "steps(3, jump-end)" },
    .{ .property = "animation-range-start", .left = "entry 25%", .right = "exit calc(20% + 5px)" },
    .{ .property = "animation-timeline", .left = "scroll(root block)", .right = "view(block 10px 20%)" },
    .{ .property = "animation-direction", .left = "normal", .right = "alternate, reverse" },
};

fn concatenate(allocator: std.mem.Allocator, case: Case) anyerror!void {
    if (comptime !@hasDecl(css.animation_values.List, "concat")) return std.testing.expect(false);
    const property = (css.properties.lookup(case.property) orelse return error.MissingProperty);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, case.left, &assignments));
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, case.right, &assignments));
    const values = [_]css.style_values.Value{ assignments.items[0].value.value, assignments.items[1].value.value };
    var before: std.ArrayList(u8) = .empty;
    defer before.deinit(allocator);
    try css.properties.serializeValue(property.longhand, values[0], &before, allocator);
    try before.appendSlice(allocator, ", ");
    try css.properties.serializeValue(property.longhand, values[1], &before, allocator);
    const list = (try css.animation_values.List.concat(allocator, property.longhand, &values)) orelse return error.TestExpectedValue;
    defer list.unref();
    var after: std.ArrayList(u8) = .empty;
    defer after.deinit(allocator);
    // The source lists are unchanged and still independently own their items.
    try css.properties.serializeValue(property.longhand, values[0], &after, allocator);
    try after.appendSlice(allocator, ", ");
    try css.properties.serializeValue(property.longhand, values[1], &after, allocator);
    try std.testing.expectEqualStrings(before.items, after.items);
    for (assignments.items) |assignment| assignment.value.release();
    assignments.clearRetainingCapacity();
    after.clearRetainingCapacity();
    try list.serialize(&after, allocator);
    try std.testing.expectEqualStrings(before.items, after.items);
}

test "native animation-list concatenation owns names numbers easing ranges and timeline children" {
    for (cases) |case| try std.testing.checkAllAllocationFailures(a, concatenate, .{case});
}

fn rejectNone(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.animation_values.List, "concat")) return std.testing.expect(false);
    const values = [_]css.style_values.Value{ .{ .keyword = .none }, .{ .keyword = .all } };
    try std.testing.expect(try css.animation_values.List.concat(allocator, .transition_property, &values) == null);
    try std.testing.expect(try css.animation_values.List.concat(allocator, .transition_property, &.{}) == null);
    const initial = [_]css.style_values.Value{ .{ .number = 0 }, .{ .number = 1 } };
    const list = (try css.animation_values.List.concat(allocator, .transition_duration, &initial)).?;
    defer list.unref();
    try std.testing.expectEqual(css.math_values.Unit.s, list.items.items[0].number.literal.unit);
    try std.testing.expectEqual(css.math_values.Unit.s, list.items.items[1].number.literal.unit);
}

test "native list concatenation rejects mixed none and respects allocation-free time sentinels" {
    try std.testing.checkAllAllocationFailures(a, rejectNone, .{});
}

fn sliceOne(allocator: std.mem.Allocator, case: Case) anyerror!void {
    if (comptime !@hasDecl(css.animation_values.List, "slice")) return std.testing.expect(false);
    const property = (css.properties.lookup(case.property) orelse return error.MissingProperty);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, case.right, &assignments));
    const source = assignments.items[0].value.value.animation_list;
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try source.items.items[0].serialize(property.longhand, &expected, allocator);
    const copy = (try source.slice(allocator, 0, 1)) orelse return error.TestExpectedValue;
    defer copy.unref();
    try std.testing.expectEqual(@as(usize, 1), copy.items.items.len);
    try std.testing.expect(try source.slice(allocator, 2, 1) == null);
    try std.testing.expect(try source.slice(allocator, 0, source.items.items.len + 1) == null);
    const empty = (try source.slice(allocator, 0, 0)).?;
    empty.unref();
    // Free another copy first: that direction must leave the source intact.
    const temporary = (try source.slice(allocator, 0, 1)).?;
    temporary.unref();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try source.items.items[0].serialize(property.longhand, &text, allocator);
    try std.testing.expectEqualStrings(expected.items, text.items);
    // Release every original owner; the first slice owns all of its children.
    for (assignments.items) |assignment| assignment.value.release();
    assignments.clearRetainingCapacity();
    text.clearRetainingCapacity();
    try copy.serialize(&text, allocator);
    try std.testing.expectEqualStrings(expected.items, text.items);
}

test "native animation slices retain exactly one item independently of all original owners Q70" {
    for (cases) |case| try std.testing.checkAllAllocationFailures(a, sliceOne, .{case});
}
