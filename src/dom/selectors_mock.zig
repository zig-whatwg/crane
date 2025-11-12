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

    /// Attribute selectors
    attribute_exists: []const u8, // [attr]
    attribute_equals: struct {
        name: []const u8,
        value: []const u8,
    }, // [attr=value]

    /// Pseudo-classes
    pseudo_first_child, // :first-child
    pseudo_last_child, // :last-child

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

    // Pseudo-class selector: :first-child, :last-child
    if (trimmed[0] == ':') {
        if (std.mem.eql(u8, trimmed, ":first-child")) {
            return Selector.pseudo_first_child;
        }
        if (std.mem.eql(u8, trimmed, ":last-child")) {
            return Selector.pseudo_last_child;
        }
        return Selector{ .parse_error = "Unsupported pseudo-class (mock implementation)" };
    }

    // Attribute selector: [attr] or [attr=value]
    if (trimmed[0] == '[') {
        return parseAttributeSelector(trimmed);
    }

    // Type selector: div, p, span, etc.
    // Very basic validation: starts with ASCII alpha
    if (isAsciiAlpha(trimmed[0])) {
        return Selector{ .type_selector = trimmed };
    }

    // Unsupported selector syntax
    return Selector{ .parse_error = "Unsupported selector syntax (mock implementation)" };
}

/// Parse attribute selector [attr] or [attr=value]
fn parseAttributeSelector(selector: []const u8) Selector {
    if (selector.len < 3) {
        return Selector{ .parse_error = "Invalid attribute selector" };
    }

    if (selector[selector.len - 1] != ']') {
        return Selector{ .parse_error = "Attribute selector must end with ]" };
    }

    // Extract content between brackets
    const content = selector[1 .. selector.len - 1];

    // Look for = sign
    if (std.mem.indexOfScalar(u8, content, '=')) |equals_pos| {
        // [attr=value]
        const attr_name = std.mem.trim(u8, content[0..equals_pos], " \t");
        var value = std.mem.trim(u8, content[equals_pos + 1 ..], " \t");

        // Remove quotes if present
        if (value.len >= 2 and ((value[0] == '"' and value[value.len - 1] == '"') or
            (value[0] == '\'' and value[value.len - 1] == '\'')))
        {
            value = value[1 .. value.len - 1];
        }

        if (attr_name.len == 0) {
            return Selector{ .parse_error = "Empty attribute name" };
        }

        return Selector{ .attribute_equals = .{
            .name = attr_name,
            .value = value,
        } };
    } else {
        // [attr]
        const attr_name = std.mem.trim(u8, content, " \t");
        if (attr_name.len == 0) {
            return Selector{ .parse_error = "Empty attribute name" };
        }
        return Selector{ .attribute_exists = attr_name };
    }
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

    var matches = std.ArrayList(*@TypeOf(root.*)).init(allocator);
    errdefer matches.deinit();

    // Depth-first tree traversal to find matching elements
    try traverseAndMatch(selector, root, &matches);

    return matches;
}

/// Helper function to recursively traverse tree and collect matches
fn traverseAndMatch(
    selector: Selector,
    node: anytype,
    matches: *std.ArrayList(*@TypeOf(node.*)),
) !void {
    // Try to match this node if it's an Element
    // Note: In real implementation, we'd need to check node type
    // For now, assume all nodes could be elements and try to match
    if (matchesSelector(selector, node)) {
        try matches.append(node);
    }

    // Traverse children (assuming node has child_nodes field)
    // In real implementation, would need proper Node interface checking
    if (@hasField(@TypeOf(node.*), "child_nodes")) {
        for (node.child_nodes.items) |child| {
            try traverseAndMatch(selector, child, matches);
        }
    }
}

/// Check if a single element matches the selector
fn matchesSelector(selector: Selector, element: anytype) bool {
    // Type check: Only Element nodes can match selectors
    // For mock, we check if element has the fields we need
    const has_tag_name = @hasField(@TypeOf(element.*), "tag_name");
    const has_id = @hasField(@TypeOf(element.*), "id");
    const has_class_list = @hasField(@TypeOf(element.*), "class_list");

    switch (selector) {
        .universal => {
            // Universal selector matches all elements
            return has_tag_name;
        },
        .type_selector => |tag| {
            // Type selector matches by tag name
            if (!has_tag_name) return false;
            return std.mem.eql(u8, element.tag_name, tag);
        },
        .id_selector => |id| {
            // ID selector matches by id attribute
            if (!has_id) return false;
            if (element.id) |elem_id| {
                return std.mem.eql(u8, elem_id, id);
            }
            return false;
        },
        .class_selector => |class_name| {
            // Class selector matches if element has the class
            if (!has_class_list) return false;
            if (element.class_list) |classes| {
                // Token-based matching: split class list by whitespace and check each token
                return classListContains(classes, class_name);
            }
            return false;
        },
        .attribute_exists => |attr_name| {
            // Attribute exists selector matches if element has the attribute
            // Check for common attributes via fields
            if (std.mem.eql(u8, attr_name, "id")) {
                return has_id and @field(element, "id") != null;
            }
            if (std.mem.eql(u8, attr_name, "class")) {
                return has_class_list and @field(element, "class_list") != null;
            }

            // For other attributes, would need to check element.attributes
            // For now, return false for unknown attributes
            return false;
        },
        .attribute_equals => |attr_spec| {
            // Attribute equals selector matches if element has attribute with specific value
            if (std.mem.eql(u8, attr_spec.name, "id")) {
                if (has_id) {
                    if (@field(element, "id")) |elem_id| {
                        return std.mem.eql(u8, elem_id, attr_spec.value);
                    }
                }
                return false;
            }

            // For other attributes, would need to check element.attributes
            // For now, return false for unknown attributes
            return false;
        },
        .pseudo_first_child => {
            // :first-child matches if element is the first child of its parent
            return isFirstChild(element);
        },
        .pseudo_last_child => {
            // :last-child matches if element is the last child of its parent
            return isLastChild(element);
        },
        .parse_error => {
            // Parse errors don't match anything
            return false;
        },
    }
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

/// Check if a space-separated class list contains a specific token
/// Per HTML spec, class names are separated by ASCII whitespace
fn classListContains(class_list: []const u8, target_class: []const u8) bool {
    var it = std.mem.tokenizeAny(u8, class_list, " \t\n\r\x0c");
    while (it.next()) |token| {
        if (std.mem.eql(u8, token, target_class)) {
            return true;
        }
    }
    return false;
}

/// Check if element is the first child of its parent
fn isFirstChild(element: anytype) bool {
    // Check if element has parent_node field
    if (!@hasField(@TypeOf(element.*), "parent_node")) return false;

    const parent = @field(element, "parent_node") orelse return false;

    // Check if parent has child_nodes
    if (!@hasField(@TypeOf(parent.*), "child_nodes")) return false;

    const children = @field(parent, "child_nodes");
    if (children.items.len == 0) return false;

    // Element is first child if it's the first item in parent's children
    return @intFromPtr(children.items[0]) == @intFromPtr(element);
}

/// Check if element is the last child of its parent
fn isLastChild(element: anytype) bool {
    // Check if element has parent_node field
    if (!@hasField(@TypeOf(element.*), "parent_node")) return false;

    const parent = @field(element, "parent_node") orelse return false;

    // Check if parent has child_nodes
    if (!@hasField(@TypeOf(parent.*), "child_nodes")) return false;

    const children = @field(parent, "child_nodes");
    if (children.items.len == 0) return false;

    // Element is last child if it's the last item in parent's children
    return @intFromPtr(children.items[children.items.len - 1]) == @intFromPtr(element);
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

// NOTE: More comprehensive tests for matchSelectorAgainstTree would require
// actual DOM Node/Element types. The parsing tests above validate the core
// selector parsing logic. The matching logic can be tested via integration
// tests with real DOM elements in tests/dom/element_test.zig

test "Selectors mock - classListContains with tokens" {
    // Single class
    try testing.expect(classListContains("myClass", "myClass"));

    // Multiple classes
    try testing.expect(classListContains("myClass otherClass", "myClass"));
    try testing.expect(classListContains("myClass otherClass", "otherClass"));

    // Class not present
    try testing.expect(!classListContains("myClass otherClass", "notThere"));

    // Partial match should not match (token-based, not substring)
    try testing.expect(!classListContains("myClassExtended", "myClass"));

    // Multiple spaces
    try testing.expect(classListContains("myClass  otherClass", "myClass"));

    // Leading/trailing whitespace
    try testing.expect(classListContains("  myClass  ", "myClass"));

    // Tab/newline separators
    try testing.expect(classListContains("myClass\totherClass", "otherClass"));
    try testing.expect(classListContains("myClass\notherClass", "otherClass"));
}

test "Selectors mock - parse attribute exists selector" {
    const selector = try parseSelector(testing.allocator, "[href]");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .attribute_exists), @as(std.meta.Tag(Selector), selector));
    try testing.expectEqualStrings("href", selector.attribute_exists);
}

test "Selectors mock - parse attribute equals selector" {
    const selector1 = try parseSelector(testing.allocator, "[type=text]");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .attribute_equals), @as(std.meta.Tag(Selector), selector1));
    try testing.expectEqualStrings("type", selector1.attribute_equals.name);
    try testing.expectEqualStrings("text", selector1.attribute_equals.value);

    // With quotes
    const selector2 = try parseSelector(testing.allocator, "[type=\"text\"]");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .attribute_equals), @as(std.meta.Tag(Selector), selector2));
    try testing.expectEqualStrings("type", selector2.attribute_equals.name);
    try testing.expectEqualStrings("text", selector2.attribute_equals.value);

    // With spaces
    const selector3 = try parseSelector(testing.allocator, "[ type = text ]");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .attribute_equals), @as(std.meta.Tag(Selector), selector3));
    try testing.expectEqualStrings("type", selector3.attribute_equals.name);
    try testing.expectEqualStrings("text", selector3.attribute_equals.value);
}

test "Selectors mock - parse error on malformed attribute selector" {
    const selector1 = try parseSelector(testing.allocator, "[");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .parse_error), @as(std.meta.Tag(Selector), selector1));

    const selector2 = try parseSelector(testing.allocator, "[]");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .parse_error), @as(std.meta.Tag(Selector), selector2));
}

test "Selectors mock - parse pseudo-class :first-child" {
    const selector = try parseSelector(testing.allocator, ":first-child");
    try testing.expectEqual(Selector.pseudo_first_child, selector);
}

test "Selectors mock - parse pseudo-class :last-child" {
    const selector = try parseSelector(testing.allocator, ":last-child");
    try testing.expectEqual(Selector.pseudo_last_child, selector);
}

test "Selectors mock - parse error on unsupported pseudo-class" {
    const selector = try parseSelector(testing.allocator, ":hover");
    try testing.expectEqual(@as(std.meta.Tag(Selector), .parse_error), @as(std.meta.Tag(Selector), selector));
}
