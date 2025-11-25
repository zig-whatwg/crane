//! Tests for Node.getRootNode / getRoot() method
//! Spec: https://dom.spec.whatwg.org/#dom-node-getrootnode

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases - use NodeBase/ElementWithBase for internal testing
const NodeBase = dom.NodeBase;
const Element = dom.ElementWithBase;

test "Node.getRoot - detached element is its own root" {
    const allocator = std.testing.allocator;

    var elem = Element.init(allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();
    const root = node.getRoot();

    // Detached element is its own root
    try std.testing.expect(root == node);
}

test "Node.getRoot - child's root is parent (orphaned subtree)" {
    const allocator = std.testing.allocator;

    var parent_elem = Element.init(allocator, "div");
    defer parent_elem.deinit();

    var child_elem = Element.init(allocator, "span");
    defer child_elem.deinit();

    const parent = parent_elem.asNode();
    const child = child_elem.asNode();

    // Build orphaned subtree: parent -> child
    try parent.child_nodes.append(child);
    child.parent_node = parent;

    const root = child.getRoot();

    // Child's root should be parent
    try std.testing.expect(root == parent);
}

test "Node.getRoot - nested elements" {
    const allocator = std.testing.allocator;

    var grandparent_elem = Element.init(allocator, "div");
    defer grandparent_elem.deinit();

    var parent_elem = Element.init(allocator, "section");
    defer parent_elem.deinit();

    var child_elem = Element.init(allocator, "span");
    defer child_elem.deinit();

    const grandparent = grandparent_elem.asNode();
    const parent = parent_elem.asNode();
    const child = child_elem.asNode();

    // Build tree: grandparent > parent > child
    try grandparent.child_nodes.append(parent);
    parent.parent_node = grandparent;

    try parent.child_nodes.append(child);
    child.parent_node = parent;

    // All nodes should have grandparent as root
    try std.testing.expect(child.getRoot() == grandparent);
    try std.testing.expect(parent.getRoot() == grandparent);
    try std.testing.expect(grandparent.getRoot() == grandparent);
}

test "Node.getRoot - deeply nested" {
    const allocator = std.testing.allocator;

    // Create a chain of 5 elements
    var elem0 = Element.init(allocator, "div");
    defer elem0.deinit();

    var elem1 = Element.init(allocator, "section");
    defer elem1.deinit();

    var elem2 = Element.init(allocator, "article");
    defer elem2.deinit();

    var elem3 = Element.init(allocator, "p");
    defer elem3.deinit();

    var elem4 = Element.init(allocator, "span");
    defer elem4.deinit();

    const n0 = elem0.asNode();
    const n1 = elem1.asNode();
    const n2 = elem2.asNode();
    const n3 = elem3.asNode();
    const n4 = elem4.asNode();

    // Chain: n0 > n1 > n2 > n3 > n4
    try n0.child_nodes.append(n1);
    n1.parent_node = n0;

    try n1.child_nodes.append(n2);
    n2.parent_node = n1;

    try n2.child_nodes.append(n3);
    n3.parent_node = n2;

    try n3.child_nodes.append(n4);
    n4.parent_node = n3;

    // All should have n0 as root
    try std.testing.expect(n4.getRoot() == n0);
    try std.testing.expect(n3.getRoot() == n0);
    try std.testing.expect(n2.getRoot() == n0);
    try std.testing.expect(n1.getRoot() == n0);
    try std.testing.expect(n0.getRoot() == n0);
}
