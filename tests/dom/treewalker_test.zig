//! TreeWalker tests per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-treewalker

const std = @import("std");
const dom = @import("dom");
const Node = dom.Node;
const TreeWalker = dom.TreeWalker;
const NodeFilter = dom.NodeFilter;

test "TreeWalker - parentNode moves to filtered parent" {
    const allocator = std.testing.allocator;

    // Create tree: root -> child -> grandchild
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child = try Node.init(allocator, .ELEMENT_NODE);
    defer child.deinit();
    try root.appendChild(&child);

    var grandchild = try Node.init(allocator, .TEXT_NODE);
    defer grandchild.deinit();
    try child.appendChild(&grandchild);

    // Start at grandchild
    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();
    walker.set_currentNode(&grandchild);

    // Move to parent
    const parent = try walker.parentNode();
    try std.testing.expect(parent == &child);
    try std.testing.expect(walker.get_currentNode() == &child);
}

test "TreeWalker - firstChild moves to first filtered child" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child1 = try Node.init(allocator, .ELEMENT_NODE);
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, .TEXT_NODE);
    defer child2.deinit();
    try root.appendChild(&child2);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();

    const first = try walker.firstChild();
    try std.testing.expect(first == &child1);
}

test "TreeWalker - lastChild moves to last filtered child" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child1 = try Node.init(allocator, .ELEMENT_NODE);
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, .TEXT_NODE);
    defer child2.deinit();
    try root.appendChild(&child2);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();

    const last = try walker.lastChild();
    try std.testing.expect(last == &child2);
}

test "TreeWalker - nextSibling moves to next filtered sibling" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2, child3]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child1 = try Node.init(allocator, .ELEMENT_NODE);
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, .TEXT_NODE);
    defer child2.deinit();
    try root.appendChild(&child2);

    var child3 = try Node.init(allocator, .ELEMENT_NODE);
    defer child3.deinit();
    try root.appendChild(&child3);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();
    walker.set_currentNode(&child1);

    const next = try walker.nextSibling();
    try std.testing.expect(next == &child2);
}

test "TreeWalker - previousSibling moves to previous filtered sibling" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child1 = try Node.init(allocator, .ELEMENT_NODE);
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, .TEXT_NODE);
    defer child2.deinit();
    try root.appendChild(&child2);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();
    walker.set_currentNode(&child2);

    const prev = try walker.previousSibling();
    try std.testing.expect(prev == &child1);
}

test "TreeWalker - nextNode traverses in tree order" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1 -> [grandchild], child2]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child1 = try Node.init(allocator, .ELEMENT_NODE);
    defer child1.deinit();
    try root.appendChild(&child1);

    var grandchild = try Node.init(allocator, .TEXT_NODE);
    defer grandchild.deinit();
    try child1.appendChild(&grandchild);

    var child2 = try Node.init(allocator, .ELEMENT_NODE);
    defer child2.deinit();
    try root.appendChild(&child2);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();

    // Traverse: root -> child1 -> grandchild -> child2
    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == &child1);

    const n2 = try walker.nextNode();
    try std.testing.expect(n2 == &grandchild);

    const n3 = try walker.nextNode();
    try std.testing.expect(n3 == &child2);

    const n4 = try walker.nextNode();
    try std.testing.expect(n4 == null);
}

test "TreeWalker - previousNode traverses in reverse order" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child1 = try Node.init(allocator, .ELEMENT_NODE);
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, .TEXT_NODE);
    defer child2.deinit();
    try root.appendChild(&child2);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();
    walker.set_currentNode(&child2);

    const n1 = try walker.previousNode();
    try std.testing.expect(n1 == &child1);

    const n2 = try walker.previousNode();
    try std.testing.expect(n2 == &root);

    const n3 = try walker.previousNode();
    try std.testing.expect(n3 == null);
}

test "TreeWalker - whatToShow filters by node type" {
    const allocator = std.testing.allocator;

    // Create tree: root(element) -> [element, text, element]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var element1 = try Node.init(allocator, .ELEMENT_NODE);
    defer element1.deinit();
    try root.appendChild(&element1);

    var text = try Node.init(allocator, .TEXT_NODE);
    defer text.deinit();
    try root.appendChild(&text);

    var element2 = try Node.init(allocator, .ELEMENT_NODE);
    defer element2.deinit();
    try root.appendChild(&element2);

    // Only show elements
    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ELEMENT, null, null);
    defer walker.deinit();

    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == &element1);

    const n2 = try walker.nextNode();
    try std.testing.expect(n2 == &element2);

    const n3 = try walker.nextNode();
    try std.testing.expect(n3 == null);
}

test "TreeWalker - filter callback with FILTER_SKIP descends" {
    const allocator = std.testing.allocator;

    // Skip TEXT_NODE but descend into their subtrees
    const skipText = struct {
        fn callback(node: *Node) u16 {
            return if (node.node_type == .TEXT_NODE)
                NodeFilter.FILTER_SKIP
            else
                NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var text1 = try Node.init(allocator, .TEXT_NODE);
    defer text1.deinit();
    try root.appendChild(&text1);

    var element = try Node.init(allocator, .ELEMENT_NODE);
    defer element.deinit();
    try root.appendChild(&element);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, skipText, null);
    defer walker.deinit();

    // Should skip text but include elements
    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == &element);

    const n2 = try walker.nextNode();
    try std.testing.expect(n2 == null);
}

test "TreeWalker - filter callback with FILTER_REJECT skips subtree" {
    const allocator = std.testing.allocator;

    // Reject TEXT_NODE and skip their subtrees entirely
    const rejectText = struct {
        fn callback(node: *Node) u16 {
            return if (node.node_type == .TEXT_NODE)
                NodeFilter.FILTER_REJECT
            else
                NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var text = try Node.init(allocator, .TEXT_NODE);
    defer text.deinit();
    try root.appendChild(&text);

    // Add child to text (would be visited if SKIP, not if REJECT)
    var textChild = try Node.init(allocator, .ELEMENT_NODE);
    defer textChild.deinit();
    try text.appendChild(&textChild);

    var element = try Node.init(allocator, .ELEMENT_NODE);
    defer element.deinit();
    try root.appendChild(&element);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, rejectText, null);
    defer walker.deinit();

    // Should reject text and skip its children
    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == &element);
}

test "TreeWalker - currentNode setter changes position" {
    const allocator = std.testing.allocator;

    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var child1 = try Node.init(allocator, .ELEMENT_NODE);
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, .ELEMENT_NODE);
    defer child2.deinit();
    try root.appendChild(&child2);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();

    // Initially at root
    try std.testing.expect(walker.get_currentNode() == &root);

    // Set to child2
    walker.set_currentNode(&child2);
    try std.testing.expect(walker.get_currentNode() == &child2);

    // Previous from child2 should get child1
    const prev = try walker.previousNode();
    try std.testing.expect(prev == &child1);
}

test "TreeWalker - attributes return correct values" {
    const allocator = std.testing.allocator;

    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    const filter = struct {
        fn callback(node: *Node) u16 {
            _ = node;
            return NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ELEMENT, filter, null);
    defer walker.deinit();

    try std.testing.expect(walker.get_root() == &root);
    try std.testing.expect(walker.get_currentNode() == &root);
    try std.testing.expect(walker.get_whatToShow() == NodeFilter.SHOW_ELEMENT);
    try std.testing.expect(walker.get_filter() == filter);
}

test "TreeWalker - parentNode at root returns null" {
    const allocator = std.testing.allocator;

    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();

    // At root, parentNode returns null
    const parent = try walker.parentNode();
    try std.testing.expect(parent == null);
}

test "TreeWalker - nextSibling at root returns null" {
    const allocator = std.testing.allocator;

    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();

    // At root, nextSibling returns null (root has no siblings in traversal)
    const sibling = try walker.nextSibling();
    try std.testing.expect(sibling == null);
}

test "TreeWalker - complex nested traversal" {
    const allocator = std.testing.allocator;

    // Create complex tree: root -> [a -> [a1, a2], b -> [b1]]
    var root = try Node.init(allocator, .ELEMENT_NODE);
    defer root.deinit();

    var a = try Node.init(allocator, .ELEMENT_NODE);
    defer a.deinit();
    try root.appendChild(&a);

    var a1 = try Node.init(allocator, .TEXT_NODE);
    defer a1.deinit();
    try a.appendChild(&a1);

    var a2 = try Node.init(allocator, .TEXT_NODE);
    defer a2.deinit();
    try a.appendChild(&a2);

    var b = try Node.init(allocator, .ELEMENT_NODE);
    defer b.deinit();
    try root.appendChild(&b);

    var b1 = try Node.init(allocator, .TEXT_NODE);
    defer b1.deinit();
    try b.appendChild(&b1);

    var walker = try TreeWalker.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer walker.deinit();

    // Full traversal: root -> a -> a1 -> a2 -> b -> b1
    const nodes = [_]*Node{ &a, &a1, &a2, &b, &b1 };
    for (nodes) |expected| {
        const node = try walker.nextNode();
        try std.testing.expect(node == expected);
    }

    const end = try walker.nextNode();
    try std.testing.expect(end == null);
}
