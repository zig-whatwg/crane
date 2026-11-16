//! Tests for Node.getRootNode() method
//! Spec: https://dom.spec.whatwg.org/#dom-node-getrootnode
//!
//! Real elements, linked by the DOM's own append (real_nodes.zig; lane wb1):
//! `NodeBase.getRoot` - src/dom's walk - and what script reads
//! (Node.getRootNode()) agree. They were ElementWithBase values linked by
//! hand.

const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const real_nodes = @import("real_nodes.zig");

const baseOf = real_nodes.baseOf;
const Instance = real_nodes.Instance;

/// `node`'s root, by src/dom's walk and by the interface.
fn expectRoot(expected: *Instance, node: *Instance) !void {
    try std.testing.expect(baseOf(node).getRoot() == baseOf(expected));
    try std.testing.expect((try interfaces.Node.call_getRootNode(node, .{})) == expected);
}

test "Node.getRoot - detached element is its own root" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const node = try nodes.element(try nodes.document(), "div");

    // Detached element is its own root
    try expectRoot(node, node);
}

test "Node.getRoot - child's root is parent (orphaned subtree)" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const parent = try nodes.element(doc, "div");
    const child = try nodes.element(doc, "span");

    // Build orphaned subtree: parent -> child
    try nodes.append(parent, child);

    // Child's root should be parent
    try expectRoot(parent, child);
}

test "Node.getRoot - nested elements" {
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

    // All nodes should have grandparent as root
    try expectRoot(grandparent, child);
    try expectRoot(grandparent, parent);
    try expectRoot(grandparent, grandparent);
}

test "Node.getRoot - deeply nested" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();

    // Create a chain of 5 elements: n0 > n1 > n2 > n3 > n4
    var chain: [5]*Instance = undefined;
    for (&chain, [_][]const u8{ "div", "section", "article", "p", "span" }) |*slot, name| slot.* = try nodes.element(doc, name);
    for (chain[0..4], chain[1..5]) |parent, child| try nodes.append(parent, child);

    // All should have n0 as root
    for (chain) |node| try expectRoot(chain[0], node);
}
