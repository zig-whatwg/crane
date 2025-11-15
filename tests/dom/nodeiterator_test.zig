//! NodeIterator tests per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-nodeiterator

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Node = dom.Node;
const Element = dom.Element;
const Text = dom.Text;
const NodeIterator = dom.NodeIterator;
const NodeFilter = dom.NodeFilter;

test "NodeIterator - basic forward iteration" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [child1, child2, child3]
    var root = try Element.init(allocator, "div");
    defer root.deinit();

    var child1 = try Element.init(allocator, "span");
    defer child1.deinit();
    _ = try root.call_appendChild(@ptrCast(&child1));

    var child2 = try Text.init(allocator);
    defer child2.deinit();
    _ = try root.call_appendChild(@ptrCast(&child2));

    var child3 = try Element.init(allocator, "p");
    defer child3.deinit();
    _ = try root.call_appendChild(@ptrCast(&child3));

    // Create iterator showing all nodes
    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer iterator.deinit();

    // Iterator starts before root, so first nextNode() returns root
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == @as(*Node, @ptrCast(&root)));

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == @as(*Node, @ptrCast(&child1)));

    const node3 = try iterator.nextNode();
    try std.testing.expect(node3 == @as(*Node, @ptrCast(&child2)));

    const node4 = try iterator.nextNode();
    try std.testing.expect(node4 == @as(*Node, @ptrCast(&child3)));

    // No more nodes
    const node5 = try iterator.nextNode();
    try std.testing.expect(node5 == null);
}

test "NodeIterator - basic backward iteration" {
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

    // Create iterator
    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer iterator.deinit();

    // First call to previousNode() returns null (already before root)
    const node1 = try iterator.previousNode();
    try std.testing.expect(node1 == null);
}

test "NodeIterator - forward then backward" {
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

    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer iterator.deinit();

    // Go forward to child1
    _ = try iterator.nextNode(); // root
    const forward = try iterator.nextNode(); // child1
    try std.testing.expect(forward == @as(*Node, @ptrCast(&child1)));

    // Go backward
    const backward = try iterator.previousNode(); // back to root
    try std.testing.expect(backward == @as(*Node, @ptrCast(&root)));
}

test "NodeIterator - whatToShow SHOW_ELEMENT" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [element, text, element]
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

    // Iterator only shows elements
    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ELEMENT, null);
    defer iterator.deinit();

    // Should get root, element1, element2 (skipping text)
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == @as(*Node, @ptrCast(&root)));

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == @as(*Node, @ptrCast(&element1)));

    const node3 = try iterator.nextNode();
    try std.testing.expect(node3 == @as(*Node, @ptrCast(&element2)));

    const node4 = try iterator.nextNode();
    try std.testing.expect(node4 == null);
}

test "NodeIterator - whatToShow SHOW_TEXT" {
    const allocator = std.testing.allocator;

    // Create tree: root -> [element, text, element]
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

    // Iterator only shows text nodes
    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_TEXT, null);
    defer iterator.deinit();

    // Should get only text node
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == @as(*Node, @ptrCast(&text)));

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

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var child = try Text.init(allocator);
    defer child.deinit();
    _ = try root.call_appendChild(@ptrCast(&child));

    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, acceptAll);
    defer iterator.deinit();

    // Should iterate all nodes
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == @as(*Node, @ptrCast(&root)));

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == @as(*Node, @ptrCast(&child)));
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

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var text1 = try Text.init(allocator);
    defer text1.deinit();
    _ = try root.call_appendChild(@ptrCast(&text1));

    var element = try Element.init(allocator, "element");
    defer element.deinit();
    _ = try root.call_appendChild(@ptrCast(&element));

    var text2 = try Text.init(allocator);
    defer text2.deinit();
    _ = try root.call_appendChild(@ptrCast(&text2));

    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, skipText);
    defer iterator.deinit();

    // Should skip text nodes
    const node1 = try iterator.nextNode();
    try std.testing.expect(node1 == @as(*Node, @ptrCast(&root)));

    const node2 = try iterator.nextNode();
    try std.testing.expect(node2 == @as(*Node, @ptrCast(&element)));

    const node3 = try iterator.nextNode();
    try std.testing.expect(node3 == null);
}

test "NodeIterator - detach does nothing" {
    const allocator = std.testing.allocator;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer iterator.deinit();

    // detach() is a no-op
    iterator.detach();

    // Iterator still works after detach
    const node = try iterator.nextNode();
    try std.testing.expect(node == @as(*Node, @ptrCast(&root)));
}

test "NodeIterator - attributes" {
    const allocator = std.testing.allocator;

    var root = try Element.init(allocator, "element");
    defer root.deinit();

    const filter = struct {
        fn callback(node: *Node) u16 {
            _ = node;
            return NodeFilter.FILTER_ACCEPT;
        }
    }.callback;

    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ELEMENT, filter);
    defer iterator.deinit();

    // Check attributes
    try std.testing.expect(iterator.get_root() == @as(*Node, @ptrCast(&root)));
    try std.testing.expect(iterator.get_referenceNode() == @as(*Node, @ptrCast(&root)));
    try std.testing.expect(iterator.get_pointerBeforeReferenceNode() == true);
    try std.testing.expect(iterator.get_whatToShow() == NodeFilter.SHOW_ELEMENT);
    try std.testing.expect(iterator.get_filter() == filter);
}

test "NodeIterator - nested tree traversal" {
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

    var iterator = try NodeIterator.init(allocator, @ptrCast(&root), NodeFilter.SHOW_ALL, null);
    defer iterator.deinit();

    // Traverse in tree order: root, child1, grandchild, child2
    const n1 = try iterator.nextNode();
    try std.testing.expect(n1 == @as(*Node, @ptrCast(&root)));

    const n2 = try iterator.nextNode();
    try std.testing.expect(n2 == @as(*Node, @ptrCast(&child1)));

    const n3 = try iterator.nextNode();
    try std.testing.expect(n3 == @as(*Node, @ptrCast(&grandchild)));

    const n4 = try iterator.nextNode();
    try std.testing.expect(n4 == @as(*Node, @ptrCast(&child2)));

    const n5 = try iterator.nextNode();
    try std.testing.expect(n5 == null);
}
