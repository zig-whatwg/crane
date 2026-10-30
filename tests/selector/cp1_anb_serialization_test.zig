//! CSS Syntax 3 sections 6.2 and 9.1; CSSOM selector serialization.
const std = @import("std");
const selector = @import("selector");

fn expectText(a: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
    var result = try selector.parseCssomOwned(a, try a.dupe(u8, input), .{});
    defer a.free(result.text);
    defer result.selectors.deinit();
    try std.testing.expectEqualStrings(expected, result.text);
}

test "joined An+B overflow follows Chrome and Safari rejection" {
    for ([_][]const u8{ ":nth-child(n-99999999999999999999)", ":nth-child(-n-99999999999999999999)" }) |text|
        try std.testing.expectError(error.InvalidSelector, selector.parse(std.testing.allocator, text));
    // Pins: these successful token paths already clamped before this change.
    for ([_][]const u8{ ":nth-child(n- 99999999999999999999)", ":nth-child(n - 99999999999999999999)" }) |text| {
        var list = try selector.parse(std.testing.allocator, text);
        defer list.deinit();
        const pattern = list.selectors[0].compound.simple_selectors[0].PseudoClass.kind.NthChild;
        try std.testing.expectEqual(-std.math.maxInt(i32), pattern.b);
    }
}

test "CSSOM serializes parsed An+B coefficients throughout valid selectors" {
    const cases = .{
        .{ ":nth-child(99999999999999999999)", ":nth-child(2147483647)" },
        .{ ":nth-child(99999999999999999999n)", ":nth-child(2147483647n)" },
        .{ ":nth-child(2n+99999999999999999999)", ":nth-child(2n+2147483647)" },
        .{ ":nth-child(-99999999999999999999)", ":nth-child(-2147483648)" },
        .{ ":nth-child(n - 99999999999999999999)", ":nth-child(n-2147483647)" },
        .{ ":nth-child(n- 99999999999999999999)", ":nth-child(n-2147483647)" },
        .{ ":nth-child(n + 99999999999999999999)", ":nth-child(n+2147483647)" },
        .{ ":nth-child(-99999999999999999999n)", ":nth-child(-2147483648n)" },
        .{ ":nth-child(+1)", ":nth-child(1)" },
        .{ ":nth-last-child( 0n + 0 )", ":nth-last-child(0)" },
        .{ ":nth-of-type(1n - 0)", ":nth-of-type(n)" },
        .{ ":nth-last-of-type(-1n + 2)", ":nth-last-of-type(-n+2)" },
        .{ ":nth-child(odd)", ":nth-child(2n+1)" },
        .{ ":nth-child(even)", ":nth-child(2n)" },
        .{ ":nth-child(2n + 1 of :is(.x, :nth-child(1n + 2)))", ":nth-child(2n+1 of :is(.x, :nth-child(n+2)))" },
        .{ ":host(:nth-child(1n + 1))", ":host(:nth-child(n+1))" },
    };
    inline for (cases) |pair| try expectText(std.testing.allocator, pair[0], pair[1]);
}

test "forgiven invalid branches retain their complete original text" {
    const a = std.testing.allocator;
    try expectText(a, ":is(:nth-child(99999999999999999999)???, .ok)", ":is(:nth-child(99999999999999999999)???, .ok)");
    try expectText(a, ":is(:nth-child(1n + 2), :nth-child(99999999999999999999)???)", ":is(:nth-child(n+2), :nth-child(99999999999999999999)???)");
}

fn ownership(a: std.mem.Allocator) !void {
    var result = try selector.parseCssomOwned(a, try a.dupe(u8, "article.foo:nth-child(99999999999999999999n+99999999999999999999) > .tail"), .{});
    defer a.free(result.text);
    defer result.selectors.deinit();
    try std.testing.expectEqualStrings("article.foo:nth-child(2147483647n+2147483647) > .tail", result.text);
    const list = &result.selectors.selectors[0];
    try std.testing.expectEqualStrings("tail", list.compound.simple_selectors[0].Class.class_name);
    // The ancestor's names still borrow the original source, whose ownership
    // moved into the existing outer-list string storage after normalization.
    try std.testing.expectEqualStrings("article", list.combinators[0].compound.simple_selectors[0].Type.tag_name);
    try std.testing.expectEqualStrings("foo", list.combinators[0].compound.simple_selectors[1].Class.class_name);
}

test "normalized selector text keeps all original AST names alive through every OOM" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, ownership, .{});
}

fn nestedOwnership(a: std.mem.Allocator) !void {
    try expectText(a, ":nth-child(2n + 1 of :is(.x, :nth-last-child(3n - 2 of .item)))", ":nth-child(2n+1 of :is(.x, :nth-last-child(3n-2 of .item)))");
}

test "An+B normalization unwinds owned of-selector lists on every OOM" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, nestedOwnership, .{});
}
