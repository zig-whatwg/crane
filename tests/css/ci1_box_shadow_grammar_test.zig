//! Q172 PART2: Backgrounds3 longhand only; Borders4 materials quarantined.
//! Browser evidence: main/tmp/analysis/integrator-probes-1024c/ (q172 C/F/S).
//! Q170 preparation only. UNRUN; install only on the actual accepted parent.
//! Backgrounds3 §6.1; Values4 §§2.2–2.3, 6, 9.1, 10.12; CSSOM §6.7.2.
//! Uses existing public paths; missing recognition fails at runtime before
//! unknown-property declaration storage can produce a misleading success.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = struct { input: []const u8, expected: ?[]const u8 };

fn property() !css.properties.Property {
    return css.properties.lookup("box-shadow") orelse error.BoxShadowNotImplemented;
}

fn parseCase(allocator: Allocator, case: Case, quirks: bool) !void {
    const p = try property();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(allocator);
    }
    const valid = try css.properties.parseDeclaration(.{ .allocator = allocator, .quirks = quirks }, p, case.input, &assignments);
    try testing.expectEqual(case.expected != null, valid);
    if (case.expected) |expected| {
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        const value = assignments.items[0].value.value;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try css.properties.serializeValue(p.longhand, value, &out, allocator);
        try testing.expectEqualStrings(expected, out.items);
        // Serialization is a valid input and preserves the value's meaning.
        var again: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (again.items) |a| a.value.release();
            again.deinit(allocator);
        }
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator, .quirks = quirks }, p, out.items, &again));
        try testing.expect(value.eql(again.items[0].value.value));
    } else try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "ci1 box shadow unordered color inset and adjacent lengths serialize completely" {
    for ([_]Case{
        .{ .input = "none", .expected = "none" },
        .{ .input = "1px 2px", .expected = "1px 2px" },
        .{ .input = "0 -0", .expected = "0px 0px" },
        .{ .input = "red inset 1px -2px 0 -4px", .expected = "red 1px -2px 0px -4px inset" },
        .{ .input = "red 1px -2px inset", .expected = "red 1px -2px inset" },
        .{ .input = "inset red 1px -2px", .expected = "red 1px -2px inset" },
        .{ .input = "inset 1px -2px red", .expected = "red 1px -2px inset" },
        .{ .input = "1px -2px inset red", .expected = "red 1px -2px inset" },
        .{ .input = "1px -2px red inset", .expected = "red 1px -2px inset" },
        .{ .input = "inset 1em 2rem 3px -4px, blue -5px 6px", .expected = "1em 2rem 3px -4px inset, blue -5px 6px" },
        .{ .input = "1px 1px calc(-1px)", .expected = "1px 1px calc(-1px)" },
        .{ .input = "1px 1px calc(1em - 2px)", .expected = "1px 1px calc(1em - 2px)" },
        .{ .input = "1px 2px rgb(255, 0, 0", .expected = "rgb(255, 0, 0) 1px 2px" },
        .{ .input = "1px 2px calc(3px", .expected = "1px 2px calc(3px)" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, parseCase, .{ case, false });
}

test "ci1 box shadow invalid suffixes reject the whole list and clean every owned prefix" {
    for ([_][]const u8{
        "",                                        "red",                 "inset",               "1px",                   "1 2",                   "1% 2%",                             "1px calc(2px + 2%)",
        "1px 2px -1px",                            "1px 2px 3px 4px 5px", "red 1px 2px blue",    "1px red 2px",           "1px inset 2px",         "1px 2px red 3px",                   "1px 2px 3px inset 4px",
        "inset 1px 2px inset",                     "none, 1px 2px",       "1px 2px, none",       "1px 2px,",              ",1px 2px",              "red calc(1em + 2px) 2px, blue 3px", "red 1px 2px, blue 3px 4px -5px",
        "red 1px 2px, rgb(1, 2, 3) 3px 4px extra", "1px 2px rgb(",        "1px 2px calc(",       "1px 2px rgb(1, 2, 3))", "1px 2px url(bad\"url)", "1px 2px 'bad\nstring'",             "1px 2px inherit",
        "initial, 1px 2px",                        "red none",            "none 3px -4px inset", "1px 2px outset",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, parseCase, .{ Case{ .input = input, .expected = null }, false });
}

test "ci1 box shadow borrows strict scalar grammars without color or length quirks" {
    for ([_][]const u8{ "1 2", "123 1px 2px", "abc 1px 2px", "1px 2px 3", "1px 2px 0 4" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, parseCase, .{ Case{ .input = input, .expected = null }, true });
    try testing.checkAllAllocationFailures(testing.allocator, parseCase, .{ Case{ .input = "0 0 0 -0", .expected = "0px 0px 0px 0px" }, true });
}

fn setterLifecycle(allocator: Allocator) !void {
    const p = try property();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:red;box-shadow:inset red 1px 2px 3px -4px");
    defer block.deinit();
    try testing.expect(block.get(p.longhand) != null);
    try testing.expectEqualStrings("box-shadow", block.item(1).?);
    try testing.expectEqual(@as(usize, 2), block.length());
    try testing.expect(!(try block.setProperty(.{ .allocator = allocator }, "box-shadow", "blue 5px 6px, red 1px", "")));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("box-shadow", &out);
    try testing.expectEqualStrings("red 1px 2px 3px -4px inset", out.items);
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "box-shadow", "blue 5px 6px, red 7px 8px", "important"));
    try testing.expect(block.getPropertyPriority("box-shadow"));
    try testing.expectEqual(@as(usize, 2), block.length());
    out.clearRetainingCapacity();
    try testing.expect(try block.removeProperty("box-shadow", &out));
    try testing.expectEqualStrings("blue 5px 6px, red 7px 8px", out.items);
    try testing.expect(block.get(p.longhand) == null);
    try testing.expectEqual(@as(usize, 1), block.length());
}

test "ci1 box shadow CSSOM replacement rejection enumeration and removal own their values" {
    try testing.checkAllAllocationFailures(testing.allocator, setterLifecycle, .{});
}
