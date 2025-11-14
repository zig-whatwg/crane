//! Tests migrated from src/dom/html_mock.zig
//! Per WHATWG specifications

const std = @import("std");

const dom = @import("dom");

test "parseOrderedSet - single class" {
    const allocator = std.testing.allocator;

    var result = try parseOrderedSet(allocator, "foo");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.size());
    try std.testing.expectEqualStrings("foo", result.get(0).?);
}
test "parseOrderedSet - multiple classes" {
    const allocator = std.testing.allocator;

    var result = try parseOrderedSet(allocator, "foo bar baz");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.size());
    try std.testing.expectEqualStrings("foo", result.get(0).?);
    try std.testing.expectEqualStrings("bar", result.get(1).?);
    try std.testing.expectEqualStrings("baz", result.get(2).?);
}
test "parseOrderedSet - removes duplicates" {
    const allocator = std.testing.allocator;

    var result = try parseOrderedSet(allocator, "foo bar foo baz bar");
    defer result.deinit();

    // Should only have 3 unique tokens in order
    try std.testing.expectEqual(@as(usize, 3), result.size());
    try std.testing.expectEqualStrings("foo", result.get(0).?);
    try std.testing.expectEqualStrings("bar", result.get(1).?);
    try std.testing.expectEqualStrings("baz", result.get(2).?);
}
test "parseOrderedSet - multiple whitespace types" {
    const allocator = std.testing.allocator;

    var result = try parseOrderedSet(allocator, "foo\t\tbar\n\nbaz\r\nqux");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 4), result.size());
    try std.testing.expectEqualStrings("foo", result.get(0).?);
    try std.testing.expectEqualStrings("bar", result.get(1).?);
    try std.testing.expectEqualStrings("baz", result.get(2).?);
    try std.testing.expectEqualStrings("qux", result.get(3).?);
}
test "parseOrderedSet - leading and trailing whitespace" {
    const allocator = std.testing.allocator;

    var result = try parseOrderedSet(allocator, "  foo  bar  ");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.size());
    try std.testing.expectEqualStrings("foo", result.get(0).?);
    try std.testing.expectEqualStrings("bar", result.get(1).?);
}
test "parseOrderedSet - empty string" {
    const allocator = std.testing.allocator;

    var result = try parseOrderedSet(allocator, "");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.size());
}
test "parseOrderedSet - only whitespace" {
    const allocator = std.testing.allocator;

    var result = try parseOrderedSet(allocator, "   \t\n  ");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.size());
}
test "hasAllClasses - single class match" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try hasAllClasses(allocator, "foo", "foo bar", false));
}
test "hasAllClasses - multiple class match" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try hasAllClasses(allocator, "foo bar", "foo bar baz", false));
}
test "hasAllClasses - no match" {
    const allocator = std.testing.allocator;

    try std.testing.expect(!try hasAllClasses(allocator, "foo bar", "foo baz", false));
}
test "hasAllClasses - order doesn't matter" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try hasAllClasses(allocator, "bar foo", "foo bar baz", false));
}
test "hasAllClasses - quirks mode case insensitive" {
    const allocator = std.testing.allocator;

    try std.testing.expect(try hasAllClasses(allocator, "FOO Bar", "foo bar baz", true));
}
test "hasAllClasses - standards mode case sensitive" {
    const allocator = std.testing.allocator;

    try std.testing.expect(!try hasAllClasses(allocator, "FOO", "foo bar", false));
    try std.testing.expect(try hasAllClasses(allocator, "foo", "foo bar", false));
}
test "hasAllClasses - empty required classes" {
    const allocator = std.testing.allocator;

    // Empty required classes should match any element
    try std.testing.expect(try hasAllClasses(allocator, "", "foo bar", false));
}
test "hasAllClasses - empty element classes" {
    const allocator = std.testing.allocator;

    // Element with no classes should not match if classes are required
    try std.testing.expect(!try hasAllClasses(allocator, "foo", "", false));

    // But should match if no classes are required
    try std.testing.expect(try hasAllClasses(allocator, "", "", false));
}