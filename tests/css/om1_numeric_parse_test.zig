//! Q21/Q22/Q23 probes (Chrome 156, Safari 27, 2026-10-27), Values 4
//! §10.10.1 and Typed OM §5.6: reify the simplified shared parser tree.
const std = @import("std");
const css = @import("css");
const allocator = std.testing.allocator;

fn typed(a: std.mem.Allocator, text: []const u8, expected: ?[]const u8) anyerror!void {
    if (comptime !@hasDecl(css.math_values, "parseNumeric")) return std.testing.expect(false);
    const parsed = try css.math_values.parseNumeric(a, text);
    if (expected) |want| {
        const expression = parsed orelse return error.TestUnexpectedResult;
        defer expression.deinit();
        const serialized = try css.typed_om.numeric_ops.serialize(a, @intFromPtr(expression.root), css.typed_om.numeric_ops.ParsedReader{});
        defer a.free(serialized);
        try std.testing.expectEqualStrings(want, serialized);
    } else {
        defer if (parsed) |p| p.deinit();
        try std.testing.expect(parsed == null);
    }
}

fn control(text: []const u8, expected: []const u8) !void {
    const parsed = (try css.math_values.parse(allocator, text, .{ .kind = .length_percentage })) orelse return error.TestUnexpectedResult;
    defer parsed.expression.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try parsed.expression.serialize(&out, allocator);
    try std.testing.expectEqualStrings(expected, out.items);
}

test "existing CSS calculation parsing remains byte-identical" {
    try control("calc(1px + 1in)", "calc(97px)");
    try control("calc(9em - 8px + 1vh)", "calc(9em - 8px + 1vh)");
    try control("min(1px, 2px)", "calc(1px)");
    try control("max(1px, 2px)", "calc(2px)");
    try control("clamp(1px, 9px, 3px)", "calc(3px)");
}

fn parseCases(a: std.mem.Allocator) anyerror!void {
    const cases = .{
        .{ "calc(10px)", "10px" },                                     .{ "calc(1px + 1in)", "97px" },
        .{ "calc(9em - 8px + 1vh)", "calc(9em + -8px + 1vh)" },        .{ "calc(calc(1px + 2em) + 3px)", "calc(4px + 2em)" },
        .{ "min(1px, 2px)", "1px" },                                   .{ "calc(2 * min(10px, 20%))", "calc(min(10px, 20%) * 2)" },
        .{ "calc(1px - min(2px, 1em))", "calc(1px - min(2px, 1em))" }, .{ "calc(sin(90deg))", "1" },
        .{ "calc(1px * 1px)", "calc(1px * 1px)" },                     .{ "calc(1px / 1s)", "calc(1px / 1s)" },
        .{ "min(10%, 20%)", "min(10%, 20%)" },                         .{ "calc(min(10%, 20%) + 1px)", "calc(min(10%, 20%) + 1px)" },
        .{ "clamp(none, 2px, 3px)", "2px" },                           .{ "1in", "1in" },
        .{ "2KHZ", "2khz" },                                           .{ "25%", "25%" },
    };
    inline for (cases) |case| try typed(a, case[0], case[1]);
    for ([_][]const u8{ "sin(90deg)", "round(1.2, 1)", "abs(-2px)", "", "auto", "1px 2px", "calc(1px + 2s)", "1unknown", "(1px)", "calc(1px+ 2px)" }) |text| try typed(a, text, null);
}

test "context-free numeric parsing covers the full probe and allocation failure paths" {
    try std.testing.checkAllAllocationFailures(allocator, parseCases, .{});
}

test "property and numeric entry points share the same simplified probe trees" {
    if (comptime !@hasDecl(css.typed_om, "numeric_ops")) return std.testing.expect(false);
    const cases = .{
        .{ "calc(10px)", "10px" },                                     .{ "calc(1px + 1in)", "97px" },
        .{ "calc(9em - 8px + 1vh)", "calc(9em + -8px + 1vh)" },        .{ "calc(calc(1px + 2em) + 3px)", "calc(4px + 2em)" },
        .{ "min(1px, 2px)", "1px" },                                   .{ "calc(2 * min(10px, 20%))", "calc(min(10px, 20%) * 2)" },
        .{ "calc(1px - min(2px, 1em))", "calc(1px - min(2px, 1em))" },
    };
    inline for (cases) |case| {
        const parsed = (try css.math_values.parse(allocator, case[0], .{ .kind = .length_percentage })) orelse return error.TestUnexpectedResult;
        defer parsed.expression.unref();
        const text = try css.typed_om.numeric_ops.serialize(allocator, @intFromPtr(parsed.expression.root), css.typed_om.numeric_ops.ParsedReader{});
        defer allocator.free(text);
        try std.testing.expectEqualStrings(case[1], text);
    }
}
