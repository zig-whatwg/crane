//! Counter Styles 3 §§2.1, 3, 9.2. Q28 all-browser probe, 2026-10-27.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn cases(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "counter_style_descriptors")) return std.testing.expect(false);
    var parsed = (try css.rules.parseRule(allocator, "@counter-style foo { system: cyclic; symbols: a b; }")) orelse return error.TestUnexpectedResult;
    defer parsed.deinitOwned(allocator);
    var data = (try css.counter_style_descriptors.fromParsed(allocator, &parsed)) orelse return error.TestUnexpectedResult;
    defer data.deinit();
    for ([_][]const u8{ "", "123", "a b", "initial", "inherit", "unset", "revert", "revert-layer", "default", "none", "DECIMAL" }) |invalid| {
        try std.testing.expect(!try data.setName(invalid));
        try std.testing.expectEqualStrings("foo", data.name);
    }
    try std.testing.expect(try data.setName("LOWER-ROMAN"));
    try std.testing.expectEqualStrings("lower-roman", data.name);
    for ([_][]const u8{ "url(\"x\")", "linear-gradient(red, blue)", "initial" }) |invalid| {
        try std.testing.expect(!try data.set(.symbols, invalid));
        try std.testing.expectEqualStrings("a b", data.get(.symbols));
    }
    try std.testing.expect(try data.set(.symbols, "a \"b\""));
    try std.testing.expectEqualStrings("a \"b\"", data.get(.symbols));
    try std.testing.expect(try data.set(.symbols, "none"));
    try std.testing.expectEqualStrings("none", data.get(.symbols));
    try std.testing.expect(!try data.set(.system, "numeric")); // algorithm immutable
    try std.testing.expectEqualStrings("cyclic", data.get(.system));
    try std.testing.expect(try data.set(.negative, "'(' ')'"));
    try std.testing.expectEqualStrings("\"(\" \")\"", data.get(.negative));
    try std.testing.expect(try data.set(.pad, "\"0\" 3"));
    try std.testing.expectEqualStrings("3 \"0\"", data.get(.pad));
    try std.testing.expect(try data.set(.range, "infinite -1, 1 infinite"));
    try std.testing.expectEqualStrings("infinite -1, 1 infinite", data.get(.range));
    try std.testing.expect(!try data.set(.range, "2 1"));
    try std.testing.expect(try data.set(.fallback, "UPPER-ROMAN"));
    try std.testing.expectEqualStrings("upper-roman", data.get(.fallback));
    try std.testing.expect(try data.set(.speak_as, "WORDS"));
    try std.testing.expectEqualStrings("words", data.get(.speak_as));
    const text = try data.cssText(allocator);
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOfScalar(u8, text, '\n') == null);
    try std.testing.expectEqualStrings(
        "@counter-style lower-roman { system: cyclic; symbols: none; negative: \"(\" \")\"; pad: 3 \"0\"; range: infinite -1, 1 infinite; fallback: upper-roman; speak-as: words; }",
        text,
    );
}

test "counter descriptor CSSOM rulings and mutation are allocation-safe" {
    try std.testing.checkAllAllocationFailures(a, cases, .{});
}

fn systems(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "counter_style_descriptors")) return std.testing.expect(false);
    const Cases = struct { source: []const u8, field: css.counter_style_descriptors.Descriptor, valid: []const u8, invalid: []const u8, expected: []const u8 };
    const cases_list = [_]Cases{
        .{ .source = "system: fixed; symbols: a b", .field = .system, .valid = "FIXED -2", .invalid = "cyclic", .expected = "fixed -2" },
        .{ .source = "system: extends decimal", .field = .system, .valid = "extends LOWER-ROMAN", .invalid = "symbolic", .expected = "extends lower-roman" },
        .{ .source = "system: numeric; symbols: a b", .field = .symbols, .valid = "x y", .invalid = "x", .expected = "x y" },
        .{ .source = "system: additive; additive-symbols: 2 a, 1 b", .field = .additive_symbols, .valid = "z 5, 2 x, 0 y", .invalid = "2 a, 2 b", .expected = "5 z, 2 x, 0 y" },
    };
    for (cases_list) |case| {
        const source = try std.fmt.allocPrint(allocator, "@counter-style foo {{ {s}; }}", .{case.source});
        defer allocator.free(source);
        var parsed = (try css.rules.parseRule(allocator, source)).?;
        defer parsed.deinitOwned(allocator);
        var data = (try css.counter_style_descriptors.fromParsed(allocator, &parsed)).?;
        defer data.deinit();
        try std.testing.expect(try data.set(case.field, case.valid));
        try std.testing.expect(!try data.set(case.field, case.invalid));
        try std.testing.expectEqualStrings(case.expected, data.get(case.field));
    }
}

test "counter descriptor setters preserve a defined system and its algorithm" {
    try std.testing.checkAllAllocationFailures(a, systems, .{});
}

fn mathCases() anyerror!void {
    if (comptime !@hasDecl(css, "counter_style_descriptors")) return std.testing.expect(false);
    const model = css.counter_style_descriptors;
    // Three-browser probes q43/q44, 2026-10-27. These are tested through
    // both stylesheet parsing and CSSOM mutation, as in the probes.
    const Case = struct { field: model.Descriptor, input: []const u8, expected: ?[]const u8 };
    const cases_list = [_]Case{
        .{ .field = .system, .input = "fixed", .expected = "fixed 1" },
        .{ .field = .system, .input = "fixed calc(1 + 1)", .expected = "fixed calc(2)" },
        .{ .field = .system, .input = "fixed calc(1px / 1px)", .expected = "fixed calc(1)" },
        .{ .field = .system, .input = "fixed calc(2.5)", .expected = "fixed calc(2.5)" },
        .{ .field = .pad, .input = "calc(1 + 1) \"0\"", .expected = "calc(2) \"0\"" },
        .{ .field = .range, .input = "calc(1 + 1) 5", .expected = "calc(2) 5" },
        .{ .field = .range, .input = "1 calc(2 + 3)", .expected = "1 calc(5)" },
        .{ .field = .additive_symbols, .input = "calc(1 + 1) a, 1 b", .expected = "calc(2) a, 1 b" },
        .{ .field = .additive_symbols, .input = "2 a, calc(1) b", .expected = "2 a, calc(1) b" },
        .{ .field = .system, .input = "fixed 2147483648", .expected = "fixed 2147483647" },
        .{ .field = .system, .input = "fixed -2147483649", .expected = "fixed -2147483648" },
        .{ .field = .pad, .input = "2147483648 \"0\"", .expected = "2147483647 \"0\"" },
        .{ .field = .range, .input = "2147483648 2147483649", .expected = "2147483647 2147483647" },
        .{ .field = .range, .input = "-2147483649 5", .expected = "-2147483648 5" },
        .{ .field = .range, .input = "1 2147483648", .expected = "1 2147483647" },
        .{ .field = .additive_symbols, .input = "2147483648 a, 1 b", .expected = "2147483647 a, 1 b" },
        .{ .field = .system, .input = "fixed 1e20", .expected = null },
        .{ .field = .pad, .input = "1e20 \"0\"", .expected = null },
        .{ .field = .range, .input = "1e20 5", .expected = null },
        .{ .field = .range, .input = "1 1e20", .expected = null },
        .{ .field = .additive_symbols, .input = "1e20 a, 1 b", .expected = null },
        .{ .field = .pad, .input = "-1 \"0\"", .expected = null },
        .{ .field = .pad, .input = "-2147483649 \"0\"", .expected = null },
        .{ .field = .additive_symbols, .input = "-1 a", .expected = null },
        .{ .field = .additive_symbols, .input = "-2147483649 a", .expected = null },
        .{ .field = .system, .input = "fixed calc(1em / 1px)", .expected = "fixed calc(1em / 1px)" },
        .{ .field = .system, .input = "fixed calc(1px / 1em)", .expected = "fixed calc(1px / 1em)" },
        .{ .field = .system, .input = "fixed calc(1vw / 1px)", .expected = "fixed calc(1vw / 1px)" },
        .{ .field = .pad, .input = "calc(1em / 1px) \"0\"", .expected = "calc(1em / 1px) \"0\"" },
        .{ .field = .pad, .input = "calc(1px / 1em) \"0\"", .expected = "calc(1px / 1em) \"0\"" },
        .{ .field = .pad, .input = "calc(1vw / 1px) \"0\"", .expected = "calc(1vw / 1px) \"0\"" },
        .{ .field = .range, .input = "calc(1em / 1px) 5", .expected = null },
        .{ .field = .range, .input = "1 calc(1em / 1px)", .expected = null },
        .{ .field = .range, .input = "calc(1px / 1em) 5", .expected = null },
        .{ .field = .range, .input = "1 calc(1px / 1em)", .expected = null },
        .{ .field = .range, .input = "calc(1vw / 1px) 5", .expected = null },
        .{ .field = .range, .input = "1 calc(1vw / 1px)", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(1em / 1px) a, 1 b", .expected = null },
        .{ .field = .additive_symbols, .input = "2 a, calc(1em / 1px) b", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(1px / 1em) a, 1 b", .expected = null },
        .{ .field = .additive_symbols, .input = "2 a, calc(1px / 1em) b", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(1vw / 1px) a, 1 b", .expected = null },
        .{ .field = .additive_symbols, .input = "2 a, calc(1vw / 1px) b", .expected = null },
        .{ .field = .system, .input = "fixed calc(sibling-index())", .expected = null },
        .{ .field = .pad, .input = "calc(sibling-index()) \"0\"", .expected = null },
        .{ .field = .range, .input = "calc(sibling-index()) 5", .expected = null },
        .{ .field = .range, .input = "1 calc(sibling-index())", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(sibling-index()) a, 1 b", .expected = null },
        .{ .field = .additive_symbols, .input = "2 a, calc(sibling-index()) b", .expected = null },
        .{ .field = .system, .input = "fixed calc(2147483648)", .expected = "fixed calc(2147483648)" },
        .{ .field = .pad, .input = "calc(2147483648) \"0\"", .expected = "calc(2147483648) \"0\"" },
        .{ .field = .range, .input = "calc(2147483648) calc(2147483649)", .expected = "calc(2147483648) calc(2147483649)" },
        .{ .field = .additive_symbols, .input = "calc(2147483648) a, 1 b", .expected = "calc(2147483648) a, 1 b" },
        .{ .field = .pad, .input = "calc(-1) \"0\"", .expected = "calc(-1) \"0\"" },
        .{ .field = .additive_symbols, .input = "calc(-1) a", .expected = "calc(-1) a" },
        .{ .field = .additive_symbols, .input = "1 a, calc(2) b", .expected = null },
        .{ .field = .range, .input = "calc(5) 1", .expected = null },
        // Q46: compare resolved integers, preserve specified calculations.
        .{ .field = .additive_symbols, .input = "calc(1.4) a, calc(1.3) b", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(2.4) a, 2 b", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(2147483648) a, calc(2147483647) b", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(2147483648) a, 2147483647 b", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(NaN) a, calc(-1) b", .expected = null },
        .{ .field = .additive_symbols, .input = "calc(NaN) a", .expected = "calc(NaN) a" },
        .{ .field = .additive_symbols, .input = "1 a, calc(NaN) b", .expected = "1 a, calc(NaN) b" },
        .{ .field = .additive_symbols, .input = "1 a, calc(-infinity) b", .expected = "1 a, calc(-infinity) b" },
        .{ .field = .additive_symbols, .input = "calc(1.6) a, calc(1.4) b", .expected = "calc(1.6) a, calc(1.4) b" },
        .{ .field = .additive_symbols, .input = "calc(infinity) a, 1 b", .expected = "calc(infinity) a, 1 b" },
        .{ .field = .range, .input = "calc(1.4) calc(1.3)", .expected = "calc(1.4) calc(1.3)" },
        .{ .field = .range, .input = "calc(1.4) 1", .expected = "calc(1.4) 1" },
        .{ .field = .range, .input = "1 calc(0.6)", .expected = "1 calc(0.6)" },
        .{ .field = .range, .input = "calc(2147483648) calc(2147483647)", .expected = "calc(2147483648) calc(2147483647)" },
        .{ .field = .range, .input = "calc(2147483648) 2147483647", .expected = "calc(2147483648) 2147483647" },
        .{ .field = .range, .input = "calc(NaN) 5", .expected = "calc(NaN) 5" },
        .{ .field = .range, .input = "5 calc(NaN)", .expected = null },
        .{ .field = .range, .input = "calc(infinity) 5", .expected = null },
        .{ .field = .range, .input = "5 calc(infinity)", .expected = "5 calc(infinity)" },
        .{ .field = .range, .input = "calc(-infinity) 5", .expected = "calc(-infinity) 5" },
    };
    const Operation = struct {
        fn run(allocator: std.mem.Allocator, case: Case) anyerror!void {
            // Test parse-time acceptance independently from the setter's
            // defined-style and algorithm checks.
            const source = try std.fmt.allocPrint(allocator, "@counter-style x {{ {s}: {s}; }}", .{ case.field.name(), case.input });
            defer allocator.free(source);
            var parsed = (try css.rules.parseRule(allocator, source)).?;
            defer parsed.deinitOwned(allocator);
            var data = (try model.fromParsed(allocator, &parsed)).?;
            defer data.deinit();
            try std.testing.expectEqualStrings(case.expected orelse "", data.get(case.field));

            const initial = if (case.field == .additive_symbols)
                "@counter-style x { system: additive; additive-symbols: 2 a, 1 b; }"
            else
                "@counter-style x { system: fixed 1; symbols: a b; }";
            var initial_parsed = (try css.rules.parseRule(allocator, initial)).?;
            defer initial_parsed.deinitOwned(allocator);
            var current = (try model.fromParsed(allocator, &initial_parsed)).?;
            defer current.deinit();
            const before = try allocator.dupe(u8, current.get(case.field));
            defer allocator.free(before);
            try std.testing.expectEqual(case.expected != null, try current.set(case.field, case.input));
            try std.testing.expectEqualStrings(case.expected orelse before, current.get(case.field));
        }
    };
    // Q98/Q99: inject every site per independent row, without replaying earlier rows.
    for (cases_list) |case| try std.testing.checkAllAllocationFailures(a, Operation.run, .{case});
}

test "counter integer math follows browser range and context rulings without invented inputs" {
    try mathCases();
}
