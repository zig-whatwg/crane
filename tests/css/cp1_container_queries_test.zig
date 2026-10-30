//! CSS Conditional 5 sections 5.4, 6 and 9.1: parse without evaluating layout.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn check(allocator: std.mem.Allocator, text: []const u8, expected: []const u8) !void {
    var parsed = (try css.container_queries.parse(allocator, text)) orelse return error.ExpectedContainerQuery;
    defer parsed.deinit();
    const actual = try parsed.serialize(allocator);
    defer allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

fn sizeCases(allocator: std.mem.Allocator) !void {
    try check(allocator, "Name", "Name");
    try check(allocator, "Name (widTH>=10PX)", "Name (width >= 10px)");
    // MQ5 section 3 prohibits whitespace tokens between < or > and =.
    // Comments produce no token (liaison Q57, 2026-10-27).
    try check(allocator, "(WIDTH</**/=10PX)", "(width <= 10px)");
    try check(allocator, "(10PX>/**/=WIDTH>/**/=1PX)", "(10px >= width >= 1px)");
    try check(allocator, "(WIDTH< /*x*/=10PX)", "(WIDTH< /*x*/=10PX)");
    try check(allocator, "(WIDTH<\n=10PX)", "(WIDTH<\n=10PX)");
    try check(allocator, "(width),(height) ,--foo ,--bar", "(width), (height), --foo, --bar");
    try check(allocator, "\\!-name (inline-size > 200px    )", "\\!-name (inline-size > 200px)");
    try check(allocator, "(  MAX-WIDTH:100px  )", "(max-width: 100px)");
    try check(allocator, "(100px>WIDTH>10px)", "(100px > width > 10px)");
    try check(allocator, "not ((width:10px) OR (height:20px))", "not ((width: 10px) or (height: 20px))");
    try check(allocator, "(calc(1em + 1px) >= width >= max(10em, 10px))", "(calc(1em + 1px) >= width >= max(10em, 10px))");
    try check(allocator, "( WIDTH ==  10px )", "( WIDTH ==  10px )");
    try check(allocator, "FUTURE( URL(\"x\") ,  [a])", "FUTURE( URL(\"x\") ,  [a])");
    // General-enclosed keeps source only AFTER CSS input preprocessing.
    try check(allocator, "FUTURE(\r\n\x00\x0c\xed\xa0\x80)", "FUTURE(\n�\n�)");
}

test "container queries serialize names sizes ranges and boolean grouping" {
    if (comptime @hasDecl(css, "container_queries")) {
        try sizeCases(a);
        var parsed = (try css.container_queries.parse(a, "Name (width > 10px), style(--flag)")) orelse return error.ExpectedContainerQuery;
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 2), parsed.conditions.len);
        try std.testing.expectEqualStrings("Name", parsed.conditions[0].name);
        try std.testing.expectEqualStrings("(width > 10px)", parsed.conditions[0].query);
        try std.testing.expectEqualStrings("", parsed.conditions[1].name);
    } else return error.MissingContainerQueries;
}

fn featureCases(allocator: std.mem.Allocator) !void {
    try check(allocator, "STyle(  --FOO:bar   baz  )", "style(--FOO: bar   baz)");
    try check(allocator, "STyle(--foo:    )", "style(--foo: )");
    try check(allocator, "style(--foo:2.100  )", "style(--foo: 2.100)");
    try check(allocator, "style(--foo: bar !important)", "style(--foo: bar)");
    try check(allocator, "STyle( --foo:bar; )", "STyle( --foo:bar; )");
    try check(allocator, "style(((--FOO: BAR)) AND (--bar: foo))", "style(((--FOO: BAR)) and (--bar: foo))");
    try check(allocator, "style((--FOO: BAR) OR ( prop: val  ))", "style((--FOO: BAR) or ( prop: val  ))");
    try check(allocator, "style(100px  > --\\{foo >10px)", "style(100px > --\\{foo > 10px)");
    try check(allocator, "style(10px<=env(safe-area-inset-top) <20px)", "style(10px <= env(safe-area-inset-top) < 20px)");
    try check(allocator, "style(--x: var(--a, env(test)))", "style(--x: var(--a, env(test)))");
    try check(allocator, "style (--foo: bar)", "style (--foo: bar)");
    // Q28/Q42's all-three-browser serialization probe (2026-10-27).
    try check(allocator, "style( COLOR : RED )", "style( COLOR : RED )");
    try check(allocator, "style( width: 10PX )", "style( width: 10PX )");
    try check(allocator, "style( color )", "style( color )");
    try check(allocator, "scroll-STate(  stuck:TOP   )", "scroll-state(stuck: top)");
    try check(allocator, "scroll-STate(stuck:    )", "scroll-STate(stuck:    )");
    try check(allocator, "scroll-state((snapped:X) OR (scrolled:BLOCK-END))", "scroll-state((snapped: x) or (scrolled: block-end))");
    try check(allocator, "scroll-state(scrollable)", "scroll-state(scrollable)");
}

test "container style and scroll-state features preserve unknown source text" {
    if (comptime @hasDecl(css, "container_queries")) {
        try featureCases(a);
    } else return error.MissingContainerQueries;
}

test "container condition lists reject malformed grammar without forgiving entries" {
    if (comptime @hasDecl(css, "container_queries")) {
        for ([_][]const u8{ "", " ", ")", "(width),", ",(width)", "(width),,(height)", "none", "initial", "and", "not", "foo foo", "foo not screen", "(width) and (height) or (orientation)", "(width) trailing", "(width", "style(\"bad\n)", "future([)]", "(width > url(a b))" }) |text| {
            var result = try css.container_queries.parse(a, text);
            if (result) |*owned| owned.deinit();
            try std.testing.expect(result == null);
        }
    } else return error.MissingContainerQueries;
}

test "container condition parsing unwinds every allocation failure" {
    if (comptime @hasDecl(css, "container_queries")) {
        try std.testing.checkAllAllocationFailures(a, sizeCases, .{});
        try std.testing.checkAllAllocationFailures(a, featureCases, .{});
    } else return error.MissingContainerQueries;
}
