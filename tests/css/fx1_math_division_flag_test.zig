//! Q41's optional division diagnostic must not change default CSS math.
const std = @import("std");
const math = @import("css").math_values;
const testing = std.testing;

fn compareDiagnostics(allocator: std.mem.Allocator, text: []const u8, context: math.Context, expected_at_parse: bool, expected_after_compute: bool) anyerror!void {
    if (comptime @hasDecl(math, "parseWithDivisionCheck") and @hasDecl(math.Expression, "computeWithDivisionCheck")) {
        var divided_by_zero = false;
        const checked = (try math.parseWithDivisionCheck(allocator, text, .{ .kind = .length }, &divided_by_zero)) orelse return error.InvalidCheckedMath;
        defer checked.expression.unref();
        try testing.expectEqual(text.len, checked.consumed);
        try testing.expectEqual(expected_at_parse, divided_by_zero);
        const computed = try checked.expression.computeWithDivisionCheck(allocator, context, &divided_by_zero);
        defer computed.unref();
        try testing.expectEqual(expected_after_compute, divided_by_zero);

        // Existing entrypoints keep their results bit-for-bit and their
        // serialization byte-for-byte, including raw nonfinite values.
        const normal = (try math.parse(allocator, text, .{ .kind = .length })) orelse return error.InvalidDefaultMath;
        defer normal.expression.unref();
        const normal_computed = try normal.expression.compute(allocator, context);
        defer normal_computed.unref();
        const raw = computed.knownNumber() orelse return error.UnresolvedCheckedMath;
        const normal_raw = normal_computed.knownNumber() orelse return error.UnresolvedDefaultMath;
        try testing.expectEqual(normal_raw.unit, raw.unit);
        try testing.expectEqual(@as(u64, @bitCast(normal_raw.value)), @as(u64, @bitCast(raw.value)));
        var actual: std.ArrayList(u8) = .empty;
        defer actual.deinit(allocator);
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(allocator);
        try computed.serialize(&actual, allocator);
        try normal_computed.serialize(&expected, allocator);
        try testing.expectEqualStrings(expected.items, actual.items);
    } else {
        // A meaningful missing-contract RED before the additive API exists;
        // the independent default-behavior pin below still runs on BASE.
        return error.MissingDivisionDiagnostic;
    }
}

test "default CSS division and overflow keep IEEE results before outer clamping" {
    const Case = struct { text: []const u8, kind: enum { positive_infinity, nan, finite }, finite: f64 = 0 };
    const cases = [_]Case{
        .{ .text = "calc(1px / 0)", .kind = .positive_infinity },
        .{ .text = "calc(0px / 0)", .kind = .nan },
        .{ .text = "calc(1e308px * 1e308)", .kind = .positive_infinity },
        .{ .text = "calc(1e308in - 1e308in)", .kind = .nan },
        .{ .text = "min(30px, 1px / 0)", .kind = .finite, .finite = 30 },
        .{ .text = "calc(20px / 2)", .kind = .finite, .finite = 10 },
    };
    for (cases) |case| {
        const parsed = (try math.parse(testing.allocator, case.text, .{ .kind = .length })) orelse return error.InvalidDefaultMath;
        defer parsed.expression.unref();
        const computed = try parsed.expression.compute(testing.allocator, .{});
        defer computed.unref();
        const raw = computed.knownNumber() orelse return error.UnresolvedDefaultMath;
        const clamped = computed.computedNumber() orelse return error.UnresolvedDefaultMath;
        try testing.expectEqual(math.Unit.px, raw.unit);
        switch (case.kind) {
            .positive_infinity => {
                try testing.expect(std.math.isPositiveInf(raw.value));
                try testing.expectEqual(std.math.floatMax(f64), clamped.value);
            },
            .nan => {
                try testing.expect(std.math.isNan(raw.value));
                try testing.expectEqual(@as(f64, 0), clamped.value);
            },
            .finite => {
                try testing.expectEqual(case.finite, raw.value);
                try testing.expectEqual(case.finite, clamped.value);
            },
        }
    }
}

test "division diagnostic defaults to false for ordinary nonzero division" {
    try compareDiagnostics(testing.allocator, "calc(20px / 2)", .{}, false, false);
}

test "division diagnostic sees positive and negative zero" {
    try compareDiagnostics(testing.allocator, "calc(1px / 0)", .{}, true, true);
    try compareDiagnostics(testing.allocator, "calc(1px / -0)", .{}, true, true);
}

test "division diagnostic sees zero over zero before NaN folding" {
    try compareDiagnostics(testing.allocator, "calc(0px / 0)", .{}, true, true);
}

test "division diagnostic sees a denominator expression simplifying to zero" {
    try compareDiagnostics(testing.allocator, "calc(1px / (2 - 2))", .{}, true, true);
}

test "division diagnostic survives a finite min branch" {
    try compareDiagnostics(testing.allocator, "min(30px, 1px / 0)", .{}, true, true);
}

test "division diagnostic sees dimensional zero before unit cancellation" {
    try compareDiagnostics(testing.allocator, "calc(1px * (1px / 0px))", .{}, true, true);
}

test "division diagnostic sees a zero resolved only with computed font inputs" {
    try compareDiagnostics(testing.allocator, "calc(1px / ((1em - 16px) / 1px))", .{ .font_size = 16 }, false, true);
}

test "division diagnostic does not mistake arithmetic overflow for zero division" {
    try compareDiagnostics(testing.allocator, "calc(1e308px * 1e308)", .{}, false, false);
}

test "division diagnostic does not mistake overflow cancellation for zero division" {
    try compareDiagnostics(testing.allocator, "calc(1e308in - 1e308in)", .{}, false, false);
}

test "division diagnostic does not mistake an infinity keyword for zero division" {
    try compareDiagnostics(testing.allocator, "calc(infinity * 1px)", .{}, false, false);
}

test "division diagnostic does not round a small nonzero divisor to zero" {
    try compareDiagnostics(testing.allocator, "calc(1px / 1e-308)", .{}, false, false);
}

test "division diagnostic unwinds every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, compareDiagnostics, .{
        "calc(1px / ((1em - 16px) / 1px))", math.Context{ .font_size = 16 }, false, true,
    });
}
