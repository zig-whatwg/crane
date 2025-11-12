//! Selectors Level 4 Integration for DOM
//!
//! Provides integration between DOM querySelector APIs and the Selectors Level 4 implementation.
//!
//! This module implements the DOM spec's selector matching algorithms:
//! - scope-match a selectors string: https://dom.spec.whatwg.org/#scope-match-a-selectors-string
//! - match a selector against a tree: https://drafts.csswg.org/selectors-4/#match-a-selector-against-a-tree
//!
//! Used by ParentNode mixin (querySelector, querySelectorAll) and Element.matches()

const std = @import("std");
const selector_mod = @import("selector");
const Tokenizer = selector_mod.Tokenizer;
const Parser = selector_mod.Parser;
const SelectorList = selector_mod.SelectorList;
const Matcher = selector_mod.Matcher;

// DOM types
const ElementWithBase = @import("element_with_base.zig").ElementWithBase;
const NodeBase = @import("node_base.zig").NodeBase;

/// DOM §1.3 - scope-match a selectors string
/// Spec: https://dom.spec.whatwg.org/#scope-match-a-selectors-string
///
/// Steps:
/// 1. Let s be the result of parse a selector selectors.
/// 2. If s is failure, throw SyntaxError DOMException.
/// 3. Return the result of match a selector against a tree with s and node's root
///    using scoping root node.
///
/// Returns:
/// - ArrayList of matching elements (in tree order)
/// - error.SyntaxError if parsing fails
pub fn scopeMatchSelectorsString(
    allocator: std.mem.Allocator,
    selectors: []const u8,
    node: anytype,
) !std.ArrayList(*ElementWithBase) {
    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Step 3: Match against tree using node as scoping root
    // Get the root of the tree (walk up to find root)
    const root = getRoot(node);

    return matchSelectorAgainstTree(allocator, &selector_list, root, node);
}

/// Get the root of a node's tree
fn getRoot(node: anytype) *NodeBase {
    const node_base = getNodeBase(node);
    var current = node_base;
    while (current.parent_node) |parent| {
        current = parent;
    }
    return current;
}

/// Get NodeBase from various node types
fn getNodeBase(node: anytype) *NodeBase {
    const T = @TypeOf(node.*);

    // If it's already NodeBase, return it
    if (T == NodeBase) {
        return node;
    }

    // If it has a 'base' field (like ElementWithBase), return that
    if (@hasField(T, "base")) {
        return &node.base;
    }

    // Otherwise assume it has prototype/base at the start
    return @ptrCast(node);
}

/// Match a selector against a tree
/// Returns all matching elements in tree order
fn matchSelectorAgainstTree(
    allocator: std.mem.Allocator,
    selector_list: *const SelectorList,
    root: *NodeBase,
    scoping_root: anytype,
) !std.ArrayList(*ElementWithBase) {
    _ = scoping_root; // TODO: Use for :scope pseudo-class

    var matches: std.ArrayList(*ElementWithBase) = .empty;
    errdefer matches.deinit(allocator);

    const matcher = Matcher.init(allocator);

    // Traverse tree in depth-first order
    try traverseAndMatch(allocator, &matcher, selector_list, root, &matches);

    return matches;
}

/// Recursively traverse tree and collect matching elements
fn traverseAndMatch(
    allocator: std.mem.Allocator,
    matcher: *const Matcher,
    selector_list: *const SelectorList,
    node: *NodeBase,
    matches: *std.ArrayList(*ElementWithBase),
) !void {
    // Check if this node is an element and matches
    if (node.node_type == NodeBase.ELEMENT_NODE) {
        const element: *ElementWithBase = @ptrCast(node);
        if (try matcher.matches(element, selector_list)) {
            try matches.append(allocator, element);
        }
    }

    // Traverse children
    for (0..node.child_nodes.size()) |i| {
        if (node.child_nodes.get(i)) |child| {
            try traverseAndMatch(allocator, matcher, selector_list, child, matches);
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

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
    defer matches.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), matches.items.len);
    try testing.expect(matches.items[0] == child);
}

test "selectors: scopeMatchSelectorsString with no matches" {
    const allocator = testing.allocator;

    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();

    // Query for "p" (but tree only has div)
    var matches = try scopeMatchSelectorsString(allocator, "p", &root);
    defer matches.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), matches.items.len);
}

test "selectors: scopeMatchSelectorsString with syntax error" {
    const allocator = testing.allocator;

    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();

    // Invalid selector should return SyntaxError
    const result = scopeMatchSelectorsString(allocator, ">>", &root);
    try testing.expectError(error.SyntaxError, result);
}
