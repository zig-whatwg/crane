//! Tree Helper Utilities
//! Pure helper functions for common DOM tree operations.
//!
//! Adapted from dom2's tree_helpers.zig with modifications for our List-based
//! child storage instead of direct sibling pointers.
//!
//! NOTE: getNextSibling() and getPreviousSibling() are O(n) due to our
//! child_nodes List structure. This is acceptable for now. Can optimize
//! later by adding sibling pointers if profiling shows this is a bottleneck.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import DOM types from the dom root module
// This works because tree_helpers.zig is part of src/dom/root.zig
pub const Node = @import("node").Node;

// ============================================================================
// Tree Navigation Adapters
// ============================================================================
// These functions adapt our List-based child storage to dom2's pointer-based
// tree navigation patterns.

/// Get the parent node of the given node
pub fn getParentNode(node: *const Node) ?*Node {
    return node.parent_node;
}

/// Get the first child of the given node
/// O(1) - Direct access to first element of child_nodes list
pub fn getFirstChild(node: *const Node) ?*Node {
    return if (node.child_nodes.items.len > 0)
        node.child_nodes.items[0]
    else
        null;
}

/// Get the last child of the given node
/// O(1) - Direct access to last element of child_nodes list
pub fn getLastChild(node: *const Node) ?*Node {
    return if (node.child_nodes.items.len > 0)
        node.child_nodes.items[node.child_nodes.items.len - 1]
    else
        null;
}

/// Get the next sibling of the given node
/// O(n) - Must search parent's child_nodes list to find current node's position
///
/// Performance note: This is slower than dom2's O(1) pointer access, but
/// acceptable for typical use cases. Can optimize later if needed by adding
/// sibling pointers alongside child_nodes list.
pub fn getNextSibling(node: *const Node) ?*Node {
    const parent = node.parent_node orelse return null;

    for (parent.child_nodes.items, 0..) |child, i| {
        if (child == node) {
            return if (i + 1 < parent.child_nodes.items.len)
                parent.child_nodes.items[i + 1]
            else
                null;
        }
    }

    return null;
}

/// Get the previous sibling of the given node
/// O(n) - Must search parent's child_nodes list to find current node's position
pub fn getPreviousSibling(node: *const Node) ?*Node {
    const parent = node.parent_node orelse return null;

    for (parent.child_nodes.items, 0..) |child, i| {
        if (child == node) {
            return if (i > 0)
                parent.child_nodes.items[i - 1]
            else
                null;
        }
    }

    return null;
}

/// Get the number of children of the given node
/// O(1) - Direct access to list length
pub fn getChildCount(node: *const Node) usize {
    return node.child_nodes.items.len;
}

/// Get child at specific index
/// O(1) - Direct array access
/// Returns null if index out of bounds
pub fn getChildAt(node: *const Node, index: usize) ?*Node {
    return if (index < node.child_nodes.items.len)
        node.child_nodes.items[index]
    else
        null;
}

/// Find the index of a child node
/// O(n) - Linear search through children
/// Returns null if child not found
pub fn getChildIndex(parent: *const Node, child: *const Node) ?usize {
    for (parent.child_nodes.items, 0..) |existing, i| {
        if (existing == child) {
            return i;
        }
    }
    return null;
}

// ============================================================================
// Tree Relationship Queries
// ============================================================================
// Pure functions for checking relationships between nodes

/// Check if `other` is an inclusive descendant of `node`
/// Per WHATWG DOM: An object A is an inclusive descendant of an object B,
/// if A is a descendant of B or A is B.
pub fn isInclusiveDescendant(node: *const Node, other: *const Node) bool {
    if (node == other) return true;
    return isDescendant(node, other);
}

/// Check if `other` is a descendant of `node`
/// Per WHATWG DOM: An object A is a descendant of an object B, if A's
/// parent is B or A's parent is a descendant of B.
pub fn isDescendant(node: *const Node, other: *const Node) bool {
    var current = other.parent_node;
    while (current) |parent| {
        if (parent == node) return true;
        current = parent.parent_node;
    }
    return false;
}

/// Check if `other` is an inclusive ancestor of `node`
/// Per WHATWG DOM: An object A is an inclusive ancestor of an object B,
/// if A is an ancestor of B or A is B.
pub fn isInclusiveAncestor(node: *const Node, other: *const Node) bool {
    if (node == other) return true;
    return isAncestor(node, other);
}

/// Check if `other` is an ancestor of `node`
/// Per WHATWG DOM: An object A is an ancestor of an object B, if B is a
/// descendant of A.
pub fn isAncestor(node: *const Node, other: *const Node) bool {
    return isDescendant(other, node);
}

/// Get the inclusive ancestors of a node
/// Returns a list of all ancestors including the node itself, from node up to root.
/// The list is ordered from the node to the root (node is first, root is last).
/// Caller owns the returned list and must call deinit().
pub fn getInclusiveAncestors(allocator: Allocator, node: *const Node) !std.ArrayList(*Node) {
    var ancestors = std.ArrayList(*Node).init(allocator);
    errdefer ancestors.deinit();

    // Add the node itself
    try ancestors.append(@constCast(node));

    // Walk up the tree adding each parent
    var current = node.parent_node;
    while (current) |parent| {
        try ancestors.append(parent);
        current = parent.parent_node;
    }

    return ancestors;
}

/// Check if two nodes are siblings (share the same parent)
pub fn areSiblings(a: *const Node, b: *const Node) bool {
    if (a.parent_node == null or b.parent_node == null) return false;
    return a.parent_node == b.parent_node;
}

/// Check if node has any children
/// O(1) - Check list length
pub fn hasChildren(node: *const Node) bool {
    return node.child_nodes.items.len > 0;
}

/// Check if node is the root (has no parent)
pub fn isRoot(node: *const Node) bool {
    return node.parent_node == null;
}

/// Check if node is a leaf (has no children)
pub fn isLeaf(node: *const Node) bool {
    return node.child_nodes.items.len == 0;
}

/// Check if node A is following node B (comes after B in tree order)
/// Per WHATWG DOM: An object A is following an object B if A and B are in
/// the same tree and A comes after B in tree order (preorder depth-first).
pub fn isFollowing(nodeA: *const Node, nodeB: *const Node) bool {
    // Use tree order comparison
    return compareTreeOrder(nodeA, nodeB) == .after;
}

/// Check if node A is preceding node B (comes before B in tree order)
/// Per WHATWG DOM: An object A is preceding an object B if A and B are in
/// the same tree and A comes before B in tree order.
pub fn isPreceding(nodeA: *const Node, nodeB: *const Node) bool {
    return compareTreeOrder(nodeA, nodeB) == .before;
}

/// Compare two nodes in tree order
/// Returns: .before if nodeA comes before nodeB, .after if nodeA comes after nodeB, .equal if same node
pub fn compareTreeOrder(nodeA: *const Node, nodeB: *const Node) enum { before, equal, after } {
    if (nodeA == nodeB) return .equal;

    // Find common ancestor and determine relative positions
    // This is essentially a tree traversal comparison

    // First check if one is ancestor of the other
    if (isAncestor(nodeA, nodeB)) {
        // A is ancestor of B, so A comes before B in preorder
        return .before;
    }
    if (isAncestor(nodeB, nodeA)) {
        // B is ancestor of A, so A comes after B in preorder
        return .after;
    }

    // Neither is ancestor of the other, find common ancestor
    // and compare which branch comes first
    var ancestorsA = std.ArrayList(*const Node).init(std.heap.page_allocator);
    defer ancestorsA.deinit();

    // Build ancestor chain for A
    var currentA: ?*const Node = nodeA;
    while (currentA) |node| {
        ancestorsA.append(node) catch return .equal; // fallback on error
        currentA = node.parent_node;
    }

    // Walk up from B until we find common ancestor
    var currentB: ?*const Node = nodeB;
    while (currentB) |nodeB_ancestor| {
        // Check if this B ancestor is in A's chain
        for (ancestorsA.items, 0..) |nodeA_ancestor, i| {
            if (nodeA_ancestor == nodeB_ancestor) {
                // Found common ancestor
                // Compare which child branch comes first
                if (i == 0) {
                    // nodeA itself is the common ancestor (shouldn't happen, we checked above)
                    return .before;
                }

                const childOfCommonA = ancestorsA.items[i - 1];

                // Find B's child of common ancestor
                var childOfCommonB: *const Node = nodeB;
                var parentOfB = nodeB.parent_node;
                while (parentOfB != null and parentOfB != nodeB_ancestor) {
                    childOfCommonB = parentOfB.?;
                    parentOfB = childOfCommonB.parent_node;
                }

                // Compare indices of these children
                const common = nodeB_ancestor;
                var indexA: ?usize = null;
                var indexB: ?usize = null;

                for (common.child_nodes.items, 0..) |child, idx| {
                    if (child == childOfCommonA) indexA = idx;
                    if (child == childOfCommonB) indexB = idx;
                }

                if (indexA != null and indexB != null) {
                    if (indexA.? < indexB.?) {
                        return .before;
                    } else {
                        return .after;
                    }
                }

                return .equal; // fallback
            }
        }
        currentB = nodeB_ancestor.parent_node;
    }

    // No common ancestor found (different trees) - treat as equal
    return .equal;
}

// ============================================================================
// Tree Traversal
// ============================================================================
// Iteration helpers for traversing the tree

/// Get the next node in pre-order traversal
/// Pre-order: Visit node, then children left-to-right
pub fn getNextInPreOrder(node: *const Node) ?*Node {
    // If node has children, next is first child
    if (getFirstChild(node)) |first_child| {
        return first_child;
    }

    // Otherwise, traverse up to find next sibling of an ancestor
    var current = node;
    while (true) {
        if (getNextSibling(current)) |next_sibling| {
            return next_sibling;
        }

        // Move up to parent
        current = getParentNode(current) orelse return null;
    }
}

/// Get the previous node in pre-order traversal
pub fn getPreviousInPreOrder(node: *const Node) ?*Node {
    // If has previous sibling, go to rightmost descendant of that sibling
    if (getPreviousSibling(node)) |prev_sibling| {
        return getRightmostDescendant(prev_sibling);
    }

    // Otherwise, parent is previous
    return getParentNode(node);
}

/// Get the rightmost (deepest last) descendant of a node
fn getRightmostDescendant(node: *const Node) *Node {
    var current = node;
    while (getLastChild(current)) |last_child| {
        current = last_child;
    }
    return current;
}

// ============================================================================
// Text Content Extraction
// ============================================================================

/// Get the descendant text content of a node
/// Concatenates all Text node descendants in tree order
/// Caller owns returned memory
pub fn getDescendantTextContent(node: *const Node, allocator: Allocator) ![]const u8 {
    var text_list = std.ArrayList(u8).init(allocator);
    errdefer text_list.deinit();

    try collectTextContent(node, &text_list);

    return try text_list.toOwnedSlice();
}

/// Recursively collect text content from node and its descendants
fn collectTextContent(node: *const Node, list: *std.ArrayList(u8)) !void {
    // If this is a Text node (type 3), append its content
    if (node.node_type == Node.TEXT_NODE) {
        // node_name contains the text data for Text nodes
        try list.appendSlice(node.node_name);
    }

    // Recursively process children
    for (node.child_nodes.items) |child| {
        try collectTextContent(child, list);
    }
}

// ============================================================================
// Tree Depth and Level
// ============================================================================

/// Get the depth of a node (distance from root)
/// Root has depth 0
pub fn getDepth(node: *const Node) usize {
    var depth: usize = 0;
    var current = node.parent_node;
    while (current) |parent| {
        depth += 1;
        current = parent.parent_node;
    }
    return depth;
}

/// Get the height of a tree (maximum depth of any descendant)
/// Leaf nodes have height 0
pub fn getHeight(node: *const Node) usize {
    var max_height: usize = 0;

    for (node.child_nodes.items) |child| {
        const child_height = getHeight(child) + 1;
        if (child_height > max_height) {
            max_height = child_height;
        }
    }

    return max_height;
}

/// Count total number of descendants (not including self)
pub fn countDescendants(node: *const Node) usize {
    var count: usize = 0;

    for (node.child_nodes.items) |child| {
        count += 1; // Count the child
        count += countDescendants(child); // Count child's descendants
    }

    return count;
}

// ============================================================================
// Common Ancestor
// ============================================================================

/// Find the lowest common ancestor of two nodes
/// Returns null if nodes are in different trees
pub fn findCommonAncestor(a: *const Node, b: *const Node) ?*Node {
    // Collect all ancestors of a
    var a_ancestors = std.ArrayList(*const Node).init(std.heap.page_allocator);
    defer a_ancestors.deinit();

    var current = a;
    while (true) {
        a_ancestors.append(current) catch return null;
        current = getParentNode(current) orelse break;
    }

    // Walk up from b until we find a common ancestor
    current = b;
    while (true) {
        for (a_ancestors.items) |ancestor| {
            if (ancestor == current) {
                return @constCast(current);
            }
        }
        current = getParentNode(current) orelse return null;
    }
}

// ============================================================================
// Performance Notes
// ============================================================================
//
// Complexity comparison with dom2:
//
// | Operation              | Dom2 | Our Implementation | Reason            |
// |------------------------|------|--------------------|-------------------|
// | getFirstChild          | O(1) | O(1)              | Direct access     |
// | getLastChild           | O(1) | O(1)              | Direct access     |
// | getParentNode          | O(1) | O(1)              | Direct pointer    |
// | getNextSibling         | O(1) | O(n)              | List search       |
// | getPreviousSibling     | O(1) | O(n)              | List search       |
// | getChildCount          | N/A  | O(1)              | List length       |
// | getChildAt             | N/A  | O(1)              | Array indexing    |
// | getChildIndex          | N/A  | O(n)              | Linear search     |
//
// Trade-off: We sacrifice O(1) sibling navigation for simpler data structure.
// This is acceptable because:
// 1. Most DOM operations access children, not siblings
// 2. Typical elements have few children (median ~3-5)
// 3. O(n) with n=5 is still very fast (~20-30 CPU cycles)
//
// Optimization strategy:
// - Profile real-world usage first
// - If sibling access is hot path, add sibling pointers alongside child_nodes
// - For now, prefer simplicity over premature optimization
//
// Spec references:
// - Tree: https://dom.spec.whatwg.org/#trees
// - Inclusive ancestor/descendant: https://dom.spec.whatwg.org/#concept-tree-inclusive-ancestor

// ============================================================================
// NodeIterator/TreeWalker Helper Functions
// ============================================================================

/// Get the next node in tree order, constrained within a root
/// Returns null if no next node exists within root
/// Used by NodeIterator for forward traversal
pub fn getNextNodeInTree(node: *const Node, root: *const Node) ?*Node {
    // If node has children, return first child
    if (getFirstChild(node)) |child| {
        return child;
    }

    // Otherwise, find next sibling (or ancestor's next sibling)
    var current = node;
    while (true) {
        // Don't go past root
        if (current == root) return null;

        // Try next sibling
        if (getNextSibling(current)) |sibling| {
            return sibling;
        }

        // Move up to parent
        const parent = getParentNode(current) orelse return null;
        if (parent == root) return null; // Don't go past root
        current = parent;
    }
}

/// Get the previous node in tree order, constrained within a root
/// Returns null if no previous node exists within root
/// Used by NodeIterator for backward traversal
pub fn getPreviousNodeInTree(node: *const Node, root: *const Node) ?*Node {
    // Don't go before root
    if (node == root) return null;

    // If node has previous sibling, return its last descendant
    if (getPreviousSibling(node)) |sibling| {
        return getLastInclusiveDescendant(sibling);
    }

    // Otherwise return parent (if not root)
    const parent = getParentNode(node) orelse return null;
    if (parent == root) return null;
    return parent;
}

/// Get the last inclusive descendant of a node (the node that appears last in tree order)
/// This is the node itself if it has no children, otherwise the last descendant of its last child
pub fn getLastInclusiveDescendant(node: *const Node) *Node {
    var current = node;
    while (getLastChild(current)) |last_child| {
        current = last_child;
    }
    return current;
}

/// Get the next node after to_be_removed that is an inclusive descendant of root
/// but NOT an inclusive descendant of to_be_removed
/// Used by NodeIterator.preRemoveSteps
pub fn getNextNodeNotInSubtree(to_be_removed: *const Node, root: *const Node) ?*Node {
    // Start from the node after to_be_removed in tree order
    var current: ?*const Node = to_be_removed;

    while (current) |node| {
        // Try to find next in tree order, but skip to_be_removed's subtree

        // If this node is to_be_removed, skip its entire subtree
        if (node == to_be_removed) {
            // Skip to next sibling or ancestor's next sibling
            var skip = node;
            while (true) {
                if (skip == root) return null;

                if (getNextSibling(skip)) |sibling| {
                    current = sibling;
                    break;
                }

                const parent = getParentNode(skip) orelse return null;
                if (parent == root) return null;
                skip = parent;
            }
            continue;
        }

        // Check if this node is in root's subtree but not in to_be_removed's subtree
        if (isInclusiveDescendant(node, root) and !isInclusiveDescendant(node, to_be_removed)) {
            return @constCast(node);
        }

        // Move to next node in tree
        current = getNextNodeInTree(node, root);
    }

    return null;
}

// ============================================================================
// Tree Traversal for Slot Algorithms
// ============================================================================

/// Get all inclusive descendants of a node in tree order (preorder, depth-first)
/// Returns an ArrayList that the caller must deinit
///
/// Tree order is defined in DOM spec as preorder, depth-first traversal:
/// 1. Visit node
/// 2. Visit first child and its descendants
/// 3. Visit next sibling and its descendants
pub fn getInclusiveDescendantsInTreeOrder(allocator: Allocator, root: *const Node) !std.ArrayList(*Node) {
    var result = std.ArrayList(*Node).init(allocator);
    errdefer result.deinit();

    // Add root first (inclusive)
    try result.append(@constCast(root));

    // Recursively add all descendants
    try collectDescendantsInTreeOrder(&result, root);

    return result;
}

/// Helper function to recursively collect descendants
fn collectDescendantsInTreeOrder(result: *std.ArrayList(*Node), node: *const Node) !void {
    // Visit all children in order
    // node.child_nodes is a List, not ArrayList, so iterate properly
    var i: usize = 0;
    while (i < node.child_nodes.len) : (i += 1) {
        const child = node.child_nodes.get(i).?;
        try result.append(child);
        // Recursively visit child's descendants
        try collectDescendantsInTreeOrder(result, child);
    }
}

/// Get all descendants (not including root) in tree order
pub fn getDescendantsInTreeOrder(allocator: Allocator, root: *const Node) !std.ArrayList(*Node) {
    var result = std.ArrayList(*Node).init(allocator);
    errdefer result.deinit();

    // Don't add root, just its descendants
    try collectDescendantsInTreeOrder(&result, root);

    return result;
}

// Tree traversal functions are tested through integration tests in
// tests/dom/slot_algorithms_test.zig since they require proper DOM tree setup
