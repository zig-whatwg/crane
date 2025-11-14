//! NodeIterator tests per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-nodeiterator

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Node = dom.Node;
const NodeIterator = dom.NodeIterator;
const NodeFilter = dom.NodeFilter;

test "NodeIterator - basic forward iteration" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2, child3]
    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var child1 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer child2.deinit();
    try root.appendChild(&child2);

    var child3 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer child3.deinit();
    try root.appendChild(&child3);

    // Create iterator showing all nodes
    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer iterator.deinit();

    // Iterator starts before root, so first nextNode() returns root
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == &root);

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == &child1);

    const node3 = try iterator.nextNode();
    try std.testing.expect(node3 == &child2);

    const node4 = try iterator.nextNode();
    try std.testing.expect(node4 == &child3);

    // No more nodes
    const node5 = try iterator.nextNode();
    try std.testing.expect(node5 == null);
}

test "NodeIterator - basic backward iteration" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var child1 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer child2.deinit();
    try root.appendChild(&child2);

    // Create iterator
    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer iterator.deinit();

    // First call to previousNode() returns null (already before root)
    const node1 = try iterator.previousNode();
    try std.testing.expect(node1 == null);
}

test "NodeIterator - forward then backward" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2]
    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var child1 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer child1.deinit();
    try root.appendChild(&child1);

    var child2 = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer child2.deinit();
    try root.appendChild(&child2);

    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer iterator.deinit();

    // Go forward to child1
    _ = try iterator.nextNode(); // root
    const forward = try iterator.nextNode(); // child1
    try std.testing.expect(forward == &child1);

    // Go backward
    const backward = try iterator.previousNode(); // back to root
    try std.testing.expect(backward == &root);
}

test "NodeIterator - whatToShow SHOW_ELEMENT" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [element, text, element]
    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var element1 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer element1.deinit();
    try root.appendChild(&element1);

    var text = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer text.deinit();
    try root.appendChild(&text);

    var element2 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer element2.deinit();
    try root.appendChild(&element2);

    // Iterator only shows elements
    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ELEMENT, null, null);
    defer iterator.deinit();

    // Should get root, element1, element2 (skipping text)
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == &root);

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == &element1);

    const node3 = try iterator.nextNode();
    try std.testing.expect(node3 == &element2);

    const node4 = try iterator.nextNode();
    try std.testing.expect(node4 == null);
}

test "NodeIterator - whatToShow SHOW_TEXT" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [element, text, element]
    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var element1 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer element1.deinit();
    try root.appendChild(&element1);

    var text = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer text.deinit();
    try root.appendChild(&text);

    var element2 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer element2.deinit();
    try root.appendChild(&element2);

    // Iterator only shows text nodes
    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_TEXT, null, null);
    defer iterator.deinit();

    // Should get only text node
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == &text);

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == null);
}

test "NodeIterator - filter callback accepts all" {
    const allocator = std.testing.allocator;

    const acceptAll = struct {
        fn callback(node: *Node) u16 {
            _ = node;
            return NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var child = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer child.deinit();
    try root.appendChild(&child);

    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ALL, acceptAll, null);
    defer iterator.deinit();

    // Should iterate all nodes
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == &root);

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == &child);
}

test "NodeIterator - filter callback skips nodes" {
    const allocator = std.testing.allocator;

    // Skip TEXT_NODE
    const skipText = struct {
        fn callback(node: *Node) u16 {
            return if (node.node_type == Node.TEXT_NODE)
                NodeFilter.FILTER_SKIP
            else
                NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var text1 = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer text1.deinit();
    try root.appendChild(&text1);

    var element = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer element.deinit();
    try root.appendChild(&element);

    var text2 = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer text2.deinit();
    try root.appendChild(&text2);

    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ALL, skipText, null);
    defer iterator.deinit();

    // Should skip text nodes
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == &root);

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == &element);

    const node3 = try iterator.nextNode();
    try std.testing.expect(node3 == null);
}

test "NodeIterator - detach does nothing" {
    const allocator = std.testing.allocator;

    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer iterator.deinit();

    // detach() is a no-op
    iterator.detach();

    // Iterator still works after detach
    const node = try iterator.nextNode();
    try std.testing.expect(node == &root);
}

test "NodeIterator - attributes" {
    const allocator = std.testing.allocator;

    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    const filter = struct {
        fn callback(node: *Node) u16 {
            _ = node;
            return NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ELEMENT, filter, null);
    defer iterator.deinit();

    // Check attributes
    try std.testing.expect(iterator.get_root() == &root);
    try std.testing.expect(iterator.get_referenceNode() == &root);
    try std.testing.expect(iterator.get_pointerBeforeReferenceNode() == true);
    try std.testing.expect(iterator.get_whatToShow() == NodeFilter.SHOW_ELEMENT);
    try std.testing.expect(iterator.get_filter() == filter);
}

test "NodeIterator - nested tree traversal" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1 -> [grandchild], child2]
    var root = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer root.deinit();

    var child1 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer child1.deinit();
    try root.appendChild(&child1);

    var grandchild = try Node.init(allocator, Node.TEXT_NODE, "#text");
    defer grandchild.deinit();
    try child1.appendChild(&grandchild);

    var child2 = try Node.init(allocator, Node.ELEMENT_NODE, "element");
    defer child2.deinit();
    try root.appendChild(&child2);

    var iterator = try NodeIterator.init(allocator, &root, NodeFilter.SHOW_ALL, null, null);
    defer iterator.deinit();

    // Traverse in tree order: root, child1, grandchild, child2
    const n1 = try iterator.nextNode();
    try std.testing.expect(n1 == &root);

    const n2 = try iterator.nextNode();
    try std.testing.expect(n2 == &child1);

    const n3 = try iterator.nextNode();
    try std.testing.expect(n3 == &grandchild);

    const n4 = try iterator.nextNode();
    try std.testing.expect(n4 == &child2);

    const n5 = try iterator.nextNode();
    try std.testing.expect(n5 == null);
}
