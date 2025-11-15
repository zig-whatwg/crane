//! TreeWalker tests per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-treewalker

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Node = dom.Node;
const Element = dom.Element;
const Text = dom.Text;
const TreeWalker = dom.TreeWalker;
const NodeFilter = dom.NodeFilter;

test "TreeWalker - parentNode moves to filtered parent" {
    const allocator = std.testing.allocator;

    // Create tree: root -> child -> grandchild
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child = try Element.init(allocator, "element");
    defer child.deinit();
    _ = try root.call_appendChild(@ptrCast(&child));

    var grandchild = try Text.init(allocator);
    defer grandchild.deinit();
    _ = try child.call_appendChild(@ptrCast(&grandchild));

    // Start at grandchild
    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();
    walker.set_currentNode(@ptrCast(&grandchild));

    // Move to parent
    const parent = try walker.parentNode();
    try std.testing.expect(parent == @as(*Node, @ptrCast(&child)));
    try std.testing.expect(walker.get_currentNode() == &child);
}

test "TreeWalker - firstChild moves to first filtered child" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child1 = try Element.init(allocator, "element");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var child2 = try Text.init(allocator);
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();

    const first = try walker.firstChild();
    try std.testing.expect(first == @as(*Node, @ptrCast(&child1)));
}

test "TreeWalker - lastChild moves to last filtered child" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child1 = try Element.init(allocator, "element");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var child2 = try Text.init(allocator);
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();

    const last = try walker.lastChild();
    try std.testing.expect(last == @as(*Node, @ptrCast(&child2)));
}

test "TreeWalker - nextSibling moves to next filtered sibling" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2, child3]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child1 = try Element.init(allocator, "element");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var child2 = try Text.init(allocator);
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var child3 = try Element.init(allocator, "element");
    defer child3.deinit();
    _ = try root.call_appendChild(@ptrCast(&child3));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();
    walker.set_currentNode(@ptrCast(&child1));

    const next = try walker.nextSibling();
    try std.testing.expect(next == @as(*Node, @ptrCast(&child2)));
}

test "TreeWalker - previousSibling moves to previous filtered sibling" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child1 = try Element.init(allocator, "element");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var child2 = try Text.init(allocator);
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();
    walker.set_currentNode(@ptrCast(&child2));

    const prev = try walker.previousSibling();
    try std.testing.expect(prev == @as(*Node, @ptrCast(&child1)));
}

test "TreeWalker - nextNode traverses in tree order" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1 -> [grandchild], child2]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child1 = try Element.init(allocator, "element");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var grandchild = try Text.init(allocator);
    defer grandchild.deinit();
    _ = try child1.call_appendChild(@ptrCast(&grandchild));

    var child2 = try Element.init(allocator, "element");
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();

    // Traverse: root -> child1 -> grandchild -> child2
    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == @as(*Node, @ptrCast(&child1)));

    const n2 = try walker.nextNode();
    try std.testing.expect(n2 == @as(*Node, @ptrCast(&grandchild)));

    const n3 = try walker.nextNode();
    try std.testing.expect(n3 == @as(*Node, @ptrCast(&child2)));

    const n4 = try walker.nextNode();
    try std.testing.expect(n4 == null);
}

test "TreeWalker - previousNode traverses in reverse order" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child1 = try Element.init(allocator, "element");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var child2 = try Text.init(allocator);
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();
    walker.set_currentNode(@ptrCast(&child2));

    const n1 = try walker.previousNode();
    try std.testing.expect(n1 == @as(*Node, @ptrCast(&child1)));

    const n2 = try walker.previousNode();
    try std.testing.expect(n2 == @as(*Node, @ptrCast(&root)));

    const n3 = try walker.previousNode();
    try std.testing.expect(n3 == null);
}

test "TreeWalker - whatToShow filters by node type" {
    const allocator = std.testing.allocator;

    // Create tree: root(element) -> [element, text, element]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var element1 = try Element.init(allocator, "element");
    defer element1.deinit();
    _ = try root.call_appendChild(@ptrCast(&element1));

    var text = try Text.init(allocator);
    defer text.deinit();
    _ = try root.call_appendChild(@ptrCast(&text));

    var element2 = try Element.init(allocator, "element");
    defer element2.deinit();
    _ = try root.call_appendChild(@ptrCast(&element2));

    // Only show elements
    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ELEMENT, null);
    defer walker.deinit();

    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == @as(*Node, @ptrCast(&element1)));

    const n2 = try walker.nextNode();
    try std.testing.expect(n2 == @as(*Node, @ptrCast(&element2)));

    const n3 = try walker.nextNode();
    try std.testing.expect(n3 == null);
}

test "TreeWalker - filter callback with FILTER_SKIP descends" {
    const allocator = std.testing.allocator;

    // Skip TEXT_NODE but descend into their subtrees
    const skipText = struct {
        fn callback(node: *Node) u16 {
            return if (node.node_type == Node.TEXT_NODE)
                NodeFilter.FILTER_SKIP
            else
                NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var text1 = try Text.init(allocator);
    defer text1.deinit();
    _ = try root.call_appendChild(@ptrCast(&text1));

    var element = try Element.init(allocator, "element");
    defer element.deinit();
    _ = try root.call_appendChild(@ptrCast(&element));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, skipText);
    defer walker.deinit();

    // Should skip text but include elements
    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == @as(*Node, @ptrCast(&element)));

    const n2 = try walker.nextNode();
    try std.testing.expect(n2 == null);
}

test "TreeWalker - filter callback with FILTER_REJECT skips subtree" {
    const allocator = std.testing.allocator;

    // Reject TEXT_NODE and skip their subtrees entirely
    const rejectText = struct {
        fn callback(node: *Node) u16 {
            return if (node.node_type == Node.TEXT_NODE)
                NodeFilter.FILTER_REJECT
            else
                NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var text = try Text.init(allocator);
    defer text.deinit();
    _ = try root.call_appendChild(@ptrCast(&text));

    // Add child to text (would be visited if SKIP, not if REJECT)
    var textChild = try Element.init(allocator, "element");
    defer textChild.deinit();
    _ = try text.call_appendChild(@ptrCast(&textChild));

    var element = try Element.init(allocator, "element");
    defer element.deinit();
    _ = try root.call_appendChild(@ptrCast(&element));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, rejectText);
    defer walker.deinit();

    // Should reject text and skip its children
    const n1 = try walker.nextNode();
    try std.testing.expect(n1 == @as(*Node, @ptrCast(&element)));
}

test "TreeWalker - currentNode setter changes position" {
    const allocator = std.testing.allocator;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child1 = try Element.init(allocator, "element");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var child2 = try Element.init(allocator, "element");
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();

    // Initially at root
    try std.testing.expect(walker.get_currentNode() == @as(*Node, @ptrCast(&root)));

    // Set to child2
    walker.set_currentNode(@ptrCast(&child2));
    try std.testing.expect(walker.get_currentNode() == @as(*Node, @ptrCast(&child2)));

    // Previous from child2 should get child1
    const prev = try walker.previousNode();
    try std.testing.expect(prev == @as(*Node, @ptrCast(&child1)));
}

test "TreeWalker - attributes return correct values" {
    const allocator = std.testing.allocator;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    const filter = struct {
        fn callback(node: *Node) u16 {
            _ = node;
            return NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ELEMENT, filter);
    defer walker.deinit();

    try std.testing.expect(walker.get_root() == @as(*Node, @ptrCast(&root)));
    try std.testing.expect(walker.get_currentNode() == @as(*Node, @ptrCast(&root)));
    try std.testing.expect(walker.get_whatToShow() == NodeFilter.SHOW_ELEMENT);
    try std.testing.expect(walker.get_filter() == filter);
}

test "TreeWalker - parentNode at root returns null" {
    const allocator = std.testing.allocator;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();

    // At root, parentNode returns null
    const parent = try walker.parentNode();
    try std.testing.expect(parent == null);
}

test "TreeWalker - nextSibling at root returns null" {
    const allocator = std.testing.allocator;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();

    // At root, nextSibling returns null (root has no siblings in traversal)
    const sibling = try walker.nextSibling();
    try std.testing.expect(sibling == null);
}

test "TreeWalker - complex nested traversal" {
    const allocator = std.testing.allocator;

    // Create complex tree: root -> [a -> [a1, a2], b -> [b1]]
    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var a = try Element.init(allocator, "element");
    defer a.deinit();
    _ = try root.call_appendChild(@ptrCast(&a));

    var a1 = try Text.init(allocator);
    defer a1.deinit();
    _ = try a.call_appendChild(@ptrCast(&a1));

    var a2 = try Text.init(allocator);
    defer a2.deinit();
    _ = try a.call_appendChild(@ptrCast(&a2));

    var b = try Element.init(allocator, "element");
    defer b.deinit();
    _ = try root.call_appendChild(@ptrCast(&b));

    var b1 = try Text.init(allocator);
    defer b1.deinit();
    _ = try b.call_appendChild(@ptrCast(&b1));

    var walker = try TreeWalker.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer walker.deinit();

    // Full traversal: root -> a -> a1 -> a2 -> b -> b1
    const nodes = [_]*Node{ @ptrCast(&a), @ptrCast(&a1), @ptrCast(&a2), @ptrCast(&b), @ptrCast(&b1) };
    for (nodes) |expected| {
        const node = try walker.nextNode();
        try std.testing.expect(node == expected);
    }

    const end = try walker.nextNode();
    try std.testing.expect(end == null);
}
