//! CSS Conditional 5 §5.4 and §6.2 style-query grammar, used by if().
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const available = @hasDecl(css, "if_function") and @hasDecl(css.if_function, "parseStyleQuery");
const Checks = if (available) struct {
    const ifs = css.if_function;
    const Context = struct {
        calls: usize = 0,
        pub fn evaluate(self: *@This(), feature: ifs.StyleFeature) !ifs.Truth {
            self.calls += 1;
            return switch (feature) {
                .boolean => |name| if (std.mem.eql(u8, name, "--present")) .true else .false,
                .plain => |plain| if (std.mem.eql(u8, plain.name, "--color") and std.mem.eql(u8, plain.value, "rgb(1, 2, 3)")) .true else .false,
                .range => |range| blk: {
                    try testing.expectEqual(@as(usize, 3), range.operands.len);
                    try testing.expectEqualStrings("1px", range.operands[0]);
                    try testing.expectEqualStrings("--size", range.operands[1]);
                    try testing.expectEqualStrings("calc(10px + 2px)", range.operands[2]);
                    try testing.expectEqual(ifs.Comparison.less, range.comparisons[0]);
                    try testing.expectEqual(ifs.Comparison.less_equal, range.comparisons[1]);
                    break :blk .true;
                },
            };
        }
    };

    fn queries(allocator: std.mem.Allocator) !void {
        const Case = struct { text: []const u8, expected: ifs.Truth };
        for ([_]Case{
            .{ .text = "--present", .expected = .true },
            .{ .text = "--\\70 resent", .expected = .true },
            .{ .text = "--missing", .expected = .false },
            .{ .text = "not (--missing)", .expected = .true },
            .{ .text = "(--present) and (--color: rgb(1, 2, 3))", .expected = .true },
            .{ .text = "(--missing) or ((--present) and (--color: rgb(1, 2, 3)))", .expected = .true },
            .{ .text = "1px < --size <= calc(10px + 2px)", .expected = .true },
            .{ .text = "unknown(x)", .expected = .unknown },
            // if-cycle.html: a failed query-value substitution makes its
            // feature false; the containing not still evaluates normally.
            .{ .text = "not (--missing: var(--cyclic))", .expected = .true },
        }) |case| {
            var query = (try ifs.parseStyleQuery(allocator, case.text)) orelse return error.ExpectedStyleQuery;
            defer query.deinit();
            var context: Context = .{};
            try testing.expectEqual(case.expected, try query.evaluate(&context));
        }
    }

    fn invalid(allocator: std.mem.Allocator) !void {
        for ([_][]const u8{
            "",                         "--x !",   "--x: !important", "1px < --x > 2px",   "--x < = 1px",
            "(--x) and (--y) or (--z)", "not --x", "--x >",           "--x: url(bad url)",
        }) |input| {
            var query = try ifs.parseStyleQuery(allocator, input);
            defer if (query) |*value| value.deinit();
            try testing.expect(query == null);
        }
    }

    const LazyContext = struct {
        calls: usize = 0,
        pub fn evaluate(self: *@This(), feature: ifs.StyleFeature) error{OutOfMemory}!ifs.Truth {
            self.calls += 1;
            return switch (feature) {
                .boolean => |name| if (std.mem.eql(u8, name, "--present")) .true else .false,
                .plain => |plain| if (std.mem.eql(u8, plain.value, "var(--cyclic)")) .false else error.OutOfMemory,
                .range => error.OutOfMemory,
            };
        }
    };

    fn lazy(allocator: std.mem.Allocator) !void {
        const Case = struct { text: []const u8, expected: ifs.Truth };
        for ([_]Case{
            .{ .text = "(--present) or (--x: var(--unvisited))", .expected = .true },
            .{ .text = "(--missing) and (--x: var(--unvisited))", .expected = .false },
            .{ .text = "not (--x: var(--cyclic))", .expected = .true },
        }) |case| {
            var query = (try ifs.parseStyleQuery(allocator, case.text)).?;
            defer query.deinit();
            var context: LazyContext = .{};
            try testing.expectEqual(case.expected, try query.evaluate(&context));
            try testing.expectEqual(@as(usize, 1), context.calls);
        }
        var query = (try ifs.parseStyleQuery(allocator, "--x: oom")).?;
        defer query.deinit();
        var context: LazyContext = .{};
        try testing.expectError(error.OutOfMemory, query.evaluate(&context));
    }

    fn standardProperties(allocator: std.mem.Allocator) !void {
        // Integrator probe 1025i: known standard properties stay unknown too,
        // including under negation; the host must never receive these leaves.
        for ([_][]const u8{ "color: red", "color: blue", "not (color: red)", "not (color: blue)", "color", "not (color)" }) |input| {
            var query = (try ifs.parseStyleQuery(allocator, input)).?;
            defer query.deinit();
            var context: LazyContext = .{};
            try testing.expectEqual(ifs.Truth.unknown, try query.evaluate(&context));
            try testing.expectEqual(@as(usize, 0), context.calls);
        }
    }

    const RangeContext = struct {
        expected: []const ifs.Comparison,
        pub fn evaluate(self: *@This(), feature: ifs.StyleFeature) !ifs.Truth {
            try testing.expect(feature == .range);
            try testing.expectEqualSlices(ifs.Comparison, self.expected, feature.range.comparisons);
            try testing.expectEqual(self.expected.len + 1, feature.range.operands.len);
            return .true;
        }
    };

    fn rangeGrammar(allocator: std.mem.Allocator) !void {
        // Integrator probe 1025j: Chrome ships equality within chains and
        // comments between comparison delims; whitespace still separates them.
        const Case = struct { text: []const u8, comparisons: []const ifs.Comparison };
        for ([_]Case{
            .{ .text = "1 = 1 = 1", .comparisons = &.{ .equal, .equal } },
            .{ .text = "1 < 2 = 2", .comparisons = &.{ .less, .equal } },
            .{ .text = "1 </**/= 2", .comparisons = &.{.less_equal} },
            .{ .text = "2 >/**/= 1", .comparisons = &.{.greater_equal} },
        }) |case| {
            var query = (try ifs.parseStyleQuery(allocator, case.text)) orelse return error.ExpectedRangeQuery;
            defer query.deinit();
            var context: RangeContext = .{ .expected = case.comparisons };
            try testing.expectEqual(ifs.Truth.true, try query.evaluate(&context));
        }
    }

    fn rangeMatrix(allocator: std.mem.Allocator) !void {
        // Integrator probe 1025k records positive/negated results for every
        // pair. Some opposing directions are accepted, while = with <= is not.
        const spellings = [_][]const u8{ "=", "<", "<=", ">", ">=" };
        const operators = [_]ifs.Comparison{ .equal, .less, .less_equal, .greater, .greater_equal };
        const accepted = [_][5]bool{
            .{ true, true, false, false, false },
            .{ true, true, true, false, false },
            .{ false, true, true, true, false },
            .{ false, false, true, true, true },
            .{ false, false, false, true, true },
        };
        for (spellings, 0..) |first, i| {
            for (spellings, 0..) |second, j| {
                const input = try std.fmt.allocPrint(allocator, "1 {s} 2 {s} 3", .{ first, second });
                defer allocator.free(input);
                var query = try ifs.parseStyleQuery(allocator, input);
                defer if (query) |*value| value.deinit();
                try testing.expectEqual(accepted[i][j], query != null);
                if (query) |*value| {
                    var context: RangeContext = .{ .expected = &.{ operators[i], operators[j] } };
                    try testing.expectEqual(ifs.Truth.true, try value.evaluate(&context));
                }
            }
        }
    }

    const NestedContext = struct {
        pub fn evaluate(_: *@This(), feature: ifs.StyleFeature) !ifs.Truth {
            switch (feature) {
                .plain => |plain| try testing.expectEqualStrings("attr(data-foo type(<length>))", plain.value),
                .range => |range| try testing.expectEqualStrings("attr(data-foo type(<length>))", range.operands[0]),
                .boolean => return error.ExpectedValue,
            }
            return .true;
        }
    };

    fn nestedValueTokens(allocator: std.mem.Allocator) !void {
        // if-conditionals.html queries typed attr() in style features. The
        // <length> delims belong to the nested type() block, not this range.
        for ([_][]const u8{
            "--x: attr(data-foo type(<length>))",
            "attr(data-foo type(<length>)) < 10px",
        }) |input| {
            var query = (try ifs.parseStyleQuery(allocator, input)) orelse return error.ExpectedNestedValue;
            defer query.deinit();
            var context: NestedContext = .{};
            try testing.expectEqual(ifs.Truth.true, try query.evaluate(&context));
        }
    }
} else struct {};

const RangeChecks = if (available and @hasDecl(css.if_function, "compareRange")) struct {
    const ifs = css.if_function;
    const Dimension = enum { number, percentage, length, angle, time, frequency, resolution };
    const Numeric = struct { value: f64, dimension: Dimension };

    fn ranges() !void {
        for (std.enums.values(Dimension)) |dimension| {
            const low: Numeric = .{ .value = 1, .dimension = dimension };
            const high: Numeric = .{ .value = 2, .dimension = dimension };
            try testing.expectEqual(ifs.Truth.true, ifs.compareRange(@as([]const Numeric, &.{ low, high }), &.{.less}));
            try testing.expectEqual(ifs.Truth.true, ifs.compareRange(@as([]const Numeric, &.{ low, low }), &.{.equal}));
            try testing.expectEqual(ifs.Truth.true, ifs.compareRange(@as([]const Numeric, &.{ high, low, low }), &.{ .greater, .greater_equal }));
            try testing.expectEqual(ifs.Truth.false, ifs.compareRange(@as([]const Numeric, &.{ low, high, low }), &.{ .less_equal, .less }));
        }
        const zero: Numeric = .{ .value = 0, .dimension = .number };
        const length_zero: Numeric = .{ .value = 0, .dimension = .length };
        try testing.expectEqual(ifs.Truth.true, ifs.compareRange(@as([]const Numeric, &.{ zero, length_zero, zero }), &.{ .less_equal, .less_equal }));
        for ([_]Dimension{ .percentage, .angle, .time, .frequency, .resolution }) |dimension| {
            try testing.expectEqual(ifs.Truth.false, ifs.compareRange(@as([]const Numeric, &.{ zero, .{ .value = 0, .dimension = dimension } }), &.{.equal}));
        }
        try testing.expectEqual(ifs.Truth.false, ifs.compareRange(@as([]const Numeric, &.{ .{ .value = 1, .dimension = .number }, length_zero }), &.{.greater}));
        try testing.expectEqual(ifs.Truth.false, ifs.compareRange(@as([]const Numeric, &.{ .{ .value = std.math.nan(f64), .dimension = .number }, zero }), &.{.equal}));
        try testing.expectEqual(ifs.Truth.true, ifs.compareRange(@as([]const Numeric, &.{ .{ .value = std.math.inf(f64), .dimension = .number }, zero }), &.{.greater}));
        try testing.expectEqual(ifs.Truth.false, ifs.compareRange(@as([]const Numeric, &.{}), &.{}));
    }
} else struct {};

test "if() style queries parse boolean plain range and nested expressions" {
    if (comptime !available) return error.StyleQueryNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.queries, .{});
}

test "if() style query grammar rejects malformed features and mixed range directions" {
    if (comptime !available) return error.StyleQueryNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.invalid, .{});
}

test "if() style features keep unresolved values lazy and preserve error distinctions" {
    if (comptime !available) return error.StyleQueryNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.lazy, .{});
}

test "if() standard-property style queries stay unknown without calling the host" {
    if (comptime !available) return error.StyleQueryNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.standardProperties, .{});
}

test "if() numeric ranges compare canonical dimensions and coerce only zero to length" {
    if (comptime !available or !@hasDecl(css.if_function, "compareRange")) return error.NumericRangeNotImplemented;
    try RangeChecks.ranges();
}

test "if() range grammar matches shipping chained equality and comment-separated operators" {
    if (comptime !available) return error.StyleQueryNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.rangeGrammar, .{});
}

test "if() style values preserve comparisons inside nested component blocks" {
    if (comptime !available) return error.StyleQueryNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.nestedValueTokens, .{});
}

test "if() chained ranges match the complete shipping operator acceptance matrix" {
    if (comptime !available) return error.StyleQueryNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.rangeMatrix, .{});
}
