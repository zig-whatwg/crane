//! CSS Content 3: declaration grammar, canonical serialization and defaults.
const std = @import("std");
const css = @import("css");
const properties = css.properties;
const testing = std.testing;

fn check(value: []const u8, expected: ?[]const u8) !void {
    const property = properties.lookup("content") orelse return error.MissingContentProperty;
    var assignments: std.ArrayList(properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(testing.allocator);
    }
    const valid = try properties.parseDeclaration(.{ .allocator = testing.allocator }, property, value, &assignments);
    try testing.expectEqual(expected != null, valid);
    if (expected) |text| {
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(testing.allocator);
        try properties.serializeAssigned(assignments.items[0].longhand, assignments.items[0].value, &output, testing.allocator);
        try testing.expectEqualStrings(text, output.items);
    }
}

test "content parses strings, attribute references, alternatives and distinct layout values" {
    try check("normal", "normal");
    try check("none", "none");
    try check("'a' \"b\"", "\"a\" \"b\"");
    try check("attr(data-label)", "attr(data-label)");
    try check("attr(data-label raw-string, 'fallback')", "attr(data-label raw-string, \"fallback\")");
    try check("'visual' / 'spoken'", "\"visual\" / \"spoken\"");
    try check("counter(chapter)", "counter(chapter)");
    try check("open-quote 'inside' close-quote", "open-quote \"inside\" close-quote");
    try check("normal 'text'", null);
    try check("'text' /", null);
    try check("'text' / none", null);
    try check("attr()", null);
    try check("bogus", null);
}

test "an explicit raw-string attribute without a fallback is invalid when missing" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "content: 'prefix' attr(data-missing raw-string)");
    defer block.deinit();
    const computed = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .pseudo = "before" }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer computed.destroy();
    // Values 5 8.7: an explicit type's omitted fallback is guaranteed-invalid.
    try expectContent(computed, "none");
}

test "content functions close at EOF according to CSS Syntax" {
    try check("attr(data-label", "attr(data-label)");
    try check("counter(chapter", "counter(chapter)");
    try check("counters(chapter, '.'", "counters(chapter, \".\")");
    try check("counter(chapter, symbols('a' 'b'", "counter(chapter, symbols(\"a\" \"b\"))");
    try check("leader(dotted", "leader(dotted)");
    try check("linear-gradient(red, blue", "linear-gradient(red, blue)");
}

fn expectContent(computed: *const css.computed_style.ComputedStyle, expected: []const u8) !void {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(testing.allocator);
    try computed.serializeResolved(.content, &output, testing.allocator);
    try testing.expectEqualStrings(expected, output.items);
}

test "content normal computes to none on before and after and remains normal on elements" {
    const element = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{});
    defer element.destroy();
    try expectContent(element, "normal");
    for ([_][]const u8{ "before", "after" }) |pseudo| {
        const computed = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = element, .pseudo = pseudo }, &.{});
        defer computed.destroy();
        try expectContent(computed, "none");
    }
}

test "content attribute substitution owns the result and value copies retain it" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "content: attr(data-label) / 'spoken'");
    defer block.deinit();
    const Lookup = struct {
        value: []const u8,
        fn get(context: *const anyopaque, name: []const u8) ?[]const u8 {
            const self: *const @This() = @ptrCast(@alignCast(context));
            return if (std.mem.eql(u8, name, "data-label")) self.value else null;
        }
    };
    var lookup: Lookup = .{ .value = "first" };
    const context: css.cascade.Context = .{ .allocator = testing.allocator, .parent = null, .pseudo = "before", .content_attributes = .{ .context = &lookup, .get = Lookup.get } };
    const first = try css.cascade.cascade(context, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer first.destroy();
    const kept = first.get(.content);
    kept.retain();
    defer kept.release();
    try expectContent(first, "\"first\" / \"spoken\"");
    lookup.value = "second";
    const second = try css.cascade.cascade(context, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer second.destroy();
    try expectContent(second, "\"second\" / \"spoken\"");
    try testing.expect(!kept.eql(second.get(.content)));
    try testing.expect(kept.eql(first.get(.content)));
    var spoken: std.ArrayList(u8) = .empty;
    defer spoken.deinit(testing.allocator);
    try kept.content.appendAccessible(&spoken, testing.allocator);
    try testing.expectEqualStrings("spoken", spoken.items);
}
