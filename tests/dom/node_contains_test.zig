//! Tests for Node.contains() method
//! Spec: https://dom.spec.whatwg.org/#dom-node-contains

const std = @import("std");
const Node = @import("node").Node;
const infra = @import("infra");

test "Node.contains - self" {
    const allocator = std.testing.allocator;
    
    var node = try Node.init(allocator, 1, "test");
    defer node.deinit();
    
    // Node contains itself
    try std.testing.expect(node.call_contains(&node));
}

test "Node.contains - null returns false" {
    const allocator = std.testing.allocator;
    
    var node = try Node.init(allocator, 1, "test");
    defer node.deinit();
    
    // contains(null) returns false
    try std.testing.expect(!node.call_contains(null));
}

test "Node.contains - direct child" {
    const allocator = std.testing.allocator;
    
    var parent = try Node.init(allocator, 1, "parent");
    defer parent.deinit();
    
    var child = try Node.init(allocator, 1, "child");
    defer child.deinit();
    
    // Add child to parent
    try parent.child_nodes.append(&child);
    child.parent_node = &parent;
    
    // Parent contains child
    try std.testing.expect(parent.call_contains(&child));
    
    // Child does not contain parent
    try std.testing.expect(!child.call_contains(&parent));
}

test "Node.contains - descendant" {
    const allocator = std.testing.allocator;
    
    var grandparent = try Node.init(allocator, 1, "grandparent");
    defer grandparent.deinit();
    
    var parent = try Node.init(allocator, 1, "parent");
    defer parent.deinit();
    
    var child = try Node.init(allocator, 1, "child");
    defer child.deinit();
    
    // Build tree: grandparent > parent > child
    try grandparent.child_nodes.append(&parent);
    parent.parent_node = &grandparent;
    
    try parent.child_nodes.append(&child);
    child.parent_node = &parent;
    
    // Grandparent contains all descendants
    try std.testing.expect(grandparent.call_contains(&parent));
    try std.testing.expect(grandparent.call_contains(&child));
    
    // Parent contains child but not grandparent
    try std.testing.expect(parent.call_contains(&child));
    try std.testing.expect(!parent.call_contains(&grandparent));
    
    // Child contains only itself
    try std.testing.expect(!child.call_contains(&parent));
    try std.testing.expect(!child.call_contains(&grandparent));
}

test "Node.contains - unrelated nodes" {
    const allocator = std.testing.allocator;
    
    var node1 = try Node.init(allocator, 1, "node1");
    defer node1.deinit();
    
    var node2 = try Node.init(allocator, 1, "node2");
    defer node2.deinit();
    
    // Unrelated nodes don't contain each other
    try std.testing.expect(!node1.call_contains(&node2));
    try std.testing.expect(!node2.call_contains(&node1));
}
