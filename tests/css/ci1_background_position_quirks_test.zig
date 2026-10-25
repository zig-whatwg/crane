//! Regression coverage for background-position unitless lengths and typed math.
//! CSS Values4 Appendix C; Backgrounds3 §2.6; Values4 §§8.3, 10.13.
//! Native ParseOptions exposes quirks as a bool: limited/no-quirks both map
//! to false. The three WPT documents must independently verify document mode.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Mode = enum {
    quirks,
    limited_quirks,
    no_quirks,

    fn options(self: Mode, allocator: Allocator) css.properties.ParseOptions {
        return .{ .allocator = allocator, .quirks = self == .quirks };
    }
};
const Case = struct { input: []const u8, specified: []const u8, computed: []const u8 };
const unitless = [_]Case{
    .{ .input = "1", .specified = "1px center", .computed = "1px 50%" },
    .{ .input = "+1", .specified = "1px center", .computed = "1px 50%" },
    .{ .input = "-1", .specified = "-1px center", .computed = "-1px 50%" },
    .{ .input = "1.5", .specified = "1.5px center", .computed = "1.5px 50%" },
    .{ .input = "+1.5", .specified = "1.5px center", .computed = "1.5px 50%" },
    .{ .input = "-1.5", .specified = "-1.5px center", .computed = "-1.5px 50%" },
    .{ .input = "1 +2", .specified = "1px 2px", .computed = "1px 2px" },
    .{ .input = "1 -2", .specified = "1px -2px", .computed = "1px -2px" },
    .{ .input = "1 2px", .specified = "1px 2px", .computed = "1px 2px" },
    .{ .input = "1px 2", .specified = "1px 2px", .computed = "1px 2px" },
};
const calc_case = Case{ .input = "calc(2 * 2px)", .specified = "calc(4px) center", .computed = "4px 50%" };

fn releaseAssignments(allocator: Allocator, assignments: *std.ArrayList(css.properties.Assignment)) void {
    for (assignments.items) |assignment| assignment.value.release();
    assignments.deinit(allocator);
}

// Direct grammar result and full declaration consumption are observed here;
// CSSOM's forgiving drop policy must not hide parseDeclaration(false).
fn parserCase(allocator: Allocator, mode: Mode, case: Case) !void {
    const property = css.properties.lookup("background-position") orelse return error.BackgroundPositionMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(mode.options(allocator), property, case.input, &assignments));
    try testing.expectEqual(@as(usize, 2), assignments.items.len);
    try testing.expectEqual(css.properties.Longhand.background_position_x, assignments.items[0].longhand);
    try testing.expectEqual(css.properties.Longhand.background_position_y, assignments.items[1].longhand);
    const assigned = [_]css.properties.Assigned{ assignments.items[0].value, assignments.items[1].value };
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try testing.expect(try css.properties.serializeShorthand(.background_position, &assigned, .specified, &text, allocator));
    try testing.expectEqualStrings(case.specified, text.items);
}

// Exercise the declaration-list token serialization used by style rules.
fn declarationCase(allocator: Allocator, mode: Mode, case: Case) !void {
    const text = try std.fmt.allocPrint(allocator, "background-position:{s}", .{case.input});
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(mode.options(allocator), text);
    defer block.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    try block.getPropertyValue("background-position", &actual);
    try testing.expectEqualStrings(case.specified, actual.items);
}

// Independent of declarationCase: an earlier parser assertion cannot prevent
// the computed API from running. The noninitial expected value catches a drop.
fn computedCase(allocator: Allocator, mode: Mode, case: Case) !void {
    const text = try std.fmt.allocPrint(allocator, "background-position:{s}", .{case.input});
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(mode.options(allocator), text);
    var owns_block = true;
    defer if (owns_block) block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.deinit();
    owns_block = false;
    const assigned = [_]css.properties.Assigned{
        .{ .value = style.get(.background_position_x) },
        .{ .value = style.get(.background_position_y) },
    };
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    try testing.expect(try css.properties.serializeShorthand(.background_position, &assigned, .computed, &actual, allocator));
    try testing.expectEqualStrings(case.computed, actual.items);
}

// Existing values make ignoring an unsupported new value observable.
fn setterCase(allocator: Allocator, mode: Mode, case: Case) !void {
    var block = try css.declarations.DeclarationBlock.parse(mode.options(allocator), "background-position:7px 9px");
    defer block.deinit();
    try testing.expect(try block.setProperty(mode.options(allocator), "background-position", case.input, ""));
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    try block.getPropertyValue("background-position", &actual);
    try testing.expectEqualStrings(case.specified, actual.items);
}

fn allBoundaries(allocator: Allocator, mode: Mode, case: Case) !void {
    try parserCase(allocator, mode, case);
    try declarationCase(allocator, mode, case);
    try setterCase(allocator, mode, case);
    try computedCase(allocator, mode, case);
}

fn rejects(allocator: Allocator, mode: Mode, name: []const u8, input: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.PropertyMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(!try css.properties.parseDeclaration(mode.options(allocator), property, input, &assignments));
    try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

fn accepts(allocator: Allocator, name: []const u8, input: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.PropertyMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(Mode.quirks.options(allocator), property, input, &assignments));
    try testing.expect(assignments.items.len > 0);
}

fn otherPositionCallers(allocator: Allocator) !void {
    const controls = [_]struct { name: []const u8, good: []const u8, bad: []const u8 }{
        .{ .name = "object-position", .good = "1px 2px", .bad = "1 2" },
        .{ .name = "mask-position", .good = "1px 2px", .bad = "1 2" },
        .{ .name = "clip-path", .good = "circle(at 1px 2px)", .bad = "circle(at 1 2)" },
        .{ .name = "clip-path", .good = "ellipse(at 1px 2px)", .bad = "ellipse(at 1 2)" },
        .{ .name = "clip-path", .good = "shape(from 1px 2px, line to 3px 4px)", .bad = "shape(from 1 2, line to 3px 4px)" },
        .{ .name = "clip-path", .good = "shape(from 1px 2px, line to 3px 4px)", .bad = "shape(from 1px 2px, line to 3 4)" },
        .{ .name = "clip-path", .good = "shape(from 1px 2px, curve to 3px 4px with 5px 6px)", .bad = "shape(from 1px 2px, curve to 3px 4px with 5 6)" },
    };
    for (controls) |control| {
        try accepts(allocator, control.name, control.good);
        try rejects(allocator, .quirks, control.name, control.bad);
    }
}

test "r0 every existing position caller keeps strict unitless components" {
    try otherPositionCallers(testing.allocator);
}

test "r0 every existing position caller keeps strict components at all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, otherPositionCallers, .{});
}

fn negativeControls(allocator: Allocator) !void {
    try accepts(allocator, "background", "1px 2px");
    try accepts(allocator, "background-position-x", "1px");
    try accepts(allocator, "background-position-y", "2px");
    for ([_]Mode{ .limited_quirks, .no_quirks }) |mode| {
        for (unitless) |case| try rejects(allocator, mode, "background-position", case.input);
    }
    // Appendix C: shorthand/component reuse never inherits this exception.
    for (unitless) |case| {
        try rejects(allocator, .quirks, "background", case.input);
        try rejects(allocator, .quirks, "object-position", case.input);
        try rejects(allocator, .quirks, "mask-position", case.input);
    }
    for ([_][]const u8{ "background-position-x", "background-position-y" }) |name| {
        try rejects(allocator, .quirks, name, "1");
    }
    try rejects(allocator, .quirks, "clip-path", "circle(at 1 2)");
    try rejects(allocator, .quirks, "clip-path", "shape(from 1 2, line to 3px 4px)");
    try rejects(allocator, .quirks, "mask", "url(a) 1 2");
    // A number-valued calc is not a length; the quirk is not applied inside it.
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| {
        for ([_][]const u8{ "calc(1)", "calc(1) 2px", "1px calc(2)", "calc(1 + 2px)", "calc(1s)", "calc(1deg)", "auto", "1px 2px 3px", "left right", "1px,", "1px,,2px", "1px garbage", "calc(2 * 2px) garbage" }) |bad| {
            try rejects(allocator, mode, "background-position", bad);
        }
    }
    // CSSOM invalid input must preserve an existing recognized declaration.
    var block = try css.declarations.DeclarationBlock.parse(Mode.no_quirks.options(allocator), "background-position:7px 9px");
    defer block.deinit();
    try testing.expect(!try block.setProperty(Mode.no_quirks.options(allocator), "background-position", "1", ""));
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    try block.getPropertyValue("background-position", &actual);
    try testing.expectEqualStrings("7px 9px", actual.items);
}

test "r0 background-position quirk remains property and mode specific" {
    try negativeControls(testing.allocator);
}

test "r0 negative controls clean up at every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, negativeControls, .{});
}

test "r0 quirks background-position 1 parser" {
    try parserCase(testing.allocator, .quirks, unitless[0]);
}

test "r0 quirks background-position 1 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[0]);
}

test "r0 quirks background-position 1 setter" {
    try setterCase(testing.allocator, .quirks, unitless[0]);
}

test "r0 quirks background-position 1 computed" {
    try computedCase(testing.allocator, .quirks, unitless[0]);
}

test "r0 quirks background-position 1 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[0] });
}

test "r0 quirks background-position +1 parser" {
    try parserCase(testing.allocator, .quirks, unitless[1]);
}

test "r0 quirks background-position +1 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[1]);
}

test "r0 quirks background-position +1 setter" {
    try setterCase(testing.allocator, .quirks, unitless[1]);
}

test "r0 quirks background-position +1 computed" {
    try computedCase(testing.allocator, .quirks, unitless[1]);
}

test "r0 quirks background-position +1 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[1] });
}

test "r0 quirks background-position -1 parser" {
    try parserCase(testing.allocator, .quirks, unitless[2]);
}

test "r0 quirks background-position -1 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[2]);
}

test "r0 quirks background-position -1 setter" {
    try setterCase(testing.allocator, .quirks, unitless[2]);
}

test "r0 quirks background-position -1 computed" {
    try computedCase(testing.allocator, .quirks, unitless[2]);
}

test "r0 quirks background-position -1 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[2] });
}

test "r0 quirks background-position 1.5 parser" {
    try parserCase(testing.allocator, .quirks, unitless[3]);
}

test "r0 quirks background-position 1.5 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[3]);
}

test "r0 quirks background-position 1.5 setter" {
    try setterCase(testing.allocator, .quirks, unitless[3]);
}

test "r0 quirks background-position 1.5 computed" {
    try computedCase(testing.allocator, .quirks, unitless[3]);
}

test "r0 quirks background-position 1.5 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[3] });
}

test "r0 quirks background-position +1.5 parser" {
    try parserCase(testing.allocator, .quirks, unitless[4]);
}

test "r0 quirks background-position +1.5 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[4]);
}

test "r0 quirks background-position +1.5 setter" {
    try setterCase(testing.allocator, .quirks, unitless[4]);
}

test "r0 quirks background-position +1.5 computed" {
    try computedCase(testing.allocator, .quirks, unitless[4]);
}

test "r0 quirks background-position +1.5 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[4] });
}

test "r0 quirks background-position -1.5 parser" {
    try parserCase(testing.allocator, .quirks, unitless[5]);
}

test "r0 quirks background-position -1.5 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[5]);
}

test "r0 quirks background-position -1.5 setter" {
    try setterCase(testing.allocator, .quirks, unitless[5]);
}

test "r0 quirks background-position -1.5 computed" {
    try computedCase(testing.allocator, .quirks, unitless[5]);
}

test "r0 quirks background-position -1.5 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[5] });
}

test "r0 quirks background-position 1 +2 parser" {
    try parserCase(testing.allocator, .quirks, unitless[6]);
}

test "r0 quirks background-position 1 +2 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[6]);
}

test "r0 quirks background-position 1 +2 setter" {
    try setterCase(testing.allocator, .quirks, unitless[6]);
}

test "r0 quirks background-position 1 +2 computed" {
    try computedCase(testing.allocator, .quirks, unitless[6]);
}

test "r0 quirks background-position 1 +2 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[6] });
}

test "r0 quirks background-position 1 -2 parser" {
    try parserCase(testing.allocator, .quirks, unitless[7]);
}

test "r0 quirks background-position 1 -2 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[7]);
}

test "r0 quirks background-position 1 -2 setter" {
    try setterCase(testing.allocator, .quirks, unitless[7]);
}

test "r0 quirks background-position 1 -2 computed" {
    try computedCase(testing.allocator, .quirks, unitless[7]);
}

test "r0 quirks background-position 1 -2 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[7] });
}

test "r0 quirks background-position 1 2px parser" {
    try parserCase(testing.allocator, .quirks, unitless[8]);
}

test "r0 quirks background-position 1 2px declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[8]);
}

test "r0 quirks background-position 1 2px setter" {
    try setterCase(testing.allocator, .quirks, unitless[8]);
}

test "r0 quirks background-position 1 2px computed" {
    try computedCase(testing.allocator, .quirks, unitless[8]);
}

test "r0 quirks background-position 1 2px all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[8] });
}

test "r0 quirks background-position 1px 2 parser" {
    try parserCase(testing.allocator, .quirks, unitless[9]);
}

test "r0 quirks background-position 1px 2 declaration" {
    try declarationCase(testing.allocator, .quirks, unitless[9]);
}

test "r0 quirks background-position 1px 2 setter" {
    try setterCase(testing.allocator, .quirks, unitless[9]);
}

test "r0 quirks background-position 1px 2 computed" {
    try computedCase(testing.allocator, .quirks, unitless[9]);
}

test "r0 quirks background-position 1px 2 all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, unitless[9] });
}

test "r0 quirks background-position calc(2 * 2px) parser" {
    try parserCase(testing.allocator, .quirks, calc_case);
}

test "r0 quirks background-position calc(2 * 2px) declaration" {
    try declarationCase(testing.allocator, .quirks, calc_case);
}

test "r0 quirks background-position calc(2 * 2px) setter" {
    try setterCase(testing.allocator, .quirks, calc_case);
}

test "r0 quirks background-position calc(2 * 2px) computed" {
    try computedCase(testing.allocator, .quirks, calc_case);
}

test "r0 quirks background-position calc(2 * 2px) all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, calc_case });
}

test "r0 limited_quirks background-position calc(2 * 2px) parser" {
    try parserCase(testing.allocator, .limited_quirks, calc_case);
}

test "r0 limited_quirks background-position calc(2 * 2px) declaration" {
    try declarationCase(testing.allocator, .limited_quirks, calc_case);
}

test "r0 limited_quirks background-position calc(2 * 2px) setter" {
    try setterCase(testing.allocator, .limited_quirks, calc_case);
}

test "r0 limited_quirks background-position calc(2 * 2px) computed" {
    try computedCase(testing.allocator, .limited_quirks, calc_case);
}

test "r0 limited_quirks background-position calc(2 * 2px) all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.limited_quirks, calc_case });
}

test "r0 no_quirks background-position calc(2 * 2px) parser" {
    try parserCase(testing.allocator, .no_quirks, calc_case);
}

test "r0 no_quirks background-position calc(2 * 2px) declaration" {
    try declarationCase(testing.allocator, .no_quirks, calc_case);
}

test "r0 no_quirks background-position calc(2 * 2px) setter" {
    try setterCase(testing.allocator, .no_quirks, calc_case);
}

test "r0 no_quirks background-position calc(2 * 2px) computed" {
    try computedCase(testing.allocator, .no_quirks, calc_case);
}

test "r0 no_quirks background-position calc(2 * 2px) all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.no_quirks, calc_case });
}
// Exercise both independent columns, the Layers owner, and invalid suffix
// rollback rather than only the singleton fast path used by the WPT cases.
const layered_case = Case{
    .input = "1, calc(2 * 2px), 1px 2",
    .specified = "1px center, calc(4px) center, 1px 2px",
    .computed = "1px 50%, 4px 50%, 1px 2px",
};

fn invalidSuffix(allocator: Allocator) !void {
    const options = Mode.quirks.options(allocator);
    const property = css.properties.lookup("background-position") orelse return error.BackgroundPositionMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(options, property, "7px 9px", &assignments));
    for ([_][]const u8{ "1,", "1, calc(2 * 2px) garbage", "calc(2 * 2px), 1px 2px 3px" }) |bad| {
        try testing.expect(!try css.properties.parseDeclaration(options, property, bad, &assignments));
        try testing.expectEqual(@as(usize, 2), assignments.items.len);
        const assigned = [_]css.properties.Assigned{ assignments.items[0].value, assignments.items[1].value };
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try testing.expect(try css.properties.serializeShorthand(.background_position, &assigned, .specified, &text, allocator));
        try testing.expectEqualStrings("7px 9px", text.items);
    }
}

test "r0 quirks layered background-position parser" {
    try parserCase(testing.allocator, .quirks, layered_case);
}

test "r0 quirks layered background-position declaration" {
    try declarationCase(testing.allocator, .quirks, layered_case);
}

test "r0 quirks layered background-position setter" {
    try setterCase(testing.allocator, .quirks, layered_case);
}

test "r0 quirks layered background-position computed" {
    try computedCase(testing.allocator, .quirks, layered_case);
}

test "r0 quirks layered background-position all allocations" {
    try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ Mode.quirks, layered_case });
}

test "r0 invalid later background-position layer preserves caller output at every allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSuffix, .{});
}

// Broad typed-math controls prevent fixing only expressions reducible to px
// while parsing. All are background-position, independent of earlier f's
// object/mask/shape/individual-axis math admission.
const typed_math = [_]Case{
    .{ .input = "calc(2em + 3px)", .specified = "calc(2em + 3px) center", .computed = "35px 50%" },
    .{ .input = "calc(20px + 100% - 100%)", .specified = "calc(0% + 20px) center", .computed = "calc(0% + 20px) 50%" },
    .{ .input = "min(10px, 3em, 20px)", .specified = "min(10px, 3em) center", .computed = "10px 50%" },
    .{ .input = "clamp(none, 1em, 10px)", .specified = "min(1em, 10px) center", .computed = "10px 50%" },
    .{ .input = "right calc(10% + 1em) bottom calc(20% + 5px)", .specified = "right calc(10% + 1em) bottom calc(20% + 5px)", .computed = "calc(90% - 16px) calc(80% - 5px)" },
    .{ .input = "calc(10px * 10px / 2px)", .specified = "calc(50px) center", .computed = "50px 50%" },
    .{ .input = "1rex", .specified = "1rex center", .computed = "8px 50%" },
};

test "r0 typed background-position relative length parser in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try parserCase(testing.allocator, mode, typed_math[0]);
}

test "r0 typed background-position relative length computed in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try computedCase(testing.allocator, mode, typed_math[0]);
}

test "r0 typed background-position relative length all boundaries at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ mode, typed_math[0] });
}

test "r0 typed background-position unresolved percentage parser in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try parserCase(testing.allocator, mode, typed_math[1]);
}

test "r0 typed background-position unresolved percentage computed in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try computedCase(testing.allocator, mode, typed_math[1]);
}

test "r0 typed background-position unresolved percentage all boundaries at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ mode, typed_math[1] });
}

test "r0 typed background-position comparison parser in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try parserCase(testing.allocator, mode, typed_math[2]);
}

test "r0 typed background-position comparison computed in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try computedCase(testing.allocator, mode, typed_math[2]);
}

test "r0 typed background-position comparison all boundaries at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ mode, typed_math[2] });
}

test "r0 typed background-position clamp parser in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try parserCase(testing.allocator, mode, typed_math[3]);
}

test "r0 typed background-position clamp computed in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try computedCase(testing.allocator, mode, typed_math[3]);
}

test "r0 typed background-position clamp all boundaries at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ mode, typed_math[3] });
}

test "r0 typed background-position right bottom complement parser in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try parserCase(testing.allocator, mode, typed_math[4]);
}

test "r0 typed background-position right bottom complement computed in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try computedCase(testing.allocator, mode, typed_math[4]);
}

test "r0 typed background-position right bottom complement all boundaries at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ mode, typed_math[4] });
}

test "r0 typed background-position typed dimensional algebra parser in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try parserCase(testing.allocator, mode, typed_math[5]);
}

test "r0 typed background-position typed dimensional algebra computed in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try computedCase(testing.allocator, mode, typed_math[5]);
}

test "r0 typed background-position typed dimensional algebra all boundaries at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ mode, typed_math[5] });
}

const DependencyCase = struct {
    input: []const u8,
    longhand: css.properties.Longhand,
    tree: bool = false,
    random: bool = false,
    metric: bool = false,
};
const dependencies = [_]DependencyCase{
    .{ .input = "calc(sibling-index() * 1px) 2px", .longhand = .background_position_x, .tree = true },
    .{ .input = "right calc(sibling-count() * 1px) bottom 2px", .longhand = .background_position_x, .tree = true },
    .{ .input = "1px random(2px, 4px)", .longhand = .background_position_y, .random = true },
    .{ .input = "1px random(fixed .5, 2px, 4px)", .longhand = .background_position_y },
    .{ .input = "calc(1cap) 2px", .longhand = .background_position_x, .metric = true },
    .{ .input = "1px calc(1rcap)", .longhand = .background_position_y, .metric = true },
    .{ .input = "0px 0px, random(2px, 4px) 1px", .longhand = .background_position_x, .random = true },
};

fn dependencyCase(allocator: Allocator, case: DependencyCase) !void {
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(Mode.no_quirks.options(allocator), "background-position", case.input, ""));
        const value = (block.get(case.longhand) orelse return error.ExpectedPositionAxis).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    // The declaration and source random scope have died. The axis/list owns
    // its expression, whose dependencies must remain observable afterwards.
    try testing.expectEqual(case.tree, value.needsTreeCounts());
    try testing.expectEqual(case.random, value.needsRandomBase());
    try testing.expectEqual(case.metric, value.needsUnavailableMetrics(false));
    try testing.expect(!value.needsUnavailableMetrics(true));
}

test "r0 actual background-position declarations retain math dependencies after source release" {
    for (dependencies) |case| try dependencyCase(testing.allocator, case);
}

test "r0 actual background-position dependencies clean up at every allocation" {
    for (dependencies) |case| try testing.checkAllAllocationFailures(testing.allocator, dependencyCase, .{case});
}

test "r0 typed background-position extended literal parser in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try parserCase(testing.allocator, mode, typed_math[6]);
}

test "r0 typed background-position extended literal computed in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try computedCase(testing.allocator, mode, typed_math[6]);
}

test "r0 typed background-position extended literal all boundaries at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| try testing.checkAllAllocationFailures(testing.allocator, allBoundaries, .{ mode, typed_math[6] });
}

// Constructor-level guard for the second compute consumer. This deliberately
// does not expand generic .position parser admission before f. The typed
// representation already permits owned scalar expressions in either anchor.
fn positionComplementConsumer(allocator: Allocator) !void {
    const style = blk: {
        const x = (try css.math_values.parse(allocator, "calc(10% + 1em)", .{ .kind = .length_percentage })) orelse return error.ExpectedTypedMath;
        defer x.expression.unref();
        const y = (try css.math_values.parse(allocator, "calc(20% + 5px)", .{ .kind = .length_percentage })) orelse return error.ExpectedTypedMath;
        defer y.expression.unref();
        const Position = std.meta.Child(@FieldType(css.style_values.Value, "image_position"));
        const value: css.style_values.Value = .{ .image_position = try Position.create(allocator, .{
            .{ .edge = .right, .offset = .{ .calculation = x.expression } },
            .{ .edge = .bottom, .offset = .{ .calculation = y.expression } },
        }, false) };
        defer value.release();
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try block.entries.ensureUnusedCapacity(allocator, 1);
        value.retain();
        block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = .object_position, .value = .{ .value = value }, .important = false } });
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    const result = style.get(.object_position);
    try testing.expect(result == .image_position);
    try testing.expect(result.image_position.data == .computed);
    // Fail an assertion before invoking the old serializer's .length-only
    // complement assumption, so this RED guard does not mask other cases.
    try testing.expect(!result.image_position.data.computed[0].complement);
    try testing.expect(!result.image_position.data.computed[1].complement);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try style.serializeResolved(.object_position, &text, allocator);
    try testing.expectEqualStrings("calc(90% - 16px) calc(80% - 5px)", text.items);
}

test "r0 typed complement also normalizes the Position compute consumer" {
    try positionComplementConsumer(testing.allocator);
}

test "r0 Position compute typed complement cleans up at every allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, positionComplementConsumer, .{});
}

// Backgrounds3 section 2.10 / Values4 section 6.1.1 (Q188): valid root-font
// <length> literals are accepted by
// the whole `background` shorthand. Keep these tests separate from the
// background-position-only quirk/math checks above.
const WholeBackgroundCase = struct {
    input: []const u8,
    specified: []const u8,
    x_computed: []const u8,
    y_computed: []const u8,
};

const q188_whole_background_cases = [_]WholeBackgroundCase{
    .{ .input = "1rex", .specified = "1rex center", .x_computed = "8px", .y_computed = "50%" },
    .{ .input = "1rch 2rex", .specified = "1rch 2rex", .x_computed = "8px", .y_computed = "16px" },
};

fn q188WholeBackgroundAccepted(allocator: Allocator, mode: Mode, case: WholeBackgroundCase) !void {
    const property = css.properties.lookup("background") orelse return error.BackgroundMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(mode.options(allocator), property, case.input, &assignments));
    try testing.expect(assignments.items.len > 0);
    var has_x = false;
    var has_y = false;
    for (assignments.items) |assignment| {
        has_x = has_x or assignment.longhand == .background_position_x;
        has_y = has_y or assignment.longhand == .background_position_y;
    }
    try testing.expect(has_x);
    try testing.expect(has_y);
}

fn q188WholeBackgroundSpecified(allocator: Allocator, mode: Mode, case: WholeBackgroundCase) !void {
    try q188WholeBackgroundAccepted(allocator, mode, case);
    const declaration = try std.fmt.allocPrint(allocator, "background:{s}", .{case.input});
    defer allocator.free(declaration);
    var block = try css.declarations.DeclarationBlock.parse(mode.options(allocator), declaration);
    defer block.deinit();
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(allocator);
    try block.getPropertyValue("background", &serialized);
    try testing.expectEqualStrings(case.specified, serialized.items);
}

fn q188WholeBackgroundComputed(allocator: Allocator, mode: Mode, case: WholeBackgroundCase) !void {
    // This assertion is essential: otherwise CSS initial-position fallback
    // could make an ignored shorthand look like a successful computed test.
    try q188WholeBackgroundAccepted(allocator, mode, case);
    const declaration = try std.fmt.allocPrint(allocator, "background:{s}", .{case.input});
    defer allocator.free(declaration);
    var block = try css.declarations.DeclarationBlock.parse(mode.options(allocator), declaration);
    var owns_block = true;
    defer if (owns_block) block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{
        .block = &block,
        .source = .{ .origin = .author },
    }});
    defer style.destroy();

    // Computed longhands must remain readable once their declaration source
    // has been destroyed; these values came from the whole shorthand above.
    block.deinit();
    owns_block = false;
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(allocator);
    try style.serializeResolved(.background_position_x, &serialized, allocator);
    try testing.expectEqualStrings(case.x_computed, serialized.items);
    serialized.clearRetainingCapacity();
    try style.serializeResolved(.background_position_y, &serialized, allocator);
    try testing.expectEqualStrings(case.y_computed, serialized.items);
}

fn q188WholeBackgroundAllBoundaries(allocator: Allocator, mode: Mode, case: WholeBackgroundCase) !void {
    try q188WholeBackgroundSpecified(allocator, mode, case);
    try q188WholeBackgroundComputed(allocator, mode, case);
}

fn q188WholeBackgroundStrictUnitless(allocator: Allocator, mode: Mode) !void {
    const property = css.properties.lookup("background") orelse return error.BackgroundMissing;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer releaseAssignments(allocator, &assignments);
    try testing.expect(!try css.properties.parseDeclaration(mode.options(allocator), property, "1 2", &assignments));
    try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "r0 Q188 whole background 1rex specified serialization in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| {
        try q188WholeBackgroundSpecified(testing.allocator, mode, q188_whole_background_cases[0]);
    }
}

test "r0 Q188 whole background 1rex computed axes after source release in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| {
        try q188WholeBackgroundComputed(testing.allocator, mode, q188_whole_background_cases[0]);
    }
}

test "r0 Q188 whole background 1rch 2rex specified serialization in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| {
        try q188WholeBackgroundSpecified(testing.allocator, mode, q188_whole_background_cases[1]);
    }
}

test "r0 Q188 whole background 1rch 2rex computed axes after source release in every mode" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| {
        try q188WholeBackgroundComputed(testing.allocator, mode, q188_whole_background_cases[1]);
    }
}

test "r0 Q188 whole background positive paths clean up at every allocation" {
    for ([_]Mode{ .quirks, .limited_quirks, .no_quirks }) |mode| {
        for (q188_whole_background_cases) |case| {
            try testing.checkAllAllocationFailures(testing.allocator, q188WholeBackgroundAllBoundaries, .{ mode, case });
        }
    }
}

test "r0 Q188 whole background unitless pair stays strict in quirks and no-quirks" {
    try q188WholeBackgroundStrictUnitless(testing.allocator, .quirks);
    try q188WholeBackgroundStrictUnitless(testing.allocator, .no_quirks);
}

test "r0 Q188 whole background unitless pair rejection cleans up at every allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, q188WholeBackgroundStrictUnitless, .{.quirks});
    try testing.checkAllAllocationFailures(testing.allocator, q188WholeBackgroundStrictUnitless, .{.no_quirks});
}
