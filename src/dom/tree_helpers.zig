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
