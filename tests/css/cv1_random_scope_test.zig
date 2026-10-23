//! Q90: token-position ordinals survive grammar backtracking and never escape.
const std = @import("std");
const css = @import("css");
const math = css.math_values;
const testing = std.testing;
const has_scope = @hasDecl(css, "random_values") and @hasDecl(math, "parseWithScope");

fn expectText(expression: *const math.Expression, expected: []const u8) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try expression.serialize(&text, testing.allocator);
    try testing.expectEqualStrings(expected, text.items);
}

test "context free numeric math rejects property dependent random keys only" {
    if (comptime !has_scope) return error.RandomScopeNotImplemented;
    inline for (.{ "random(1px,2px)", "random(auto,1px,2px)", "random(property-scoped,1px,2px)", "random(element-scoped property-index-scoped,1px,2px)" }) |text| {
        const value = try math.parse(testing.allocator, text, .{ .kind = .length });
        defer if (value) |parsed| parsed.expression.unref();
        try testing.expect(value == null);
    }
    inline for (.{ "random(--named,1px,2px)", "random(element-scoped,1px,2px)", "random(fixed .5,1px,2px)", "random(ua-explicit,1px,2px)" }) |text| {
        const value = (try math.parse(testing.allocator, text, .{ .kind = .length })) orelse return error.InvalidRandom;
        defer value.expression.unref();
    }
}

test "random source ordinals survive a successful component followed by a restored grammar alternative" {
    if (comptime !has_scope) return error.RandomScopeNotImplemented;
    const text = "random(1px,2px) random(3px,4px)";
    var scope = try css.random_values.ParseScope.init(testing.allocator, text, "margin", .{});
    defer scope.deinit();
    const options = css.properties.ParseOptions{ .allocator = testing.allocator, .random_scope = &scope };
    var stream = css.properties.Stream.init(text);
    const before = stream;
    // The number arm fails. A length arm succeeds, but its larger grammar
    // could fail afterward: restoring its Stream must restore the ordinal too.
    try testing.expect((try css.properties.mathValue(options, &stream, .{ .kind = .number })) == null);
    stream = before;
    const tentative = (try css.properties.mathValue(options, &stream, .{ .kind = .length })).?;
    tentative.release();
    stream = before;
    const first = (try css.properties.mathValue(options, &stream, .{ .kind = .length })).?;
    defer first.release();
    const second = (try css.properties.mathValue(options, &stream, .{ .kind = .length })).?;
    defer second.release();
    try expectText(first.calculation, "random(element-scoped ua-margin-1, 1px, 2px)");
    try expectText(second.calculation, "random(element-scoped ua-margin-2, 3px, 4px)");
}

test "numeric random scope indexes named fixed and nested tokens but not comment or string contents" {
    if (comptime !has_scope) return error.RandomScopeNotImplemented;
    const text = "/* random(1,2) */ random(--x,0px,0px) random(fixed .5,0px,0px) random(10px,20px)";
    var scope = try css.random_values.ParseScope.init(testing.allocator, text, "margin", .{});
    defer scope.deinit();
    var stream = css.properties.Stream.init(text);
    const options = css.properties.ParseOptions{ .allocator = testing.allocator, .random_scope = &scope };
    for (0..3) |index| {
        const value = (try css.properties.mathValue(options, &stream, .{ .kind = .length })).?;
        defer value.release();
        if (index == 2) try expectText(value.calculation, "random(element-scoped ua-margin-3, 10px, 20px)");
    }
    var token_scope = try css.random_values.ParseScope.init(testing.allocator, "\"random(1,2)\" random(fixed random(--x,0,1),0px,1px)", "left", .{});
    defer token_scope.deinit();
    try testing.expectEqual(@as(usize, 2), token_scope.entries.len);
}

test "feature free numeric scope allocates nothing and default parse options borrow none" {
    if (comptime !has_scope) return error.RandomScopeNotImplemented;
    var failure = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    var scope = try css.random_values.ParseScope.init(failure.allocator(), "calc(1px + 2em)", "margin", .{});
    defer scope.deinit();
    try testing.expectEqual(@as(usize, 0), scope.entries.len);
    try testing.expect((css.properties.ParseOptions{ .allocator = testing.allocator }).random_scope == null);
}

test "random trees retain normalized names after their borrowed parse scope and input end" {
    if (comptime !has_scope) return error.RandomScopeNotImplemented;
    try lifetime(testing.allocator);
}

test "random source index and owned expression release every allocation failure" {
    if (comptime !has_scope) return error.RandomScopeNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, lifetime, .{});
}

fn lifetime(allocator: std.mem.Allocator) !void {
    const expression = blk: {
        const text = try allocator.dupe(u8, "random(--owned property-index-scoped,1px,2px)");
        defer allocator.free(text);
        var scope = try css.random_values.ParseScope.init(allocator, text, "left", .{});
        defer scope.deinit();
        const parsed = (try math.parseWithScope(allocator, text, .{ .kind = .length }, &scope)) orelse return error.InvalidRandom;
        break :blk parsed.expression;
    };
    defer expression.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try expression.serialize(&out, allocator);
    try testing.expectEqualStrings("random(--owned ua-left-1, 1px, 2px)", out.items);
}
