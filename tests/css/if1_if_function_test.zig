//! CSS Values 5 §8.3 / §3.2: branch grammar and three-valued conditions.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Checks = if (@hasDecl(css, "if_function")) struct {
    const if_function = css.if_function;

    fn branches(allocator: std.mem.Allocator) !void {
        var parsed = (try if_function.parseArguments(allocator, "style(--x: fn(a;b)): fn(x;y); else: {red, blue};")) orelse return error.ExpectedValidArguments;
        defer parsed.deinit();
        try testing.expectEqual(@as(usize, 2), parsed.branches.len);
        try testing.expectEqualStrings("style(--x: fn(a;b))", parsed.branches[0].condition);
        try testing.expectEqualStrings("fn(x;y)", parsed.branches[0].value);
        try testing.expectEqualStrings("else", parsed.branches[1].condition);
        // Browser ruling 1025d2: a branch's braces are its component value.
        try testing.expectEqualStrings("{red, blue}", parsed.branches[1].value);
    }

    fn emptyValues(allocator: std.mem.Allocator) !void {
        var parsed = (try if_function.parseArguments(allocator, "style(--x):; else:")) orelse return error.ExpectedValidArguments;
        defer parsed.deinit();
        try testing.expectEqual(@as(usize, 2), parsed.branches.len);
        try testing.expectEqualStrings("", parsed.branches[0].value);
        try testing.expectEqualStrings("", parsed.branches[1].value);
    }

    fn invalid(allocator: std.mem.Allocator) !void {
        for ([_][]const u8{
            "",                           ";",                  "else",    ": red",            "else: red;;", "else: red; ;", "else: red, blue",
            "style(--x): red !important", "else: url(bad url)", "else: ]", "else: {red} blue",
        }) |input| {
            var result = try if_function.parseArguments(allocator, input);
            defer if (result) |*parsed| parsed.deinit();
            try testing.expect(result == null);
        }
    }

    const Queries = struct {
        calls: usize = 0,

        pub fn evaluate(self: *@This(), kind: if_function.QueryKind, text: []const u8) !if_function.Truth {
            self.calls += 1;
            if (kind == .style and std.mem.eql(u8, text, "--yes")) return .true;
            if (kind == .media and std.mem.eql(u8, text, "width < 0px")) return .false;
            if (kind == .supports and std.mem.eql(u8, text, "display: block")) return .true;
            return .unknown;
        }
    };

    fn booleanExpressions(allocator: std.mem.Allocator) !void {
        const Case = struct { text: []const u8, expected: if_function.Truth };
        for ([_]Case{
            .{ .text = "else", .expected = .true },
            .{ .text = "style(--yes)", .expected = .true },
            .{ .text = "not media(width < 0px)", .expected = .true },
            .{ .text = "style(--yes) and supports(display: block)", .expected = .true },
            .{ .text = "unknown(x)", .expected = .unknown },
            .{ .text = "not unknown(x)", .expected = .unknown },
            .{ .text = "unknown(x) and media(width < 0px)", .expected = .false },
            .{ .text = "unknown(x) or style(--yes)", .expected = .true },
            .{ .text = "(not (unknown(x) or media(width < 0px)))", .expected = .unknown },
        }) |case| {
            var condition = (try if_function.parseCondition(allocator, case.text)) orelse return error.ExpectedValidCondition;
            defer condition.deinit();
            var queries: Queries = .{};
            try testing.expectEqual(case.expected, try condition.evaluate(&queries));
        }
    }

    fn componentValues(allocator: std.mem.Allocator) !void {
        // CSS Values 5 §3.1.1 restricts {} blocks, not () or [] blocks.
        // The cached markdown drops literal {}, so the source commit is cited
        // in the lane's D7 evidence before this regression was added.
        var parsed = (try if_function.parseArguments(allocator, "style(--x): [a;b] (x:y); else: url(icon.svg) ")) orelse return error.ExpectedComponentValues;
        defer parsed.deinit();
        try testing.expectEqualStrings("[a;b] (x:y)", parsed.branches[0].value);
        try testing.expectEqualStrings("url(icon.svg) ", parsed.branches[1].value);
        var many = (try if_function.parseArguments(allocator, "style(--a):a;style(--b):b;style(--c):c;style(--d):d;style(--e):e;else:f")) orelse return error.ExpectedValidArguments;
        defer many.deinit();
        try testing.expectEqual(@as(usize, 6), many.branches.len);
    }

    fn grammar(allocator: std.mem.Allocator) !void {
        for ([_][]const u8{
            "",                             "else junk",     "not else",       "style(--yes) and", "style(--yes) and media(x) or supports(y)",
            "not style(--yes) or media(x)", "style(--yes))", "[style(--yes)]", "style(\"bad\n)",
        }) |input| {
            var parsed = try if_function.parseCondition(allocator, input);
            defer if (parsed) |*condition| condition.deinit();
            try testing.expect(parsed == null);
        }
        var condition = (try if_function.parseCondition(allocator, "\\65 lse")) orelse return error.ExpectedEscapedKeyword;
        defer condition.deinit();
        var queries: Queries = .{};
        try testing.expectEqual(if_function.Truth.true, try condition.evaluate(&queries));
        try testing.expectEqual(@as(usize, 0), queries.calls);
    }

    fn lateConditions(allocator: std.mem.Allocator) !void {
        var parsed = (try if_function.parseArguments(allocator, "nonsense: red; {else}: blue; else: {red, blue}")) orelse return error.ExpectedLateConditions;
        defer parsed.deinit();
        try testing.expectEqualStrings("{else}", parsed.branches[1].condition);
        for (parsed.branches[0..2]) |branch| {
            var condition = try if_function.parseCondition(allocator, branch.condition);
            defer if (condition) |*value| value.deinit();
            try testing.expect(condition == null);
        }
        try testing.expectEqualStrings("{red, blue}", parsed.branches[2].value);
    }

    const FallibleQueries = struct {
        calls: usize = 0,
        pub fn evaluate(self: *@This(), _: if_function.QueryKind, text: []const u8) error{OutOfMemory}!if_function.Truth {
            self.calls += 1;
            if (std.mem.eql(u8, text, "--yes")) return .true;
            if (std.mem.eql(u8, text, "--no")) return .false;
            return error.OutOfMemory;
        }
    };

    fn shortCircuit(allocator: std.mem.Allocator) !void {
        for ([_][]const u8{ "style(--yes) or style(--oom)", "style(--no) and style(--oom)" }) |input| {
            var condition = (try if_function.parseCondition(allocator, input)).?;
            defer condition.deinit();
            var queries: FallibleQueries = .{};
            _ = try condition.evaluate(&queries);
            try testing.expectEqual(@as(usize, 1), queries.calls);
        }
        var condition = (try if_function.parseCondition(allocator, "style(--oom)")).?;
        defer condition.deinit();
        var queries: FallibleQueries = .{};
        try testing.expectError(error.OutOfMemory, condition.evaluate(&queries));
    }
} else struct {};

test "if() argument grammar respects nested delimiters and retains branch braces" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.branches, .{});
}

test "if() branches may have empty values" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try Checks.emptyValues(testing.allocator);
}

test "if() rejects malformed argument lists and declaration tokens" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try Checks.invalid(testing.allocator);
}

test "if() boolean expression preserves unknown through negation and nested groups" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.booleanExpressions, .{});
}

test "if() value grammar accepts square and round blocks and preserves source spans" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.componentValues, .{});
}

test "if() condition grammar rejects malformed combinations and decodes escaped keywords" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.grammar, .{});
}

test "if() boolean evaluation short-circuits and propagates query allocation failures" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.shortCircuit, .{});
}

test "if() parses invalid conditions late and retains invalid wrapped conditions" {
    if (comptime !@hasDecl(css, "if_function")) return error.IfFunctionNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.lateConditions, .{});
}
