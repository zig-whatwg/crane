//! Tests migrated from src/dom/selectors.zig
//! Per WHATWG specifications

const std = @import("std");

const dom = @import("dom");
const source = @import("../../../src/dom/selectors.zig");

test "selectors: scopeMatchSelectorsString with type selector" {
    const allocator = testing.allocator;

    // Create simple tree: div > p
    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();

    var child = try allocator.create(ElementWithBase);
    defer {
        child.deinit();
        allocator.destroy(child);
    }
    child.* = ElementWithBase.init(allocator, "p");

    // Link them
    child.base.parent_node = &root.base;
    try root.base.child_nodes.append(&child.base);

    // Query for "p"
    var matches = try scopeMatchSelectorsString(allocator, "p", &root);
    defer matches.deinit();

    try testing.expectEqual(@as(usize, 1), matches.items().len);
    try testing.expect(matches.items()[0] == child);
}
test "selectors: scopeMatchSelectorsString with no matches" {
    const allocator = testing.allocator;

    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();

    // Query for "p" (but tree only has div)
    var matches = try scopeMatchSelectorsString(allocator, "p", &root);
    defer matches.deinit();

    try testing.expectEqual(@as(usize, 0), matches.items().len);
}
test "selectors: scopeMatchSelectorsString with syntax error" {
    const allocator = testing.allocator;

    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();

    // Invalid selector should return SyntaxError
    const result = scopeMatchSelectorsString(allocator, ">>", &root);
    try testing.expectError(error.SyntaxError, result);
}
test "selectors: :scope pseudo-class matches scoping root" {
    const allocator = testing.allocator;

    // Create tree: div#root > span > p
    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();
    try root.setId("root");

    var span = try allocator.create(ElementWithBase);
    defer {
        span.deinit();
        allocator.destroy(span);
    }
    span.* = ElementWithBase.init(allocator, "span");

    var p = try allocator.create(ElementWithBase);
    defer {
        p.deinit();
        allocator.destroy(p);
    }
    p.* = ElementWithBase.init(allocator, "p");

    // Link: div > span > p
    span.base.parent_node = &root.base;
    try root.base.child_nodes.append(&span.base);
    p.base.parent_node = &span.base;
    try span.base.child_nodes.append(&p.base);

    // Query for ":scope" - should match the scoping root (div)
    var matches = try scopeMatchSelectorsString(allocator, ":scope", &root);
    defer matches.deinit();

    try testing.expectEqual(@as(usize, 1), matches.items().len);
    try testing.expect(matches.items()[0] == &root);
}
test "selectors: :scope > p matches direct children" {
    const allocator = testing.allocator;

    // Create tree: div#scope > p, span > p
    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();
    try root.setId("scope");

    var p1 = try allocator.create(ElementWithBase);
    defer {
        p1.deinit();
        allocator.destroy(p1);
    }
    p1.* = ElementWithBase.init(allocator, "p");

    var span = try allocator.create(ElementWithBase);
    defer {
        span.deinit();
        allocator.destroy(span);
    }
    span.* = ElementWithBase.init(allocator, "span");

    var p2 = try allocator.create(ElementWithBase);
    defer {
        p2.deinit();
        allocator.destroy(p2);
    }
    p2.* = ElementWithBase.init(allocator, "p");

    // Link: div > p1, div > span > p2
    p1.base.parent_node = &root.base;
    try root.base.child_nodes.append(&p1.base);
    span.base.parent_node = &root.base;
    try root.base.child_nodes.append(&span.base);
    p2.base.parent_node = &span.base;
    try span.base.child_nodes.append(&p2.base);

    // Query for ":scope > p" from root - should match only direct p child
    var matches = try scopeMatchSelectorsString(allocator, ":scope > p", &root);
    defer matches.deinit();

    try testing.expectEqual(@as(usize, 1), matches.items().len);
    try testing.expect(matches.items()[0] == p1);
}