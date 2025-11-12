//! DOM Tree Algorithms (WHATWG DOM Standard §4.2.1 - Trees)
//!
//! Spec: https://dom.spec.whatwg.org/#trees
//!
//! This module implements the core tree relationship algorithms for DOM:
//! - Root detection
//! - Descendant/ancestor relationships
//! - Sibling relationships
//! - Tree order traversal
//! - Preceding/following detection
//!
//! These algorithms are fundamental to all DOM tree operations and are used
//! throughout the mutation, traversal, and query APIs.

const std = @import("std");

// TODO: Import actual Node type when available
pub const Node = struct {
    parent: ?*Node = null,
    children: std.ArrayList(*Node),
    allocator: std.mem.Allocator,

    // Temporary init for placeholder
    pub fn init(allocator: std.mem.Allocator) Node {
        return .{
            .children = std.ArrayList(*Node){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Node) void {
        self.children.deinit(self.allocator);
    }
};

/// Get the root of an object
/// Spec: https://dom.spec.whatwg.org/#concept-tree-root
///
/// The root of an object is itself, if its parent is null, or else it is
/// the root of its parent.
///
/// Returns: The root node (a node with parent == null)
pub fn root(node: *Node) *Node {
    var current = node;
    while (current.parent) |parent| {
        current = parent;
    }
    return current;
}

/// Check if A is a descendant of B
/// Spec: https://dom.spec.whatwg.org/#concept-tree-descendant
///
/// An object A is called a descendant of an object B, if either A is a child
/// of B or A is a child of an object C that is a descendant of B.
///
/// Returns: true if node is a descendant of ancestor
pub fn isDescendant(node: *const Node, ancestor: *const Node) bool {
    var current = node.parent;
    while (current) |parent| {
        if (parent == ancestor) {
            return true;
        }
        current = parent.parent;
    }
    return false;
}

/// Check if A is an inclusive descendant of B
/// Spec: https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant
///
/// An inclusive descendant is an object or one of its descendants.
///
/// Returns: true if node is ancestor or node is a descendant of ancestor
pub fn isInclusiveDescendant(node: *const Node, ancestor: *const Node) bool {
    if (node == ancestor) {
        return true;
    }
    return isDescendant(node, ancestor);
}

/// Check if A is an ancestor of B
/// Spec: https://dom.spec.whatwg.org/#concept-tree-ancestor
///
/// An object A is called an ancestor of an object B if and only if B is a
/// descendant of A.
///
/// Returns: true if node is an ancestor of descendant
pub fn isAncestor(node: *const Node, descendant: *const Node) bool {
    return isDescendant(descendant, node);
}

/// Check if A is an inclusive ancestor of B
/// Spec: https://dom.spec.whatwg.org/#concept-tree-inclusive-ancestor
///
/// An inclusive ancestor is an object or one of its ancestors.
///
/// Returns: true if node is descendant or node is an ancestor of descendant
pub fn isInclusiveAncestor(node: *const Node, descendant: *const Node) bool {
    if (node == descendant) {
        return true;
    }
    return isAncestor(node, descendant);
}

/// Check if A is a sibling of B
/// Spec: https://dom.spec.whatwg.org/#concept-tree-sibling
///
/// An object A is called a sibling of an object B, if and only if B and A
/// share the same non-null parent.
///
/// Returns: true if both nodes have the same non-null parent
pub fn isSibling(node_a: *const Node, node_b: *const Node) bool {
    if (node_a.parent == null) {
        return false;
    }
    return node_a.parent == node_b.parent;
}

/// Check if A is an inclusive sibling of B
/// Spec: https://dom.spec.whatwg.org/#concept-tree-inclusive-sibling
///
/// An inclusive sibling is an object or one of its siblings.
///
/// Returns: true if nodes are the same or are siblings
pub fn isInclusiveSibling(node_a: *const Node, node_b: *const Node) bool {
    if (node_a == node_b) {
        return true;
    }
    return isSibling(node_a, node_b);
}

/// Get the first child of a node
/// Spec: https://dom.spec.whatwg.org/#concept-tree-first-child
///
/// The first child of an object is its first child or null if it has no children.
///
/// Returns: First child or null
pub fn firstChild(node: *const Node) ?*Node {
    if (node.children.items.len == 0) {
        return null;
    }
    return node.children.items[0];
}

/// Get the last child of a node
/// Spec: https://dom.spec.whatwg.org/#concept-tree-last-child
///
/// The last child of an object is its last child or null if it has no children.
///
/// Returns: Last child or null
pub fn lastChild(node: *const Node) ?*Node {
    if (node.children.items.len == 0) {
        return null;
    }
    return node.children.items[node.children.items.len - 1];
}

/// Get the previous sibling of a node
/// Spec: https://dom.spec.whatwg.org/#concept-tree-previous-sibling
///
/// The previous sibling of an object is its first preceding sibling or null
/// if it has no preceding sibling.
///
/// Returns: Previous sibling or null
pub fn previousSibling(node: *const Node) ?*Node {
    const parent = node.parent orelse return null;

    // Find node's index in parent's children
    for (parent.children.items, 0..) |child, i| {
        if (child == node) {
            if (i == 0) {
                return null; // No previous sibling
            }
            return parent.children.items[i - 1];
        }
    }

    return null; // Node not found in parent (should not happen)
}

/// Get the next sibling of a node
/// Spec: https://dom.spec.whatwg.org/#concept-tree-next-sibling
///
/// The next sibling of an object is its first following sibling or null
/// if it has no following sibling.
///
/// Returns: Next sibling or null
pub fn nextSibling(node: *const Node) ?*Node {
    const parent = node.parent orelse return null;

    // Find node's index in parent's children
    for (parent.children.items, 0..) |child, i| {
        if (child == node) {
            if (i + 1 >= parent.children.items.len) {
                return null; // No next sibling
            }
            return parent.children.items[i + 1];
        }
    }

    return null; // Node not found in parent (should not happen)
}

/// Get the index of a node
/// Spec: https://dom.spec.whatwg.org/#concept-tree-index
///
/// The index of an object is its number of preceding siblings, or 0 if it has none.
///
/// Returns: Number of preceding siblings
pub fn index(node: *const Node) usize {
    const parent = node.parent orelse return 0;

    // Find node's index in parent's children
    for (parent.children.items, 0..) |child, i| {
        if (child == node) {
            return i;
        }
    }

    return 0; // Node not found in parent (should not happen)
}

/// Check if A is preceding B (in tree order)
/// Spec: https://dom.spec.whatwg.org/#concept-tree-preceding
///
/// An object A is preceding an object B if A and B are in the same tree and
/// A comes before B in tree order (preorder, depth-first traversal).
///
/// Returns: true if node_a precedes node_b in tree order
pub fn isPreceding(node_a: *const Node, node_b: *const Node) bool {
    return compareTreeOrder(node_a, node_b) == .before;
}

/// Check if A is following B (in tree order)
/// Spec: https://dom.spec.whatwg.org/#concept-tree-following
///
/// An object A is following an object B if A and B are in the same tree and
/// A comes after B in tree order (preorder, depth-first traversal).
///
/// Returns: true if node_a follows node_b in tree order
pub fn isFollowing(node_a: *const Node, node_b: *const Node) bool {
    return compareTreeOrder(node_a, node_b) == .after;
}

/// Compare two nodes in tree order (preorder, depth-first)
/// Returns: .before if node_a comes before node_b, .after if after, .equal if same node
fn compareTreeOrder(node_a: *const Node, node_b: *const Node) enum { before, equal, after } {
    if (node_a == node_b) return .equal;

    // Check if one is ancestor of the other
    if (isAncestor(node_a, node_b)) {
        // A is ancestor of B, so A comes before B in preorder
        return .before;
    }
    if (isAncestor(node_b, node_a)) {
        // B is ancestor of A, so A comes after B in preorder
        return .after;
    }

    // Neither is ancestor of the other, find common ancestor
    // and compare which branch comes first
    var ancestors_a = std.ArrayList(*const Node).init(std.heap.page_allocator);
    defer ancestors_a.deinit();

    // Build ancestor chain for A
    var current_a: ?*const Node = node_a;
    while (current_a) |node| {
        ancestors_a.append(node) catch return .equal; // fallback on error
        current_a = node.parent_node;
    }

    // Walk up from B until we find common ancestor
    var current_b: ?*const Node = node_b;
    while (current_b) |node_b_ancestor| {
        // Check if this B ancestor is in A's chain
        for (ancestors_a.items, 0..) |node_a_ancestor, i| {
            if (node_a_ancestor == node_b_ancestor) {
                // Found common ancestor
                if (i == 0) {
                    return .before;
                }

                const child_of_common_a = ancestors_a.items[i - 1];

                // Find B's child of common ancestor
                var child_of_common_b: *const Node = node_b;
                var parent_of_b = node_b.parent_node;
                while (parent_of_b != null and parent_of_b != node_b_ancestor) {
                    child_of_common_b = parent_of_b.?;
                    parent_of_b = child_of_common_b.parent_node;
                }

                // Compare indices of these children
                const common = node_b_ancestor;
                var index_a: ?usize = null;
                var index_b: ?usize = null;

                for (common.child_nodes.items, 0..) |child, idx| {
                    if (child == child_of_common_a) index_a = idx;
                    if (child == child_of_common_b) index_b = idx;
                }

                if (index_a != null and index_b != null) {
                    if (index_a.? < index_b.?) {
                        return .before;
                    } else {
                        return .after;
                    }
                }

                return .equal; // fallback
            }
        }
        current_b = node_b_ancestor.parent_node;
    }

    // No common ancestor (different trees) - treat as equal
    return .equal;
}

// ============================================================================
// Tests
// ============================================================================

test "tree - root with single node" {
    const allocator = std.testing.allocator;

    var node = Node.init(allocator);
    defer node.deinit();

    // A node with no parent is its own root
    try std.testing.expect(root(&node) == &node);
}

test "tree - root with parent chain" {
    const allocator = std.testing.allocator;

    var grandparent = Node.init(allocator);
    defer grandparent.deinit();

    var parent = Node.init(allocator);
    defer parent.deinit();
    parent.parent = &grandparent;

    var child = Node.init(allocator);
    defer child.deinit();
    child.parent = &parent;

    // All nodes should have same root
    try std.testing.expect(root(&child) == &grandparent);
    try std.testing.expect(root(&parent) == &grandparent);
    try std.testing.expect(root(&grandparent) == &grandparent);
}

test "tree - descendant relationships" {
    const allocator = std.testing.allocator;

    var grandparent = Node.init(allocator);
    defer grandparent.deinit();

    var parent = Node.init(allocator);
    defer parent.deinit();
    parent.parent = &grandparent;

    var child = Node.init(allocator);
    defer child.deinit();
    child.parent = &parent;

    // Child is descendant of parent and grandparent
    try std.testing.expect(isDescendant(&child, &parent));
    try std.testing.expect(isDescendant(&child, &grandparent));

    // Parent is descendant of grandparent
    try std.testing.expect(isDescendant(&parent, &grandparent));

    // Reverse is not true
    try std.testing.expect(!isDescendant(&parent, &child));
    try std.testing.expect(!isDescendant(&grandparent, &child));
}

test "tree - inclusive descendant" {
    const allocator = std.testing.allocator;

    var parent = Node.init(allocator);
    defer parent.deinit();

    var child = Node.init(allocator);
    defer child.deinit();
    child.parent = &parent;

    // Node is inclusive descendant of itself
    try std.testing.expect(isInclusiveDescendant(&child, &child));
    try std.testing.expect(isInclusiveDescendant(&parent, &parent));

    // Child is inclusive descendant of parent
    try std.testing.expect(isInclusiveDescendant(&child, &parent));
}

test "tree - ancestor relationships" {
    const allocator = std.testing.allocator;

    var grandparent = Node.init(allocator);
    defer grandparent.deinit();

    var parent = Node.init(allocator);
    defer parent.deinit();
    parent.parent = &grandparent;

    var child = Node.init(allocator);
    defer child.deinit();
    child.parent = &parent;

    // Parent and grandparent are ancestors of child
    try std.testing.expect(isAncestor(&parent, &child));
    try std.testing.expect(isAncestor(&grandparent, &child));

    // Grandparent is ancestor of parent
    try std.testing.expect(isAncestor(&grandparent, &parent));
}

test "tree - inclusive ancestor" {
    const allocator = std.testing.allocator;

    var parent = Node.init(allocator);
    defer parent.deinit();

    var child = Node.init(allocator);
    defer child.deinit();
    child.parent = &parent;

    // Node is inclusive ancestor of itself
    try std.testing.expect(isInclusiveAncestor(&child, &child));
    try std.testing.expect(isInclusiveAncestor(&parent, &parent));

    // Parent is inclusive ancestor of child
    try std.testing.expect(isInclusiveAncestor(&parent, &child));
}

test "tree - sibling relationships" {
    const allocator = std.testing.allocator;

    var parent = Node.init(allocator);
    defer parent.deinit();

    var child1 = Node.init(allocator);
    defer child1.deinit();
    child1.parent = &parent;

    var child2 = Node.init(allocator);
    defer child2.deinit();
    child2.parent = &parent;

    var orphan = Node.init(allocator);
    defer orphan.deinit();

    // Children with same parent are siblings
    try std.testing.expect(isSibling(&child1, &child2));
    try std.testing.expect(isSibling(&child2, &child1));

    // Node without parent is not sibling of anything
    try std.testing.expect(!isSibling(&orphan, &child1));
    try std.testing.expect(!isSibling(&child1, &orphan));
}

test "tree - firstChild and lastChild" {
    const allocator = std.testing.allocator;

    var parent = Node.init(allocator);
    defer parent.deinit();

    // No children
    try std.testing.expect(firstChild(&parent) == null);
    try std.testing.expect(lastChild(&parent) == null);

    var child1 = Node.init(allocator);
    defer child1.deinit();
    try parent.children.append(allocator, &child1);

    var child2 = Node.init(allocator);
    defer child2.deinit();
    try parent.children.append(allocator, &child2);

    var child3 = Node.init(allocator);
    defer child3.deinit();
    try parent.children.append(allocator, &child3);

    // With children
    try std.testing.expect(firstChild(&parent) == &child1);
    try std.testing.expect(lastChild(&parent) == &child3);
}

test "tree - previousSibling and nextSibling" {
    const allocator = std.testing.allocator;

    var parent = Node.init(allocator);
    defer parent.deinit();

    var child1 = Node.init(allocator);
    defer child1.deinit();
    child1.parent = &parent;
    try parent.children.append(allocator, &child1);

    var child2 = Node.init(allocator);
    defer child2.deinit();
    child2.parent = &parent;
    try parent.children.append(allocator, &child2);

    var child3 = Node.init(allocator);
    defer child3.deinit();
    child3.parent = &parent;
    try parent.children.append(allocator, &child3);

    // First child has no previous sibling
    try std.testing.expect(previousSibling(&child1) == null);
    try std.testing.expect(nextSibling(&child1) == &child2);

    // Middle child has both
    try std.testing.expect(previousSibling(&child2) == &child1);
    try std.testing.expect(nextSibling(&child2) == &child3);

    // Last child has no next sibling
    try std.testing.expect(previousSibling(&child3) == &child2);
    try std.testing.expect(nextSibling(&child3) == null);
}

test "tree - index" {
    const allocator = std.testing.allocator;

    var parent = Node.init(allocator);
    defer parent.deinit();

    var child1 = Node.init(allocator);
    defer child1.deinit();
    child1.parent = &parent;
    try parent.children.append(allocator, &child1);

    var child2 = Node.init(allocator);
    defer child2.deinit();
    child2.parent = &parent;
    try parent.children.append(allocator, &child2);

    var child3 = Node.init(allocator);
    defer child3.deinit();
    child3.parent = &parent;
    try parent.children.append(allocator, &child3);

    // Indices should match position in children array
    try std.testing.expectEqual(@as(usize, 0), index(&child1));
    try std.testing.expectEqual(@as(usize, 1), index(&child2));
    try std.testing.expectEqual(@as(usize, 2), index(&child3));

    // Node without parent has index 0
    var orphan = Node.init(allocator);
    defer orphan.deinit();
    try std.testing.expectEqual(@as(usize, 0), index(&orphan));
}
