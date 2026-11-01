//! CSS Values 4 Appendix C and Tables 3 §3.5.2.1.
//! Native ParseOptions has one quirks bit: standards and limited-quirks both
//! use false. The three upstream WPT documents check that mode boundary.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = struct { input: []const u8, specified: []const u8, computed: []const u8 };
const cases = [_]Case{
    .{ .input = "+1", .specified = "1px", .computed = "1px" },
    .{ .input = "+1.5", .specified = "1.5px", .computed = "1.5px" },
    .{ .input = "1", .specified = "1px", .computed = "1px" },
    .{ .input = "1 +2", .specified = "1px 2px", .computed = "1px 2px" },
    .{ .input = "1 2px", .specified = "1px 2px", .computed = "1px 2px" },
    .{ .input = "1.5", .specified = "1.5px", .computed = "1.5px" },
    .{ .input = "1px 2", .specified = "1px 2px", .computed = "1px 2px" },
};

fn releaseAssignments(allocator: Allocator, list: *std.ArrayList(css.properties.Assignment)) void {
    for (list.items) |assignment| assignment.value.release();
    list.deinit(allocator);
}

fn accepted(allocator: Allocator, quirks: bool, case: Case) !void {
    const options: css.properties.ParseOptions = .{ .allocator = allocator, .quirks = quirks };
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(options, css.properties.lookup("border-spacing").?, case.input, &assignments));
    try testing.expectEqual(@as(usize, 1), assignments.items.len);
    try testing.expectEqual(css.properties.Longhand.border_spacing, assignments.items[0].longhand);

    const declaration = try std.fmt.allocPrint(allocator, "border-spacing:{s}", .{case.input});
    defer allocator.free(declaration);
    var block = try h.Block.parse(options, declaration);
    var owns_block = true;
    defer if (owns_block) block.deinit();
    try h.specified(&block, "border-spacing", case.specified, allocator);
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    block.deinit();
    owns_block = false;
    try h.expect(style, "border-spacing", case.computed, allocator);

    var setter = try h.Block.parse(options, "border-spacing:7px 9px");
    defer setter.deinit();
    try testing.expect(try setter.setProperty(options, "border-spacing", case.input, ""));
    try h.specified(&setter, "border-spacing", case.specified, allocator);
}

fn rejected(allocator: Allocator, quirks: bool, input: []const u8) !void {
    const options: css.properties.ParseOptions = .{ .allocator = allocator, .quirks = quirks };
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(!try css.properties.parseDeclaration(options, css.properties.lookup("border-spacing").?, input, &assignments));
    try testing.expectEqual(@as(usize, 0), assignments.items.len);
    var block = try h.Block.parse(options, "border-spacing:7px 9px");
    defer block.deinit();
    try testing.expect(!try block.setProperty(options, "border-spacing", input, ""));
    try h.specified(&block, "border-spacing", "7px 9px", allocator);
}

test "quirky border-spacing accepts +1 as a pixel length" {
    try accepted(testing.allocator, true, cases[0]);
}
test "quirky border-spacing accepts +1.5 as a pixel length" {
    try accepted(testing.allocator, true, cases[1]);
}
test "quirky border-spacing accepts 1 as a pixel length" {
    try accepted(testing.allocator, true, cases[2]);
}
test "quirky border-spacing accepts 1 +2 on both axes" {
    try accepted(testing.allocator, true, cases[3]);
}
test "quirky border-spacing accepts 1 2px on the first axis" {
    try accepted(testing.allocator, true, cases[4]);
}
test "quirky border-spacing accepts 1.5 as a pixel length" {
    try accepted(testing.allocator, true, cases[5]);
}
test "quirky border-spacing accepts 1px 2 on the second axis" {
    try accepted(testing.allocator, true, cases[6]);
}
test "standard and limited-quirks parsing reject nonzero unitless border spacing" {
    for (cases) |case| try rejected(testing.allocator, false, case.input);
}
test "border spacing preserves length typing and range checks in both parser modes" {
    for ([_]bool{ false, true }) |quirks| {
        for ([_][]const u8{ "-1", "1px -2", "-1px 2px", "1%", "1px 2%", "1px 2px 3px", "+/**/1", "+ 1", "\\31", "calc(1)", "calc(0)", "1px calc(2)", "calc(1) 2px", "calc(1 + 2px)" }) |input|
            try rejected(testing.allocator, quirks, input);
        for ([_]Case{
            .{ .input = "0", .specified = "0px", .computed = "0px" },
            .{ .input = "1px 2px", .specified = "1px 2px", .computed = "1px 2px" },
            .{ .input = "calc(2 * 2px)", .specified = "calc(4px)", .computed = "4px" },
            .{ .input = "calc(1px - 2px) 3px", .specified = "calc(-1px) 3px", .computed = "0px 3px" },
        }) |case| try accepted(testing.allocator, quirks, case);
    }
}
test "quirky border spacing releases both axes and source blocks at every allocation" {
    for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, accepted, .{ true, case });
    try testing.checkAllAllocationFailures(testing.allocator, rejected, .{ true, "1 calc(2)" });
    try testing.checkAllAllocationFailures(testing.allocator, rejected, .{ false, "1px 2" });
}

// These are the exact CSS.supports() parser entry points. Both deliberately
// omit document mode; the CSS namespace forwards directly to them even when
// the calling document is in quirks mode (Values 4 Appendix C).
test "CSS supports remains strict for quirky border spacing" {
    try testing.expect(!css.supports.supportsDeclaration(testing.allocator, "border-spacing", "1"));
    try testing.expect(!css.supports.supportsCondition(testing.allocator, "(border-spacing: 1)", null, null));
    try testing.expect(css.supports.supportsDeclaration(testing.allocator, "border-spacing", "1px"));
    try testing.expect(css.supports.supportsCondition(testing.allocator, "(border-spacing: 1px)", null, null));
}
