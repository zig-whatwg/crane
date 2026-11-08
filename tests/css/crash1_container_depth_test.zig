//! Lane crash1: @container conditions nested 60,000 deep crashed the process
//! (SIGSEGV in container_queries.zig: query -> inParens -> query recursed
//! once per parenthesis, each level re-tokenizing its contents). The media
//! query parser beside it has bounded the same <query-in-parens> grammar at
//! 128 levels since lane mq (media_queries.zig max_nesting: deeper is a
//! syntax error); container conditions now share that bound - deeper makes
//! the condition invalid, so the @container rule is dropped, as Firefox 159
//! drops it at 10,000 (its 75-block bound; Chrome 156 keeps it at 10,000 and
//! crashes at 60,000, probe tmp/crash1/probe/results-*2.jsonl).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn nested(a: std.mem.Allocator, extra: usize) ![]u8 {
    var text: std.ArrayList(u8) = .empty;
    errdefer text.deinit(a);
    try text.appendNTimes(a, '(', extra);
    try text.appendSlice(a, "(width > 0px)");
    try text.appendNTimes(a, ')', extra);
    return text.toOwnedSlice(a);
}

test "crash1: container conditions nest to media queries' 128 levels; deeper is invalid, not a crash" {
    const a = testing.allocator;
    for ([_]struct { extra: usize, valid: bool }{
        .{ .extra = 0, .valid = true },
        .{ .extra = 127, .valid = true },
        .{ .extra = 128, .valid = false },
        .{ .extra = 10_000, .valid = false },
        .{ .extra = 60_000, .valid = false },
    }) |case| {
        const text = try nested(a, case.extra);
        defer a.free(text);
        var list = try css.container_queries.parse(a, text);
        defer if (list) |*l| l.deinit();
        try testing.expectEqual(case.valid, list != null);
    }
}

test "crash1: a deep style() query is bounded the same way" {
    const a = testing.allocator;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(a);
    try text.appendSlice(a, "style(");
    try text.appendNTimes(a, '(', 60_000);
    try text.appendSlice(a, "--x: 1");
    try text.appendNTimes(a, ')', 60_001);
    var list = try css.container_queries.parse(a, text.items);
    defer if (list) |*l| l.deinit();
    try testing.expect(list == null);
}
