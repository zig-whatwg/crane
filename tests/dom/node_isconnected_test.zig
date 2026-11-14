//! Tests for Node.isConnected property
//! Spec: https://dom.spec.whatwg.org/#dom-node-isconnected

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases - use NodeBase/ElementWithBase for internal testing
const NodeBase = dom.NodeBase;
const Element = dom.ElementWithBase;

/// Helper to create a mock document node for testing isConnected
fn createMockDocumentNode() NodeBase {
    return NodeBase{
        .owner = NodeBase.ownerless(&std.testing.allocator),
        .node_type = NodeBase.DOCUMENT_NODE,
        .parent_node = null,
    };
}

fn deinitMockDocument(doc: *NodeBase) void {
    // A node keeps no child list (lane perf2 batch 5): nothing to free.
    _ = doc;
}

/// Link `child` as `parent`'s last child (a node's children are its sibling
/// links: NodeBase.children; lane perf2 batch 5).
fn linkTestChild(parent: *NodeBase, child: *NodeBase) void {
    parent.linkChildBefore(child, null);
}

test "Node.isConnected - document node is connected" {
    var doc = createMockDocumentNode();
    defer deinitMockDocument(&doc);

    // Document is its own root, and root is a document, so it's connected
    try std.testing.expect(doc.isConnected());
}

test "Node.isConnected - detached element is not connected" {
    const allocator = std.testing.allocator;

    var elem = Element.init(&allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // Detached element's root is itself (an Element), not a Document
    try std.testing.expect(!node.isConnected());
}

test "Node.isConnected - element in document tree is connected" {
    const allocator = std.testing.allocator;

    var doc = createMockDocumentNode();
    defer deinitMockDocument(&doc);

    var elem = Element.init(&allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // Before connecting - not connected
    try std.testing.expect(!node.isConnected());

    // Connect element to document
    linkTestChild(&doc, node);
    node.parent_node = &doc;

    // Now element is connected
    try std.testing.expect(node.isConnected());
}

test "Node.isConnected - nested elements in document are connected" {
    const allocator = std.testing.allocator;

    var doc = createMockDocumentNode();
    defer deinitMockDocument(&doc);

    var parent_elem = Element.init(&allocator, "div");
    defer parent_elem.deinit();

    var child_elem = Element.init(&allocator, "span");
    defer child_elem.deinit();

    const parent = parent_elem.asNode();
    const child = child_elem.asNode();

    // Build tree: doc > parent > child
    linkTestChild(&doc, parent);
    parent.parent_node = &doc;

    linkTestChild(parent, child);
    child.parent_node = parent;

    // Both elements are connected via the document
    try std.testing.expect(parent.isConnected());
    try std.testing.expect(child.isConnected());
}

test "Node.isConnected - orphaned subtree is not connected" {
    const allocator = std.testing.allocator;

    var parent_elem = Element.init(&allocator, "div");
    defer parent_elem.deinit();

    var child_elem = Element.init(&allocator, "span");
    defer child_elem.deinit();

    const parent = parent_elem.asNode();
    const child = child_elem.asNode();

    // Build orphaned subtree: parent > child (no document)
    linkTestChild(parent, child);
    child.parent_node = parent;

    // Neither is connected (root is an Element, not a Document)
    try std.testing.expect(!parent.isConnected());
    try std.testing.expect(!child.isConnected());
}

test "Node.isConnected - deeply nested element in document" {
    const allocator = std.testing.allocator;

    var doc = createMockDocumentNode();
    defer deinitMockDocument(&doc);

    // Create a chain of 4 elements
    var elem0 = Element.init(&allocator, "html");
    defer elem0.deinit();

    var elem1 = Element.init(&allocator, "body");
    defer elem1.deinit();

    var elem2 = Element.init(&allocator, "div");
    defer elem2.deinit();

    var elem3 = Element.init(&allocator, "span");
    defer elem3.deinit();

    const n0 = elem0.asNode();
    const n1 = elem1.asNode();
    const n2 = elem2.asNode();
    const n3 = elem3.asNode();

    // Build tree: doc > n0 > n1 > n2 > n3
    linkTestChild(&doc, n0);
    n0.parent_node = &doc;

    linkTestChild(n0, n1);
    n1.parent_node = n0;

    linkTestChild(n1, n2);
    n2.parent_node = n1;

    linkTestChild(n2, n3);
    n3.parent_node = n2;

    // All elements are connected
    try std.testing.expect(n0.isConnected());
    try std.testing.expect(n1.isConnected());
    try std.testing.expect(n2.isConnected());
    try std.testing.expect(n3.isConnected());
}

test "Node.isConnected - document fragment root is not connected" {
    const allocator = std.testing.allocator;

    // Create a document fragment node
    var frag = NodeBase{
        .owner = NodeBase.ownerless(&std.testing.allocator),
        .node_type = NodeBase.DOCUMENT_FRAGMENT_NODE,
        .parent_node = null,
    };
    var elem = Element.init(&allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // Attach element to fragment
    linkTestChild(&frag, node);
    node.parent_node = &frag;

    // Fragment is not a document, so element is not connected
    try std.testing.expect(!frag.isConnected());
    try std.testing.expect(!node.isConnected());
}
