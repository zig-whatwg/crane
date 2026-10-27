//! CSS Shadow 1 §5.3 and §5.6: part mappings and successive name forwarding.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "part mapping tokens preserve spelling and allow identity mappings" {
    const parts = css.shadow_parts;
    const cases = [_]struct { text: []const u8, inner: []const u8, outer: []const u8 }{
        .{ .text = "inner:outer", .inner = "inner", .outer = "outer" },
        .{ .text = " \tinner \n:\r outer\x0c", .inner = "inner", .outer = "outer" },
        .{ .text = "identity", .inner = "identity", .outer = "identity" },
        .{ .text = "Case:case", .inner = "Case", .outer = "case" },
        .{ .text = "1:2", .inner = "1", .outer = "2" },
        .{ .text = "a.b:c/d", .inner = "a.b", .outer = "c/d" },
        .{ .text = "a\\62:c", .inner = "a\\62", .outer = "c" },
        .{ .text = "a\x0bb:c", .inner = "a\x0bb", .outer = "c" },
        .{ .text = "a\u{a0}b:c", .inner = "a\u{a0}b", .outer = "c" },
    };
    for (cases) |case| {
        var iterator = parts.MappingIterator.init(case.text);
        const mapping = iterator.next() orelse return error.ExpectedPartMapping;
        try testing.expectEqualStrings(case.inner, mapping.inner.part);
        try testing.expectEqualStrings(case.outer, mapping.outer);
        try testing.expect(iterator.next() == null);
    }
}

test "part mapping lists recover at commas and keep multiple outputs" {
    var iterator = css.shadow_parts.MappingIterator.init(
        ", ,a:b,a:c,broken entry,x:, :y,k:l:tail,good,a:b,",
    );
    const expected = [_][2][]const u8{ .{ "a", "b" }, .{ "a", "c" }, .{ "good", "good" }, .{ "a", "b" } };
    for (expected) |pair| {
        const mapping = iterator.next() orelse return error.ExpectedPartMapping;
        try testing.expectEqualStrings(pair[0], mapping.inner.part);
        try testing.expectEqualStrings(pair[1], mapping.outer);
    }
    try testing.expect(iterator.next() == null);
    for ([_][]const u8{ "", " \t\r\n\x0c", ":", "a:", ":a", "a b", "a:b c", "a::b", "a:b:c", "a : : b" }) |text| {
        var bad = css.shadow_parts.MappingIterator.init(text);
        try testing.expect(bad.next() == null);
    }
}

test "pseudo-element mappings retain their distinct source for later matching" {
    // §5.3 extends the ordinary §5.6 microsyntax. The parser keeps pseudo
    // candidates; the pseudo matcher decides whether they are fully styleable.
    var iterator = css.shadow_parts.MappingIterator.init("::before : leading,::AFTER:trailing,::future-pseudo:future");
    const expected = [_][2][]const u8{ .{ "before", "leading" }, .{ "AFTER", "trailing" }, .{ "future-pseudo", "future" } };
    for (expected) |pair| {
        const mapping = iterator.next() orelse return error.ExpectedPartMapping;
        try testing.expectEqualStrings(pair[0], mapping.inner.pseudo);
        try testing.expectEqualStrings(pair[1], mapping.outer);
    }
    try testing.expect(iterator.next() == null);
    for ([_][]const u8{ "::", "::before", ":: before:x", ":::before:x", "::before:x:y", "::before:", "a:::before" }) |text| {
        var bad = css.shadow_parts.MappingIterator.init(text);
        try testing.expect(bad.next() == null);
    }
}

fn expectNames(expected: []const []const u8, actual: []const []const u8) !void {
    try testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |want, got| try testing.expectEqualStrings(want, got);
}

test "part attribute names split only HTML spaces and form a case-sensitive set" {
    var names = try css.shadow_parts.fromAttribute(testing.allocator, "\tfirst first\nSecond\rsecond\x0cwith\u{a0}space a:b a\\62");
    defer names.deinit(testing.allocator);
    try expectNames(&.{ "first", "Second", "second", "with\u{a0}space", "a:b", "a\\62" }, names.items);
}

test "part forwarding unions all mappings and drops names not exported at each boundary" {
    const parts = css.shadow_parts;
    var first = try parts.forward(testing.allocator, &.{ "inner", "Other", "unexported" }, "inner:middle, inner:alias,Other:middle,inner:alias,other:wrong,::before:ignored");
    defer first.deinit(testing.allocator);
    try expectNames(&.{ "middle", "alias" }, first.items);
    var second = try parts.forward(testing.allocator, first.items, "middle:outer, alias:outer, alias:second,inner:wrong");
    defer second.deinit(testing.allocator);
    try expectNames(&.{ "outer", "second" }, second.items);
    var end = try parts.forward(testing.allocator, second.items, "");
    defer end.deinit(testing.allocator);
    try expectNames(&.{}, end.items);
    var pseudo = try parts.forward(testing.allocator, &.{"before"}, "::before:not-a-named-part,before:ordinary");
    defer pseudo.deinit(testing.allocator);
    try expectNames(&.{"ordinary"}, pseudo.items);
}

fn allocationCase(allocator: std.mem.Allocator) anyerror!void {
    var input_buffer = css.shadow_parts.nameBuffer(allocator);
    const input_allocator = input_buffer.get();
    var names = try css.shadow_parts.fromAttribute(input_allocator, "a b c d e f g h i a");
    defer names.deinit(input_allocator);
    var output_buffer = css.shadow_parts.nameBuffer(allocator);
    const output_allocator = output_buffer.get();
    var forwarded = try css.shadow_parts.forward(output_allocator, names.items, "a:one,a:two,b:three,c:four,d:five,e:six,f:seven,g:eight,h:nine,i:ten");
    defer forwarded.deinit(output_allocator);
    try testing.expectEqual(@as(usize, 10), forwarded.items.len);
}

test "part name sets clean up every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}

test "four part names and four forwarded aliases use only caller stack buffers" {
    const parts = css.shadow_parts;
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    var input_buffer = parts.nameBuffer(failing.allocator());
    const input_allocator = input_buffer.get();
    var names = try parts.fromAttribute(input_allocator, "a b c d a");
    defer names.deinit(input_allocator);
    try expectNames(&.{ "a", "b", "c", "d" }, names.items);

    var output_buffer = parts.nameBuffer(failing.allocator());
    const output_allocator = output_buffer.get();
    var forwarded = try parts.forward(output_allocator, names.items, "a:first,b:second,c:third,d:fourth,a:first");
    defer forwarded.deinit(output_allocator);
    try expectNames(&.{ "first", "second", "third", "fourth" }, forwarded.items);
}
