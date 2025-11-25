//! Tests for Node.contains() method
//! Spec: https://dom.spec.whatwg.org/#dom-node-contains

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases - use NodeBase/ElementWithBase for internal testing
const NodeBase = dom.NodeBase;
const Element = dom.ElementWithBase;

test "Node.contains - self" {
    const allocator = std.testing.allocator;

    var elem = Element.init(allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // Node contains itself
    try std.testing.expect(node.contains(node));
}

test "Node.contains - null returns false" {
    const allocator = std.testing.allocator;

    var elem = Element.init(allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // contains(null) returns false
    try std.testing.expect(!node.contains(null));
}

test "Node.contains - direct child" {
    const allocator = std.testing.allocator;

    var parent_elem = Element.init(allocator, "div");
    defer parent_elem.deinit();

    var child_elem = Element.init(allocator, "span");
    defer child_elem.deinit();

    const parent = parent_elem.asNode();
    const child = child_elem.asNode();

    // Add child to parent
    try parent.child_nodes.append(child);
    child.parent_node = parent;

    // Parent contains child
    try std.testing.expect(parent.contains(child));

    // Child does not contain parent
    try std.testing.expect(!child.contains(parent));
}

test "Node.contains - descendant" {
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

    // Grandparent contains all descendants
    try std.testing.expect(grandparent.contains(parent));
    try std.testing.expect(grandparent.contains(child));

    // Parent contains child but not grandparent
    try std.testing.expect(parent.contains(child));
    try std.testing.expect(!parent.contains(grandparent));

    // Child contains only itself
    try std.testing.expect(!child.contains(parent));
    try std.testing.expect(!child.contains(grandparent));
}

test "Node.contains - unrelated nodes" {
    const allocator = std.testing.allocator;

    var elem1 = Element.init(allocator, "div");
    defer elem1.deinit();

    var elem2 = Element.init(allocator, "span");
    defer elem2.deinit();

    const node1 = elem1.asNode();
    const node2 = elem2.asNode();

    // Unrelated nodes don't contain each other
    try std.testing.expect(!node1.contains(node2));
    try std.testing.expect(!node2.contains(node1));
}
