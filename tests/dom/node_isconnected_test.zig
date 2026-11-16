//! Tests for Node.isConnected property
//! Spec: https://dom.spec.whatwg.org/#dom-node-isconnected
//!
//! Real nodes, linked by the DOM's own append (real_nodes.zig; lane wb1):
//! the walk to the root (`NodeBase.isConnected`), the flag the insertion
//! steps keep (`NodeBase.is_connected`) and what script reads
//! (Node.isConnected) agree on every node. They were mock Document NodeBases
//! and ElementWithBase values linked by hand, which had no flag to compare.

const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const real_nodes = @import("real_nodes.zig");

const NodeBase = dom.NodeBase;
const baseOf = real_nodes.baseOf;

/// The three answers for one node.
fn expectConnected(expected: bool, node: *real_nodes.Instance) !void {
    const base = baseOf(node);
    try std.testing.expectEqual(expected, base.isConnected());
    try std.testing.expectEqual(expected, base.is_connected);
    try std.testing.expectEqual(expected, try interfaces.Node.get_isConnected(node));
}

test "Node.isConnected - document node is connected" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();

    // Document is its own root, and root is a document, so it's connected
    try std.testing.expect(baseOf(doc).isConnected());
    try std.testing.expect(try interfaces.Node.get_isConnected(doc));
}

test "Node.isConnected - detached element is not connected" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const elem = try nodes.element(doc, "div");

    // Detached element's root is itself (an Element), not a Document
    try expectConnected(false, elem);
}

test "Node.isConnected - element in document tree is connected" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const elem = try nodes.element(doc, "div");

    // Before connecting - not connected
    try expectConnected(false, elem);

    // Connect element to document
    try nodes.append(doc, elem);
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc)), baseOf(elem).parent_node);

    // Now element is connected
    try expectConnected(true, elem);
}

test "Node.isConnected - nested elements in document are connected" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const parent = try nodes.element(doc, "div");
    const child = try nodes.element(doc, "span");

    // Build tree: doc > parent > child
    try nodes.append(doc, parent);
    try nodes.append(parent, child);

    // Both elements are connected via the document
    try expectConnected(true, parent);
    try expectConnected(true, child);
}

test "Node.isConnected - orphaned subtree is not connected" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const parent = try nodes.element(doc, "div");
    const child = try nodes.element(doc, "span");

    // Build orphaned subtree: parent > child (no document above it)
    try nodes.append(parent, child);

    // Neither is connected (root is an Element, not a Document)
    try expectConnected(false, parent);
    try expectConnected(false, child);
}

test "Node.isConnected - deeply nested element in document" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();

    // Create a chain of 4 elements
    const n0 = try nodes.element(doc, "html");
    const n1 = try nodes.element(doc, "body");
    const n2 = try nodes.element(doc, "div");
    const n3 = try nodes.element(doc, "span");

    // Build tree: doc > n0 > n1 > n2 > n3
    try nodes.append(doc, n0);
    try nodes.append(n0, n1);
    try nodes.append(n1, n2);
    try nodes.append(n2, n3);

    // All elements are connected
    try expectConnected(true, n0);
    try expectConnected(true, n1);
    try expectConnected(true, n2);
    try expectConnected(true, n3);
}

test "Node.isConnected - document fragment root is not connected" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();

    // Create a document fragment node
    const frag = try nodes.fragment(doc);
    const elem = try nodes.element(doc, "div");

    // Attach element to fragment
    try nodes.append(frag, elem);

    // Fragment is not a document, so element is not connected
    try expectConnected(false, frag);
    try expectConnected(false, elem);
}
