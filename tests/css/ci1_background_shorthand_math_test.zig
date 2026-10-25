//! Q214 proposed controls: Backgrounds3 §§2.6, 2.6.1, 2.10;
//! Values4 §§6.1.1, 8.3, 10.11, 10.13 and Appendix C; Values5 §4.2.
//! Whole-background positions have typed, owned axes. Size math and opaque
//! image-leaf policy remain covered by their existing independent tests.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Value = css.style_values.Value;
const Longhand = css.properties.Longhand;

const Case = struct {
    input: []const u8,
    specified: []const u8,
    axes: [2][]const u8,
    edges: [2]?[]const u8 = .{ null, null },
    y_math: bool = true,
};
const exact = Case{
    .input = "url(a.png) calc(10% + 1px) 0",
    .specified = "url(\"a.png\") calc(10% + 1px) 0px",
    .axes = .{ "calc(10% + 1px)", "0px" },
    .y_math = false,
};
const relative = Case{
    .input = "url(a.png) calc(2em + 3px) calc(10% + 1em)",
    .specified = "url(\"a.png\") calc(2em + 3px) calc(10% + 1em)",
    .axes = .{ "calc(2em + 3px)", "calc(10% + 1em)" },
};
const complement = Case{
    .input = "url(a.png) right calc(10% + 1em) bottom calc(20% + 5px)",
    .specified = "url(\"a.png\") right calc(10% + 1em) bottom calc(20% + 5px)",
    .axes = .{ "right calc(10% + 1em)", "bottom calc(20% + 5px)" },
    .edges = .{ "right", "bottom" },
};
const axes = [_]Longhand{ .background_position_x, .background_position_y };

fn releaseAssignments(allocator: Allocator, assignments: *std.ArrayList(css.properties.Assignment)) void {
    for (assignments.items) |assignment| assignment.value.release();
    assignments.deinit(allocator);
}

fn expectSpecifiedAxis(allocator: Allocator, value: Value, index: usize, case: Case) !void {
    try testing.expect(value == .image_axis);
    try testing.expect(value.image_axis.data == .specified);
    const anchor = value.image_axis.data.specified;
    if (case.edges[index]) |expected| {
        try testing.expect(anchor.edge != null);
        try testing.expectEqualStrings(expected, anchor.edge.?.name());
    } else try testing.expect(anchor.edge == null);
    const offset = anchor.offset orelse return error.ExpectedOwnedPositionOffset;
    if (index == 0 or case.y_math) {
        try testing.expect(offset == .calculation);
    } else {
        try testing.expect(offset == .length);
        try testing.expectEqual(css.style_values.LengthUnit.px, offset.length.unit);
        try testing.expectEqual(@as(f64, 0), offset.length.value);
    }
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(axes[index], value, &out, allocator);
    try testing.expectEqualStrings(case.axes[index], out.items);
}

// Observe parseDeclaration's boolean and all nine expanded assignments, not
// merely CSSOM's forgiving drop result. Each position offset must be typed.
fn parser(allocator: Allocator, quirks: bool, case: Case) !void {
    const property = css.properties.lookup("background") orelse return error.BackgroundMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator, .quirks = quirks }, property, case.input, &assignments));
    const longhands = property.shorthand.longhands();
    try testing.expectEqual(@as(usize, 9), assignments.items.len);
    for (assignments.items, longhands) |assignment, longhand| try testing.expectEqual(longhand, assignment.longhand);
    for (axes, 0..) |axis, index| {
        var found = false;
        for (assignments.items) |assignment| {
            if (assignment.longhand != axis) continue;
            try testing.expect(assignment.value == .value);
            try expectSpecifiedAxis(allocator, assignment.value.value, index, case);
            found = true;
        }
        try testing.expect(found);
    }
}

fn expectBlock(allocator: Allocator, block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expect(out.items.len != 0);
    try testing.expectEqualStrings(expected, out.items);
}

// Exercise declaration-list parsing and CSSOM assignment independently. No
// serialization is reparsed to manufacture an expected or computed result.
fn specified(allocator: Allocator, quirks: bool, case: Case) !void {
    const source = try std.fmt.allocPrint(allocator, "background:{s}", .{case.input});
    defer allocator.free(source);
    var parsed = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, source);
    defer parsed.deinit();
    var assigned = css.declarations.DeclarationBlock.init(allocator);
    defer assigned.deinit();
    try testing.expect(try assigned.setProperty(.{ .allocator = allocator, .quirks = quirks }, "background", case.input, ""));
    for ([_]*const css.declarations.DeclarationBlock{ &parsed, &assigned }) |block| {
        for (axes, 0..) |axis, index| {
            const entry = block.get(axis) orelse return error.ExpectedStoredPositionAxis;
            try testing.expect(entry.value == .value);
            try expectSpecifiedAxis(allocator, entry.value.value, index, case);
        }
        try expectBlock(allocator, block, "background", case.specified);
        try expectBlock(allocator, block, "background-position-x", case.axes[0]);
        try expectBlock(allocator, block, "background-position-y", case.axes[1]);
    }
}

fn styleFromBackground(allocator: Allocator, quirks: bool, case: Case, font_px: u32) !*css.computed_style.ComputedStyle {
    const source = try std.fmt.allocPrint(allocator, "font-size:{d}px;background:{s}", .{ font_px, case.input });
    defer allocator.free(source);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, source);
    defer block.deinit();
    // A dropped declaration must fail here before an initial computed axis
    // could accidentally satisfy a downstream serialization comparison.
    for (axes, 0..) |axis, index| {
        const entry = block.get(axis) orelse return error.ExpectedStoredPositionAxis;
        try testing.expect(entry.value == .value);
        try expectSpecifiedAxis(allocator, entry.value.value, index, case);
    }
    return try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
}

fn expectComputed(allocator: Allocator, style: *const css.computed_style.ComputedStyle, expected: [2][]const u8, math_axes: [2]bool) !void {
    for (axes, 0..) |axis, index| {
        const value = style.get(axis);
        try testing.expect(value == .image_axis);
        try testing.expect(value.image_axis.data == .computed);
        const offset = value.image_axis.data.computed;
        try testing.expect(!offset.complement);
        try testing.expectEqual(math_axes[index], offset.value == .calculation);
        if (!math_axes[index]) try testing.expect(offset.value == .length);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try style.serializeResolved(axis, &out, allocator);
        try testing.expect(out.items.len != 0);
        try testing.expectEqualStrings(expected[index], out.items);
    }
}

fn computed(allocator: Allocator, quirks: bool, case: Case, font_px: u32, expected: [2][]const u8, math_axes: [2]bool) !void {
    const style = try styleFromBackground(allocator, quirks, case, font_px);
    defer style.destroy();
    // Both the source allocation and declaration block have been destroyed.
    // Drive another successful declaration/storage path before reading back.
    var churn = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, "background:url(b.png) calc(20% + 2px) 3px");
    defer churn.deinit();
    try expectBlock(allocator, &churn, "background", "url(\"b.png\") calc(20% + 2px) 3px");
    try expectComputed(allocator, style, expected, math_axes);
    const x = style.get(.background_position_x).image_axis.data.computed.value;
    if (!math_axes[0]) {
        try testing.expectEqual(css.style_values.LengthUnit.px, x.length.unit);
        try testing.expectEqual(@as(f64, @floatFromInt(font_px * 2 + 3)), x.length.value);
    }
}

// Backgrounds3 §2.10: background:inherit expands to every longhand. The
// inherited position is the parent's computed value, not a new em evaluation
// in the child's 10px font. Percentages remain unresolved (Values4 §10.11).
fn inherited(allocator: Allocator, quirks: bool) !void {
    const child = blk: {
        const parent = try styleFromBackground(allocator, quirks, relative, 40);
        defer parent.destroy();
        try expectComputed(allocator, parent, .{ "83px", "calc(10% + 40px)" }, .{ false, true });
        const source = try allocator.dupe(u8, "font-size:10px;background:inherit");
        defer allocator.free(source);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .quirks = quirks }, source);
        defer block.deinit();
        const result = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        errdefer result.destroy();
        for (axes) |axis| try testing.expect(result.get(axis).eql(parent.get(axis)));
        break :blk result;
    };
    defer child.destroy();
    // Parent, both blocks and both source allocations have now ended.
    const font = child.get(.font_size);
    try testing.expect(font == .length);
    try testing.expectEqual(css.style_values.LengthUnit.px, font.length.unit);
    try testing.expectEqual(@as(f64, 10), font.length.value);
    try expectComputed(allocator, child, .{ "83px", "calc(10% + 40px)" }, .{ false, true });
    const x = child.get(.background_position_x).image_axis.data.computed.value;
    try testing.expectEqual(css.style_values.LengthUnit.px, x.length.unit);
    try testing.expectEqual(@as(f64, 83), x.length.value);
}

// Values4 Appendix C explicitly excludes background, even in quirks mode.
// Pin both the parser's rejection and the setter preserving its prior value.
fn strictUnitless(allocator: Allocator, quirks: bool) !void {
    const property = css.properties.lookup("background") orelse return error.BackgroundMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .quirks = quirks }, "background", "url(a.png) 1px 2px", ""));
    for ([_][]const u8{ "url(a.png) 1 2", "url(a.png) calc(10% + 1px) 2" }) |bad| {
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator, .quirks = quirks }, property, bad, &assignments));
        try testing.expectEqual(@as(usize, 0), assignments.items.len);
        try testing.expect(!try block.setProperty(.{ .allocator = allocator, .quirks = quirks }, "background", bad, ""));
        try expectBlock(allocator, &block, "background", "url(\"a.png\") 1px 2px");
    }
}

test "Q214 whole background exact calc position accepts genuine stored typed axes" {
    for ([_]bool{ false, true }) |quirks| try parser(testing.allocator, quirks, exact);
}

test "Q214 whole background math specified declaration and setter serialization exists" {
    for ([_]bool{ false, true }) |quirks| {
        for ([_]Case{ exact, relative, complement }) |case| try specified(testing.allocator, quirks, case);
    }
}

test "Q214 whole background exact calc axes outlive declaration and source" {
    for ([_]bool{ false, true }) |quirks| try computed(testing.allocator, quirks, exact, 20, .{ "calc(10% + 1px)", "0px" }, .{ true, false });
}

test "Q214 whole background math computes with distinct fonts and unresolved percentages" {
    for ([_]bool{ false, true }) |quirks| {
        try computed(testing.allocator, quirks, relative, 20, .{ "43px", "calc(10% + 20px)" }, .{ false, true });
        try computed(testing.allocator, quirks, relative, 40, .{ "83px", "calc(10% + 40px)" }, .{ false, true });
    }
}

test "Q214 whole background right bottom math computes typed complements after source release" {
    for ([_]bool{ false, true }) |quirks| {
        try computed(testing.allocator, quirks, complement, 20, .{ "calc(90% - 20px)", "calc(80% - 5px)" }, .{ true, true });
        try computed(testing.allocator, quirks, complement, 40, .{ "calc(90% - 40px)", "calc(80% - 5px)" }, .{ true, true });
    }
}

test "Q214 whole background inherit preserves parent numeric axes after parent destruction" {
    for ([_]bool{ false, true }) |quirks| try inherited(testing.allocator, quirks);
}

test "Q214 whole background typed math paths release all owners at every allocation" {
    for ([_]bool{ false, true }) |quirks| {
        for ([_]Case{ exact, relative, complement }) |case| {
            try testing.checkAllAllocationFailures(testing.allocator, parser, .{ quirks, case });
            try testing.checkAllAllocationFailures(testing.allocator, specified, .{ quirks, case });
        }
        try testing.checkAllAllocationFailures(testing.allocator, computed, .{ quirks, exact, 20, [2][]const u8{ "calc(10% + 1px)", "0px" }, [2]bool{ true, false } });
        try testing.checkAllAllocationFailures(testing.allocator, computed, .{ quirks, relative, 20, [2][]const u8{ "43px", "calc(10% + 20px)" }, [2]bool{ false, true } });
        try testing.checkAllAllocationFailures(testing.allocator, computed, .{ quirks, relative, 40, [2][]const u8{ "83px", "calc(10% + 40px)" }, [2]bool{ false, true } });
        try testing.checkAllAllocationFailures(testing.allocator, computed, .{ quirks, complement, 20, [2][]const u8{ "calc(90% - 20px)", "calc(80% - 5px)" }, [2]bool{ true, true } });
        try testing.checkAllAllocationFailures(testing.allocator, computed, .{ quirks, complement, 40, [2][]const u8{ "calc(90% - 40px)", "calc(80% - 5px)" }, [2]bool{ true, true } });
        try testing.checkAllAllocationFailures(testing.allocator, inherited, .{quirks});
    }
}

test "Q214 whole background unitless positions stay strict in standards and quirks" {
    for ([_]bool{ false, true }) |quirks| try strictUnitless(testing.allocator, quirks);
}

test "Q214 whole background strict unitless rejection cleans up at every allocation" {
    for ([_]bool{ false, true }) |quirks| try testing.checkAllAllocationFailures(testing.allocator, strictUnitless, .{quirks});
}
