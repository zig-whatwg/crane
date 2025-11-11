// ⚠️ TEMPORARY MOCK: Selectors Level 4 Stub Implementation
// https://drafts.csswg.org/selectors-4/
//
// EXTERNAL SPEC DEPENDENCY: Full Selectors Level 4 implementation required
// TODO(bd-issue): Track in bd for backfill with complete Selectors spec
//
// This is a minimal mock to unblock DOM ParentNode mixin implementation.
// Provides basic selector matching for:
// - Universal selector: *
// - Type selector: div, p, span
// - ID selector: #myId
// - Class selector: .myClass
//
// NOT IMPLEMENTED (requires full Selectors spec):
// - Attribute selectors: [attr], [attr=value]
// - Pseudo-classes: :hover, :first-child, :nth-child()
// - Pseudo-elements: ::before, ::after
// - Combinators: descendant, child (>), sibling (~, +)
// - Complex selectors: :not(), :is(), :where()
// - And ~60 other Selectors Level 4 features

const std = @import("std");

/// Selector parse result
pub const Selector = union(enum) {
    universal, // *
    type_selector: []const u8, // div, p, span
    id_selector: []const u8, // #myId
    class_selector: []const u8, // .myClass

    /// Parse error - invalid selector syntax
    parse_error: []const u8,
};

/// DOM §3.4 - parse a selector
/// Spec: https://drafts.csswg.org/selectors-4/#parse-a-selector
///
/// MOCK IMPLEMENTATION - Only handles basic selectors
///
/// Returns:
/// - Selector on success
/// - Selector.parse_error on failure
pub fn parseSelector(allocator: std.mem.Allocator, selectors: []const u8) !Selector {
    _ = allocator;

    if (selectors.len == 0) {
        return Selector{ .parse_error = "Empty selector string" };
    }

    // Trim whitespace
    const trimmed = std.mem.trim(u8, selectors, " \t\n\r");

    if (trimmed.len == 0) {
        return Selector{ .parse_error = "Empty selector after trim" };
    }

    // Universal selector: *
    if (std.mem.eql(u8, trimmed, "*")) {
        return Selector.universal;
    }

    // ID selector: #myId
    if (trimmed[0] == '#') {
        if (trimmed.len == 1) {
            return Selector{ .parse_error = "Empty ID selector" };
        }
        return Selector{ .id_selector = trimmed[1..] };
    }

    // Class selector: .myClass
    if (trimmed[0] == '.') {
        if (trimmed.len == 1) {
            return Selector{ .parse_error = "Empty class selector" };
        }
        return Selector{ .class_selector = trimmed[1..] };
    }

    // Type selector: div, p, span, etc.
    // Very basic validation: starts with ASCII alpha
    if (isAsciiAlpha(trimmed[0])) {
        return Selector{ .type_selector = trimmed };
    }

    // Unsupported selector syntax
    return Selector{ .parse_error = "Unsupported selector syntax (mock implementation)" };
}

/// DOM §3.4 - match a selector against a tree
/// Spec: https://drafts.csswg.org/selectors-4/#match-a-selector-against-a-tree
///
/// MOCK IMPLEMENTATION - Only handles basic matching
///
/// Given:
/// - selector: Parsed selector
/// - root: Root of tree to search
/// - scoping_root: Scoping root for :scope pseudo-class (ignored in mock)
///
/// Returns list of matching elements (in tree order)
pub fn matchSelectorAgainstTree(
    allocator: std.mem.Allocator,
    selector: Selector,
    root: anytype,
    scoping_root: anytype,
) !std.ArrayList(*@TypeOf(root.*)) {
    _ = scoping_root; // Ignored in mock - :scope not implemented

    const matches = std.ArrayList(*@TypeOf(root.*)).init(allocator);

    // TODO: Implement tree traversal and matching
    // For now, return empty list
    _ = selector;

    return matches;
}

/// DOM §3.4 - scope-match a selectors string
/// Spec: https://dom.spec.whatwg.org/#scope-match-a-selectors-string
///
/// MOCK IMPLEMENTATION
///
/// Steps:
/// 1. Let s be the result of parse a selector selectors.
/// 2. If s is failure, throw SyntaxError DOMException.
/// 3. Return the result of match a selector against a tree with s and node's root
///    using scoping root node.
pub fn scopeMatchSelectorsString(
    allocator: std.mem.Allocator,
    selectors: []const u8,
    node: anytype,
) !std.ArrayList(*@TypeOf(node.*)) {
    // Step 1: Parse selector
    const selector = try parseSelector(allocator, selectors);

    // Step 2: If parse error, throw SyntaxError
    if (selector == .parse_error) {
        return error.SyntaxError;
    }

    // Step 3: Match against tree
    // TODO: Get node's root
    // TODO: Implement proper tree matching
    // For now, return empty list
    const matches = std.ArrayList(*@TypeOf(node.*)).init(allocator);
    return matches;
}

fn isAsciiAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "Selectors mock - parse universal selector" {
    const selector = try parseSelector(testing.allocator, "*");
    try testing.expectEqual(Selector.universal, selector);
}

test "Selectors mock - parse type selector" {
    const selector = try parseSelector(testing.allocator, "div");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .type_selector), @as(std.meta.Tag(Selector), selector));
    try testing.expectEqualStrings("div", selector.type_selector);
}

test "Selectors mock - parse ID selector" {
    const selector = try parseSelector(testing.allocator, "#myId");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .id_selector), @as(std.meta.Tag(Selector), selector));
    try testing.expectEqualStrings("myId", selector.id_selector);
}

test "Selectors mock - parse class selector" {
    const selector = try parseSelector(testing.allocator, ".myClass");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .class_selector), @as(std.meta.Tag(Selector), selector));
    try testing.expectEqualStrings("myClass", selector.class_selector);
}

test "Selectors mock - parse error on empty string" {
    const selector = try parseSelector(testing.allocator, "");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .parse_error), @as(std.meta.Tag(Selector), selector));
}

test "Selectors mock - parse error on whitespace-only" {
    const selector = try parseSelector(testing.allocator, "   ");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .parse_error), @as(std.meta.Tag(Selector), selector));
}

test "Selectors mock - parse error on empty ID" {
    const selector = try parseSelector(testing.allocator, "#");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .parse_error), @as(std.meta.Tag(Selector), selector));
}

test "Selectors mock - parse error on empty class" {
    const selector = try parseSelector(testing.allocator, ".");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .parse_error), @as(std.meta.Tag(Selector), selector));
}
