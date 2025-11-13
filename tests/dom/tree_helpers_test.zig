//! Tests for DOM tree helper utilities
//! Covers tree navigation, relationship queries, and traversal

const std = @import("std");
const dom = @import("dom");
const tree_helpers = dom.tree_helpers;
const Node = dom.Node;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

/// Helper to create a test tree:
///       root
///      /  |  \
///     a   b   c
///    / \      |
///   d   e     f
fn createTestTree(allocator: std.mem.Allocator) !struct {
    root: *Node,
    a: *Node,
    b: *Node,
    c: *Node,
    d: *Node,
    e: *Node,
    f: *Node,
} {
    // Create nodes
    const root = try allocator.create(Node);
    root.* = try Node.init(allocator, Node.ELEMENT_NODE, "root");

    const a = try allocator.create(Node);
    a.* = try Node.init(allocator, Node.ELEMENT_NODE, "a");

    const b = try allocator.create(Node);
    b.* = try Node.init(allocator, Node.ELEMENT_NODE, "b");

    const c = try allocator.create(Node);
    c.* = try Node.init(allocator, Node.ELEMENT_NODE, "c");

    const d = try allocator.create(Node);
    d.* = try Node.init(allocator, Node.ELEMENT_NODE, "d");

    const e = try allocator.create(Node);
    e.* = try Node.init(allocator, Node.ELEMENT_NODE, "e");

    const f = try allocator.create(Node);
    f.* = try Node.init(allocator, Node.ELEMENT_NODE, "f");

    // Build tree structure
    _ = try root.call_appendChild(a);
    _ = try root.call_appendChild(b);
    _ = try root.call_appendChild(c);
    _ = try a.call_appendChild(d);
    _ = try a.call_appendChild(e);
    _ = try c.call_appendChild(f);

    return .{
        .root = root,
        .a = a,
        .b = b,
        .c = c,
        .d = d,
        .e = e,
        .f = f,
    };
}

fn destroyTestTree(tree: anytype) void {
    // Clean up nodes
    tree.f.deinit();
    tree.f.allocator.destroy(tree.f);

    tree.e.deinit();
    tree.e.allocator.destroy(tree.e);

    tree.d.deinit();
    tree.d.allocator.destroy(tree.d);

    tree.c.deinit();
    tree.c.allocator.destroy(tree.c);

    tree.b.deinit();
    tree.b.allocator.destroy(tree.b);

    tree.a.deinit();
    tree.a.allocator.destroy(tree.a);

    tree.root.deinit();
    tree.root.allocator.destroy(tree.root);
}

// ============================================================================
// Tree Navigation Tests
// ============================================================================

test "tree_helpers - getParentNode" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.getParentNode(tree.root) == null);
    try expect(tree_helpers.getParentNode(tree.a) == tree.root);
    try expect(tree_helpers.getParentNode(tree.b) == tree.root);
    try expect(tree_helpers.getParentNode(tree.c) == tree.root);
    try expect(tree_helpers.getParentNode(tree.d) == tree.a);
    try expect(tree_helpers.getParentNode(tree.e) == tree.a);
    try expect(tree_helpers.getParentNode(tree.f) == tree.c);
}

test "tree_helpers - getFirstChild" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.getFirstChild(tree.root) == tree.a);
    try expect(tree_helpers.getFirstChild(tree.a) == tree.d);
    try expect(tree_helpers.getFirstChild(tree.b) == null); // No children
    try expect(tree_helpers.getFirstChild(tree.c) == tree.f);
    try expect(tree_helpers.getFirstChild(tree.d) == null); // Leaf
}

test "tree_helpers - getLastChild" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.getLastChild(tree.root) == tree.c);
    try expect(tree_helpers.getLastChild(tree.a) == tree.e);
    try expect(tree_helpers.getLastChild(tree.b) == null); // No children
    try expect(tree_helpers.getLastChild(tree.c) == tree.f);
    try expect(tree_helpers.getLastChild(tree.d) == null); // Leaf
}

test "tree_helpers - getNextSibling" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.getNextSibling(tree.root) == null); // Root has no siblings
    try expect(tree_helpers.getNextSibling(tree.a) == tree.b);
    try expect(tree_helpers.getNextSibling(tree.b) == tree.c);
    try expect(tree_helpers.getNextSibling(tree.c) == null); // Last child
    try expect(tree_helpers.getNextSibling(tree.d) == tree.e);
    try expect(tree_helpers.getNextSibling(tree.e) == null);
    try expect(tree_helpers.getNextSibling(tree.f) == null);
}

test "tree_helpers - getPreviousSibling" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.getPreviousSibling(tree.root) == null); // Root has no siblings
    try expect(tree_helpers.getPreviousSibling(tree.a) == null); // First child
    try expect(tree_helpers.getPreviousSibling(tree.b) == tree.a);
    try expect(tree_helpers.getPreviousSibling(tree.c) == tree.b);
    try expect(tree_helpers.getPreviousSibling(tree.d) == null);
    try expect(tree_helpers.getPreviousSibling(tree.e) == tree.d);
    try expect(tree_helpers.getPreviousSibling(tree.f) == null);
}

test "tree_helpers - getChildCount" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expectEqual(@as(usize, 3), tree_helpers.getChildCount(tree.root));
    try expectEqual(@as(usize, 2), tree_helpers.getChildCount(tree.a));
    try expectEqual(@as(usize, 0), tree_helpers.getChildCount(tree.b));
    try expectEqual(@as(usize, 1), tree_helpers.getChildCount(tree.c));
    try expectEqual(@as(usize, 0), tree_helpers.getChildCount(tree.d));
}

test "tree_helpers - getChildAt" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.getChildAt(tree.root, 0) == tree.a);
    try expect(tree_helpers.getChildAt(tree.root, 1) == tree.b);
    try expect(tree_helpers.getChildAt(tree.root, 2) == tree.c);
    try expect(tree_helpers.getChildAt(tree.root, 3) == null); // Out of bounds

    try expect(tree_helpers.getChildAt(tree.a, 0) == tree.d);
    try expect(tree_helpers.getChildAt(tree.a, 1) == tree.e);
    try expect(tree_helpers.getChildAt(tree.a, 2) == null);

    try expect(tree_helpers.getChildAt(tree.b, 0) == null); // No children
}

test "tree_helpers - getChildIndex" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expectEqual(@as(?usize, 0), tree_helpers.getChildIndex(tree.root, tree.a));
    try expectEqual(@as(?usize, 1), tree_helpers.getChildIndex(tree.root, tree.b));
    try expectEqual(@as(?usize, 2), tree_helpers.getChildIndex(tree.root, tree.c));
    try expectEqual(@as(?usize, null), tree_helpers.getChildIndex(tree.root, tree.d)); // Not direct child

    try expectEqual(@as(?usize, 0), tree_helpers.getChildIndex(tree.a, tree.d));
    try expectEqual(@as(?usize, 1), tree_helpers.getChildIndex(tree.a, tree.e));
}

// ============================================================================
// Tree Relationship Tests
// ============================================================================

test "tree_helpers - isInclusiveDescendant" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Self is inclusive descendant
    try expect(tree_helpers.isInclusiveDescendant(tree.root, tree.root));
    try expect(tree_helpers.isInclusiveDescendant(tree.a, tree.a));

    // Direct children
    try expect(tree_helpers.isInclusiveDescendant(tree.root, tree.a));
    try expect(tree_helpers.isInclusiveDescendant(tree.root, tree.b));
    try expect(tree_helpers.isInclusiveDescendant(tree.root, tree.c));

    // Grandchildren
    try expect(tree_helpers.isInclusiveDescendant(tree.root, tree.d));
    try expect(tree_helpers.isInclusiveDescendant(tree.root, tree.e));
    try expect(tree_helpers.isInclusiveDescendant(tree.root, tree.f));

    try expect(tree_helpers.isInclusiveDescendant(tree.a, tree.d));
    try expect(tree_helpers.isInclusiveDescendant(tree.a, tree.e));

    // Not descendants
    try expect(!tree_helpers.isInclusiveDescendant(tree.a, tree.root));
    try expect(!tree_helpers.isInclusiveDescendant(tree.a, tree.b));
    try expect(!tree_helpers.isInclusiveDescendant(tree.d, tree.e));
}

test "tree_helpers - isDescendant" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Self is NOT descendant (only inclusive descendant)
    try expect(!tree_helpers.isDescendant(tree.root, tree.root));
    try expect(!tree_helpers.isDescendant(tree.a, tree.a));

    // Direct children are descendants
    try expect(tree_helpers.isDescendant(tree.root, tree.a));
    try expect(tree_helpers.isDescendant(tree.root, tree.b));

    // Grandchildren are descendants
    try expect(tree_helpers.isDescendant(tree.root, tree.d));
    try expect(tree_helpers.isDescendant(tree.a, tree.d));

    // Not descendants
    try expect(!tree_helpers.isDescendant(tree.a, tree.root));
    try expect(!tree_helpers.isDescendant(tree.d, tree.e));
}

test "tree_helpers - isInclusiveAncestor" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Self is inclusive ancestor
    try expect(tree_helpers.isInclusiveAncestor(tree.root, tree.root));
    try expect(tree_helpers.isInclusiveAncestor(tree.a, tree.a));

    // Parents are ancestors
    try expect(tree_helpers.isInclusiveAncestor(tree.root, tree.a));
    try expect(tree_helpers.isInclusiveAncestor(tree.a, tree.d));

    // Grandparents are ancestors
    try expect(tree_helpers.isInclusiveAncestor(tree.root, tree.d));
    try expect(tree_helpers.isInclusiveAncestor(tree.root, tree.f));

    // Not ancestors
    try expect(!tree_helpers.isInclusiveAncestor(tree.a, tree.root));
    try expect(!tree_helpers.isInclusiveAncestor(tree.d, tree.a));
}

test "tree_helpers - isAncestor" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Self is NOT ancestor
    try expect(!tree_helpers.isAncestor(tree.root, tree.root));
    try expect(!tree_helpers.isAncestor(tree.a, tree.a));

    // Parents are ancestors
    try expect(tree_helpers.isAncestor(tree.root, tree.a));
    try expect(tree_helpers.isAncestor(tree.a, tree.d));

    // Not ancestors
    try expect(!tree_helpers.isAncestor(tree.a, tree.root));
}

test "tree_helpers - areSiblings" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Siblings
    try expect(tree_helpers.areSiblings(tree.a, tree.b));
    try expect(tree_helpers.areSiblings(tree.b, tree.c));
    try expect(tree_helpers.areSiblings(tree.a, tree.c));
    try expect(tree_helpers.areSiblings(tree.d, tree.e));

    // Not siblings
    try expect(!tree_helpers.areSiblings(tree.root, tree.a)); // Parent-child
    try expect(!tree_helpers.areSiblings(tree.d, tree.f)); // Different parents
    try expect(!tree_helpers.areSiblings(tree.a, tree.d)); // Parent-child
}

test "tree_helpers - hasChildren" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.hasChildren(tree.root));
    try expect(tree_helpers.hasChildren(tree.a));
    try expect(!tree_helpers.hasChildren(tree.b));
    try expect(tree_helpers.hasChildren(tree.c));
    try expect(!tree_helpers.hasChildren(tree.d));
    try expect(!tree_helpers.hasChildren(tree.e));
    try expect(!tree_helpers.hasChildren(tree.f));
}

test "tree_helpers - isRoot" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(tree_helpers.isRoot(tree.root));
    try expect(!tree_helpers.isRoot(tree.a));
    try expect(!tree_helpers.isRoot(tree.d));
}

test "tree_helpers - isLeaf" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expect(!tree_helpers.isLeaf(tree.root));
    try expect(!tree_helpers.isLeaf(tree.a));
    try expect(tree_helpers.isLeaf(tree.b));
    try expect(!tree_helpers.isLeaf(tree.c));
    try expect(tree_helpers.isLeaf(tree.d));
    try expect(tree_helpers.isLeaf(tree.e));
    try expect(tree_helpers.isLeaf(tree.f));
}

// ============================================================================
// Tree Traversal Tests
// ============================================================================

test "tree_helpers - getNextInPreOrder" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Pre-order: root -> a -> d -> e -> b -> c -> f
    try expect(tree_helpers.getNextInPreOrder(tree.root) == tree.a);
    try expect(tree_helpers.getNextInPreOrder(tree.a) == tree.d);
    try expect(tree_helpers.getNextInPreOrder(tree.d) == tree.e);
    try expect(tree_helpers.getNextInPreOrder(tree.e) == tree.b);
    try expect(tree_helpers.getNextInPreOrder(tree.b) == tree.c);
    try expect(tree_helpers.getNextInPreOrder(tree.c) == tree.f);
    try expect(tree_helpers.getNextInPreOrder(tree.f) == null);
}

test "tree_helpers - getPreviousInPreOrder" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Reverse pre-order: f -> c -> b -> e -> d -> a -> root
    try expect(tree_helpers.getPreviousInPreOrder(tree.f) == tree.c);
    try expect(tree_helpers.getPreviousInPreOrder(tree.c) == tree.b);
    try expect(tree_helpers.getPreviousInPreOrder(tree.b) == tree.a);
    try expect(tree_helpers.getPreviousInPreOrder(tree.e) == tree.d);
    try expect(tree_helpers.getPreviousInPreOrder(tree.d) == tree.a);
    try expect(tree_helpers.getPreviousInPreOrder(tree.a) == tree.root);
    try expect(tree_helpers.getPreviousInPreOrder(tree.root) == null);
}

// ============================================================================
// Text Content Tests
// ============================================================================

test "tree_helpers - getDescendantTextContent" {
    const allocator = std.testing.allocator;

    // Create tree with text nodes
    const root = try allocator.create(Node);
    root.* = try Node.init(allocator, Node.ELEMENT_NODE, "div");

    const text1 = try allocator.create(Node);
    text1.* = try Node.init(allocator, Node.TEXT_NODE, "Hello ");

    const text2 = try allocator.create(Node);
    text2.* = try Node.init(allocator, Node.TEXT_NODE, "World");

    _ = try root.call_appendChild(text1);
    _ = try root.call_appendChild(text2);

    // Get text content
    const content = try tree_helpers.getDescendantTextContent(root, allocator);
    defer allocator.free(content);

    try expectEqualStrings("Hello World", content);

    // Clean up
    text2.deinit();
    allocator.destroy(text2);
    text1.deinit();
    allocator.destroy(text1);
    root.deinit();
    allocator.destroy(root);
}

test "tree_helpers - getDescendantTextContent empty" {
    const allocator = std.testing.allocator;

    const root = try allocator.create(Node);
    root.* = try Node.init(allocator, Node.ELEMENT_NODE, "div");

    const content = try tree_helpers.getDescendantTextContent(root, allocator);
    defer allocator.free(content);

    try expectEqualStrings("", content);

    root.deinit();
    allocator.destroy(root);
}

test "tree_helpers - getDescendantTextContent nested" {
    const allocator = std.testing.allocator;

    // <div><span>Hello</span> <span>World</span></div>
    const div = try allocator.create(Node);
    div.* = try Node.init(allocator, Node.ELEMENT_NODE, "div");

    const span1 = try allocator.create(Node);
    span1.* = try Node.init(allocator, Node.ELEMENT_NODE, "span");

    const text1 = try allocator.create(Node);
    text1.* = try Node.init(allocator, Node.TEXT_NODE, "Hello");

    const text2 = try allocator.create(Node);
    text2.* = try Node.init(allocator, Node.TEXT_NODE, " ");

    const span2 = try allocator.create(Node);
    span2.* = try Node.init(allocator, Node.ELEMENT_NODE, "span");

    const text3 = try allocator.create(Node);
    text3.* = try Node.init(allocator, Node.TEXT_NODE, "World");

    _ = try span1.call_appendChild(text1);
    _ = try div.call_appendChild(span1);
    _ = try div.call_appendChild(text2);
    _ = try span2.call_appendChild(text3);
    _ = try div.call_appendChild(span2);

    const content = try tree_helpers.getDescendantTextContent(div, allocator);
    defer allocator.free(content);

    try expectEqualStrings("Hello World", content);

    // Clean up
    text3.deinit();
    allocator.destroy(text3);
    span2.deinit();
    allocator.destroy(span2);
    text2.deinit();
    allocator.destroy(text2);
    text1.deinit();
    allocator.destroy(text1);
    span1.deinit();
    allocator.destroy(span1);
    div.deinit();
    allocator.destroy(div);
}

// ============================================================================
// Tree Metrics Tests
// ============================================================================

test "tree_helpers - getDepth" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expectEqual(@as(usize, 0), tree_helpers.getDepth(tree.root));
    try expectEqual(@as(usize, 1), tree_helpers.getDepth(tree.a));
    try expectEqual(@as(usize, 1), tree_helpers.getDepth(tree.b));
    try expectEqual(@as(usize, 1), tree_helpers.getDepth(tree.c));
    try expectEqual(@as(usize, 2), tree_helpers.getDepth(tree.d));
    try expectEqual(@as(usize, 2), tree_helpers.getDepth(tree.e));
    try expectEqual(@as(usize, 2), tree_helpers.getDepth(tree.f));
}

test "tree_helpers - getHeight" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expectEqual(@as(usize, 2), tree_helpers.getHeight(tree.root));
    try expectEqual(@as(usize, 1), tree_helpers.getHeight(tree.a));
    try expectEqual(@as(usize, 0), tree_helpers.getHeight(tree.b)); // Leaf
    try expectEqual(@as(usize, 1), tree_helpers.getHeight(tree.c));
    try expectEqual(@as(usize, 0), tree_helpers.getHeight(tree.d)); // Leaf
    try expectEqual(@as(usize, 0), tree_helpers.getHeight(tree.e)); // Leaf
    try expectEqual(@as(usize, 0), tree_helpers.getHeight(tree.f)); // Leaf
}

test "tree_helpers - countDescendants" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    try expectEqual(@as(usize, 6), tree_helpers.countDescendants(tree.root)); // a,b,c,d,e,f
    try expectEqual(@as(usize, 2), tree_helpers.countDescendants(tree.a)); // d,e
    try expectEqual(@as(usize, 0), tree_helpers.countDescendants(tree.b)); // Leaf
    try expectEqual(@as(usize, 1), tree_helpers.countDescendants(tree.c)); // f
    try expectEqual(@as(usize, 0), tree_helpers.countDescendants(tree.d)); // Leaf
}

// ============================================================================
// Common Ancestor Tests
// ============================================================================

test "tree_helpers - findCommonAncestor siblings" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Siblings share parent as common ancestor
    try expect(tree_helpers.findCommonAncestor(tree.a, tree.b) == tree.root);
    try expect(tree_helpers.findCommonAncestor(tree.b, tree.c) == tree.root);
    try expect(tree_helpers.findCommonAncestor(tree.d, tree.e) == tree.a);
}

test "tree_helpers - findCommonAncestor different depths" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Different depths
    try expect(tree_helpers.findCommonAncestor(tree.a, tree.d) == tree.a); // Parent-child
    try expect(tree_helpers.findCommonAncestor(tree.d, tree.b) == tree.root); // Cousins
    try expect(tree_helpers.findCommonAncestor(tree.d, tree.f) == tree.root); // Cousins
}

test "tree_helpers - findCommonAncestor self" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Self is common ancestor
    try expect(tree_helpers.findCommonAncestor(tree.root, tree.root) == tree.root);
    try expect(tree_helpers.findCommonAncestor(tree.a, tree.a) == tree.a);
}

// ============================================================================
// Shadow-Including Tree Traversal Tests (DOM §4.10.3)
// ============================================================================

test "tree_helpers - getShadowIncludingRoot without shadow" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Without shadow roots, shadow-including root == regular root
    try expect(tree_helpers.getShadowIncludingRoot(tree.root) == tree.root);
    try expect(tree_helpers.getShadowIncludingRoot(tree.a) == tree.root);
    try expect(tree_helpers.getShadowIncludingRoot(tree.d) == tree.root);
    try expect(tree_helpers.getShadowIncludingRoot(tree.f) == tree.root);
}

test "tree_helpers - isShadowIncludingDescendant without shadow" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Without shadow roots, shadow-including descendant == regular descendant
    try expect(tree_helpers.isShadowIncludingDescendant(tree.d, tree.root));
    try expect(tree_helpers.isShadowIncludingDescendant(tree.d, tree.a));
    try expect(!tree_helpers.isShadowIncludingDescendant(tree.root, tree.d));
    try expect(!tree_helpers.isShadowIncludingDescendant(tree.d, tree.e));
}

test "tree_helpers - isShadowIncludingInclusiveDescendant without shadow" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Self is inclusive descendant
    try expect(tree_helpers.isShadowIncludingInclusiveDescendant(tree.root, tree.root));
    try expect(tree_helpers.isShadowIncludingInclusiveDescendant(tree.a, tree.a));

    // Regular descendants
    try expect(tree_helpers.isShadowIncludingInclusiveDescendant(tree.d, tree.root));
    try expect(tree_helpers.isShadowIncludingInclusiveDescendant(tree.d, tree.a));
    try expect(!tree_helpers.isShadowIncludingInclusiveDescendant(tree.root, tree.d));
}

test "tree_helpers - isShadowIncludingAncestor without shadow" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Without shadow roots, shadow-including ancestor == regular ancestor
    try expect(tree_helpers.isShadowIncludingAncestor(tree.root, tree.d));
    try expect(tree_helpers.isShadowIncludingAncestor(tree.a, tree.d));
    try expect(!tree_helpers.isShadowIncludingAncestor(tree.d, tree.root));
    try expect(!tree_helpers.isShadowIncludingAncestor(tree.d, tree.a));
}

test "tree_helpers - isShadowIncludingInclusiveAncestor without shadow" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Self is inclusive ancestor
    try expect(tree_helpers.isShadowIncludingInclusiveAncestor(tree.root, tree.root));
    try expect(tree_helpers.isShadowIncludingInclusiveAncestor(tree.a, tree.a));

    // Regular ancestors
    try expect(tree_helpers.isShadowIncludingInclusiveAncestor(tree.root, tree.d));
    try expect(tree_helpers.isShadowIncludingInclusiveAncestor(tree.a, tree.d));
    try expect(!tree_helpers.isShadowIncludingInclusiveAncestor(tree.d, tree.root));
}

test "tree_helpers - getShadowIncludingInclusiveDescendants without shadow" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Get all inclusive descendants in tree order
    var descendants = try tree_helpers.getShadowIncludingInclusiveDescendants(allocator, tree.root);
    defer descendants.deinit();

    // Should be: root, a, d, e, b, c, f (preorder traversal)
    try expectEqual(@as(usize, 7), descendants.items.len);
    try expect(descendants.items[0] == tree.root);
    try expect(descendants.items[1] == tree.a);
    try expect(descendants.items[2] == tree.d);
    try expect(descendants.items[3] == tree.e);
    try expect(descendants.items[4] == tree.b);
    try expect(descendants.items[5] == tree.c);
    try expect(descendants.items[6] == tree.f);
}

test "tree_helpers - getShadowIncludingDescendants without shadow" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Get all descendants (not including root) in tree order
    var descendants = try tree_helpers.getShadowIncludingDescendants(allocator, tree.root);
    defer descendants.deinit();

    // Should be: a, d, e, b, c, f (not including root)
    try expectEqual(@as(usize, 6), descendants.items.len);
    try expect(descendants.items[0] == tree.a);
    try expect(descendants.items[1] == tree.d);
    try expect(descendants.items[2] == tree.e);
    try expect(descendants.items[3] == tree.b);
    try expect(descendants.items[4] == tree.c);
    try expect(descendants.items[5] == tree.f);
}

// TODO: Add tests with actual shadow roots
// These will require Element and ShadowRoot setup
// For now, the above tests verify the functions work correctly without shadow DOM
