//! Tests for Node.contains() method
//! Spec: https://dom.spec.whatwg.org/#dom-node-contains
//!
//! Real elements, linked by the DOM's own append (real_nodes.zig; lane wb1):
//! `NodeBase.contains` - src/dom's walk - and what script reads
//! (Node.contains) agree. They were ElementWithBase values linked by hand.

const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const real_nodes = @import("real_nodes.zig");

const baseOf = real_nodes.baseOf;
const Instance = real_nodes.Instance;

/// `node.contains(other)`, by src/dom's walk and by the interface.
fn expectContains(expected: bool, node: *Instance, other: ?*Instance) !void {
    try std.testing.expectEqual(expected, baseOf(node).contains(if (other) |o| baseOf(o) else null));
    try std.testing.expectEqual(expected, try interfaces.Node.call_contains(node, other));
}

test "Node.contains - self" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const node = try nodes.element(try nodes.document(), "div");

    // Node contains itself
    try expectContains(true, node, node);
}

test "Node.contains - null returns false" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const node = try nodes.element(try nodes.document(), "div");

    // contains(null) returns false
    try expectContains(false, node, null);
}

test "Node.contains - direct child" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const parent = try nodes.element(doc, "div");
    const child = try nodes.element(doc, "span");

    // Add child to parent
    try nodes.append(parent, child);

    // Parent contains child
    try expectContains(true, parent, child);

    // Child does not contain parent
    try expectContains(false, child, parent);
}

test "Node.contains - descendant" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const grandparent = try nodes.element(doc, "div");
    const parent = try nodes.element(doc, "section");
    const child = try nodes.element(doc, "span");

    // Build tree: grandparent > parent > child
    try nodes.append(grandparent, parent);
    try nodes.append(parent, child);

    // Grandparent contains all descendants
    try expectContains(true, grandparent, parent);
    try expectContains(true, grandparent, child);

    // Parent contains child but not grandparent
    try expectContains(true, parent, child);
    try expectContains(false, parent, grandparent);

    // Child contains only itself
    try expectContains(false, child, parent);
    try expectContains(false, child, grandparent);
}

test "Node.contains - unrelated nodes" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const node1 = try nodes.element(doc, "div");
    const node2 = try nodes.element(doc, "span");

    // Unrelated nodes don't contain each other
    try expectContains(false, node1, node2);
    try expectContains(false, node2, node1);
}
