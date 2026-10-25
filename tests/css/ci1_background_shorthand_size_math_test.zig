//! CSS Backgrounds3 §§2.6, 2.9, 2.9.1 and 2.10: typed size math in background.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Value = css.style_values.Value;

const input = "url(a.png) 0 / calc(10px + 2px) auto";
const specified_value = "url(\"a.png\") 0px center / calc(12px) auto";

fn releaseAssignments(allocator: Allocator, assignments: *std.ArrayList(css.properties.Assignment)) void {
    for (assignments.items) |assignment| assignment.value.release();
    assignments.deinit(allocator);
}

fn expectBlockValue(allocator: Allocator, block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expect(out.items.len != 0);
    try testing.expectEqualStrings(expected, out.items);
}

fn expectTypedStoredSize(value: Value, math: bool) !void {
    try testing.expect(value == .image_size);
    const size = value.image_size;
    try testing.expectEqual(math, size.axes[0] == .calculation);
    try testing.expect(size.axes[1].isKeyword(.auto));
}

// Parse the shorthand directly and observe all nine expanded assignments.
// Checking the stored size prevents initial-value defaults from masking a drop.
fn parser(allocator: Allocator, quirks: bool) !void {
    const property = css.properties.lookup("background") orelse return error.BackgroundMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator, .quirks = quirks }, property, input, &assignments));
    try testing.expectEqual(@as(usize, 9), assignments.items.len);
    const longhands = property.shorthand.longhands();
    try testing.expectEqual(assignments.items.len, longhands.len);
    for (assignments.items, longhands) |assignment, longhand| try testing.expectEqual(longhand, assignment.longhand);
    var found_size = false;
    for (assignments.items) |assignment| {
        if (assignment.longhand != .background_size) continue;
        try testing.expect(assignment.value == .value);
        try expectTypedStoredSize(assignment.value.value, true);
        found_size = true;
    }
    try testing.expect(found_size);
}

fn specified(allocator: Allocator, quirks: bool) !void {
    const source = try std.fmt.allocPrint(allocator, "background:{s}", .{input});
    defer allocator.free(source);
    var parsed = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, source);
    defer parsed.deinit();
    var assigned = css.declarations.DeclarationBlock.init(allocator);
    defer assigned.deinit();
    try testing.expect(try assigned.setProperty(.{ .allocator = allocator, .quirks = quirks }, "background", input, ""));
    for ([_]*const css.declarations.DeclarationBlock{ &parsed, &assigned }) |block| {
        const size = block.get(.background_size) orelse return error.ExpectedStoredBackgroundSize;
        try testing.expect(size.value == .value);
        try expectTypedStoredSize(size.value.value, true);
        try expectBlockValue(allocator, block, "background", specified_value);
        try expectBlockValue(allocator, block, "background-size", "calc(12px) auto");
        try expectBlockValue(allocator, block, "background-position-y", "center");
    }
}

fn computed(allocator: Allocator, quirks: bool) !void {
    const style = blk: {
        const source = try allocator.dupe(u8, "background: url(a.png) 0 / calc(10px + 2px) auto");
        defer allocator.free(source);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, source);
        defer block.deinit();
        const stored = block.get(.background_size) orelse return error.ExpectedStoredBackgroundSize;
        try testing.expect(stored.value == .value);
        try expectTypedStoredSize(stored.value.value, true);
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    // The inner scope has ended: source and declaration storage are destroyed.
    var churn = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, "background: url(b.png) 2px / 3px auto");
    defer churn.deinit();
    try expectBlockValue(allocator, &churn, "background-size", "3px auto");
    const value = style.get(.background_size);
    try testing.expect(value == .image_size);
    try testing.expect(value.image_size.axes[0] == .length);
    try testing.expectEqual(css.style_values.LengthUnit.px, value.image_size.axes[0].length.unit);
    try testing.expectEqual(@as(f64, 12), value.image_size.axes[0].length.value);
    try testing.expect(value.image_size.axes[1].isKeyword(.auto));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.background_size, &out, allocator);
    try testing.expectEqualStrings("12px auto", out.items);
    out.clearRetainingCapacity();
    try style.serializeResolved(.background_position_y, &out, allocator);
    try testing.expectEqualStrings("50%", out.items);
}

fn relativeParent(allocator: Allocator, quirks: bool) !*css.computed_style.ComputedStyle {
    const source = try allocator.dupe(u8, "font-size:20px;background:url(a.png) 0 / calc(2em + 2px) auto");
    defer allocator.free(source);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, source);
    defer block.deinit();
    const stored = block.get(.background_size) orelse return error.ExpectedStoredBackgroundSize;
    try testing.expect(stored.value == .value);
    try expectTypedStoredSize(stored.value.value, true);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    errdefer style.destroy();
    return style;
}

fn inherited(allocator: Allocator, quirks: bool) !void {
    const child = blk: {
        const parent = try relativeParent(allocator, quirks);
        defer parent.destroy();
        const source = try allocator.dupe(u8, "font-size:10px;background:inherit");
        defer allocator.free(source);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, source);
        defer block.deinit();
        const result = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        errdefer result.destroy();
        try testing.expect(result.get(.background_size).eql(parent.get(.background_size)));
        break :blk result;
    };
    defer child.destroy();
    // Parent, source strings and both declaration blocks are gone. The parent's 20px font
    // resolved 2em before inheritance; the child's 10px font must not recalculate it.
    const size = child.get(.background_size);
    const font = child.get(.font_size);
    try testing.expect(font == .length);
    try testing.expectEqual(css.style_values.LengthUnit.px, font.length.unit);
    try testing.expectEqual(@as(f64, 10), font.length.value);
    try testing.expect(size == .image_size);
    try testing.expect(size.image_size.axes[0] == .length);
    try testing.expectEqual(css.style_values.LengthUnit.px, size.image_size.axes[0].length.unit);
    try testing.expectEqual(@as(f64, 42), size.image_size.axes[0].length.value);
    try testing.expect(size.image_size.axes[1].isKeyword(.auto));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(.background_size, &out, allocator);
    try testing.expectEqualStrings("42px auto", out.items);
}

fn invalid(allocator: Allocator, quirks: bool) !void {
    const property = css.properties.lookup("background") orelse return error.BackgroundMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .quirks = quirks }, "background", "url(a.png) 0 / 5px auto", ""));
    for ([_][]const u8{
        "url(a.png) 0 / -1px auto",
        "url(a.png) 0 / 1 auto",
        "url(a.png) 0 / calc(1px + 1s) auto",
        "url(a.png) 0 / calc(1px +) auto",
    }) |bad| {
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator, .quirks = quirks }, property, bad, &assignments));
        try testing.expectEqual(@as(usize, 0), assignments.items.len);
        try testing.expect(!try block.setProperty(.{ .allocator = allocator, .quirks = quirks }, "background", bad, ""));
        try expectBlockValue(allocator, &block, "background", "url(\"a.png\") 0px center / 5px auto");
    }
}

fn negativeMathClamp(allocator: Allocator, quirks: bool) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    // Negative math remains valid syntax; the nonnegative range clamps at compute time.
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .quirks = quirks }, "background", "url(a.png) 0 / calc(10px - 20px) auto", ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const size = style.get(.background_size);
    try testing.expect(size == .image_size);
    try testing.expect(size.image_size.axes[0] == .length);
    try testing.expectEqual(@as(f64, 0), size.image_size.axes[0].length.value);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.background_size, &out, allocator);
    try testing.expectEqualStrings("0px auto", out.items);
}

test "Q219 full background shorthand parses typed size math in standards and quirks" {
    for ([_]bool{ false, true }) |quirks| try parser(testing.allocator, quirks);
}

test "Q219 full background shorthand stores and serializes the specified typed size" {
    for ([_]bool{ false, true }) |quirks| try specified(testing.allocator, quirks);
}

test "Q219 computed size and single-position default survive source destruction" {
    for ([_]bool{ false, true }) |quirks| try computed(testing.allocator, quirks);
}

test "Q219 inherited computed size survives parent and source with child font change" {
    for ([_]bool{ false, true }) |quirks| try inherited(testing.allocator, quirks);
}

test "Q219 invalid size literals and dimensions preserve prior shorthand value" {
    for ([_]bool{ false, true }) |quirks| try invalid(testing.allocator, quirks);
}

test "Q219 valid negative size math clamps only after shorthand computation" {
    for ([_]bool{ false, true }) |quirks| try negativeMathClamp(testing.allocator, quirks);
}

test "Q219 typed background size paths clean up at every allocation failure" {
    for ([_]bool{ false, true }) |quirks| {
        try testing.checkAllAllocationFailures(testing.allocator, parser, .{quirks});
        try testing.checkAllAllocationFailures(testing.allocator, specified, .{quirks});
        try testing.checkAllAllocationFailures(testing.allocator, computed, .{quirks});
        try testing.checkAllAllocationFailures(testing.allocator, inherited, .{quirks});
        try testing.checkAllAllocationFailures(testing.allocator, invalid, .{quirks});
        try testing.checkAllAllocationFailures(testing.allocator, negativeMathClamp, .{quirks});
    }
}
