//! HTML Mock - Minimal HTML functionality needed for DOM
//!
//! This module provides basic HTML-related functionality needed by DOM
//! without implementing the full HTML specification.
//!
//! Currently provides:
//! - Class name parsing for getElementsByClassName

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;

/// Ordered set parser per DOM §3.1
/// Takes a string input and returns an ordered set of tokens.
/// Used for parsing space-separated class names.
///
/// Algorithm:
/// 1. Let inputTokens be the result of splitting input on ASCII whitespace
/// 2. Let tokens be a new ordered set
/// 3. For each token of inputTokens, append token to tokens
/// 4. Return tokens
///
/// Spec: https://dom.spec.whatwg.org/#ordered-sets
pub fn parseOrderedSet(allocator: Allocator, input: []const u8) !infra.List([]const u8) {
    var tokens = infra.List([]const u8).init(allocator);
    errdefer tokens.deinit();

    // Step 1: Split input on ASCII whitespace
    var iter = std.mem.tokenizeAny(u8, input, " \t\n\r\x0C"); // ASCII whitespace

    // Steps 2-3: For each token, append to ordered set (no duplicates)
    while (iter.next()) |token| {
        // Check if already in set (to maintain "ordered set" property)
        var already_exists = false;
        for (tokens.items()) |existing| {
            if (std.mem.eql(u8, existing, token)) {
                already_exists = true;
                break;
            }
        }

        if (!already_exists) {
            try tokens.append(token);
        }
    }

    // Step 4: Return tokens
    return tokens;
}

/// Check if an element has all classes in the given set
/// Used by getElementsByClassName to filter elements
///
/// classNames: Space-separated class names to check for
/// elementClass: The element's class attribute value
/// quirksMode: If true, use ASCII case-insensitive comparison
pub fn hasAllClasses(
    allocator: Allocator,
    classNames: []const u8,
    elementClass: []const u8,
    quirksMode: bool,
) !bool {
    // Parse both class lists
    var required_classes = try parseOrderedSet(allocator, classNames);
    defer required_classes.deinit();

    var element_classes = try parseOrderedSet(allocator, elementClass);
    defer element_classes.deinit();

    // Check if element has all required classes
    for (required_classes.items()) |required| {
        var found = false;
        for (element_classes.items()) |elem_class| {
            const matches = if (quirksMode)
                std.ascii.eqlIgnoreCase(required, elem_class)
            else
                std.mem.eql(u8, required, elem_class);

            if (matches) {
                found = true;
                break;
            }
        }

        if (!found) return false;
    }

    return true;
}

// ============================================================================
// Tests
// ============================================================================

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
