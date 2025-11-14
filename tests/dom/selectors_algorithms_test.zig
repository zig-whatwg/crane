//! Tests migrated from src/dom/selectors.zig
//! Per WHATWG specifications

const std = @import("std");

const dom = @import("dom");

test "selectors: scopeMatchSelectorsString with no matches" {
    const allocator = testing.allocator;

    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();

    // Query for "p" (but tree only has div)
    var matches = try dom.scopeMatchSelectorsString(allocator, "p", &root);
    defer matches.deinit();

    try testing.expectEqual(@as(usize, 0), matches.items().len);
}
test "selectors: scopeMatchSelectorsString with syntax error" {
    const allocator = testing.allocator;

    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();

    // Invalid selector should return SyntaxError
    const result = dom.scopeMatchSelectorsString(allocator, ">>", &root);
    try testing.expectError(error.SyntaxError, result);
}