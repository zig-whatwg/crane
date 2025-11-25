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
fn createMockDocumentNode(allocator: std.mem.Allocator) NodeBase {
    return NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
    };
}

fn deinitMockDocument(doc: *NodeBase) void {
    doc.child_nodes.deinit();
    doc.registered_observers.deinit();
}

test "Node.isConnected - document node is connected" {
    const allocator = std.testing.allocator;

    var doc = createMockDocumentNode(allocator);
    defer deinitMockDocument(&doc);

    // Document is its own root, and root is a document, so it's connected
    try std.testing.expect(doc.isConnected());
}

test "Node.isConnected - detached element is not connected" {
    const allocator = std.testing.allocator;

    var elem = Element.init(allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // Detached element's root is itself (an Element), not a Document
    try std.testing.expect(!node.isConnected());
}

test "Node.isConnected - element in document tree is connected" {
    const allocator = std.testing.allocator;

    var doc = createMockDocumentNode(allocator);
    defer deinitMockDocument(&doc);

    var elem = Element.init(allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // Before connecting - not connected
    try std.testing.expect(!node.isConnected());

    // Connect element to document
    try doc.child_nodes.append(node);
    node.parent_node = &doc;

    // Now element is connected
    try std.testing.expect(node.isConnected());
}

test "Node.isConnected - nested elements in document are connected" {
    const allocator = std.testing.allocator;

    var doc = createMockDocumentNode(allocator);
    defer deinitMockDocument(&doc);

    var parent_elem = Element.init(allocator, "div");
    defer parent_elem.deinit();

    var child_elem = Element.init(allocator, "span");
    defer child_elem.deinit();

    const parent = parent_elem.asNode();
    const child = child_elem.asNode();

    // Build tree: doc > parent > child
    try doc.child_nodes.append(parent);
    parent.parent_node = &doc;

    try parent.child_nodes.append(child);
    child.parent_node = parent;

    // Both elements are connected via the document
    try std.testing.expect(parent.isConnected());
    try std.testing.expect(child.isConnected());
}

test "Node.isConnected - orphaned subtree is not connected" {
    const allocator = std.testing.allocator;

    var parent_elem = Element.init(allocator, "div");
    defer parent_elem.deinit();

    var child_elem = Element.init(allocator, "span");
    defer child_elem.deinit();

    const parent = parent_elem.asNode();
    const child = child_elem.asNode();

    // Build orphaned subtree: parent > child (no document)
    try parent.child_nodes.append(child);
    child.parent_node = parent;

    // Neither is connected (root is an Element, not a Document)
    try std.testing.expect(!parent.isConnected());
    try std.testing.expect(!child.isConnected());
}

test "Node.isConnected - deeply nested element in document" {
    const allocator = std.testing.allocator;

    var doc = createMockDocumentNode(allocator);
    defer deinitMockDocument(&doc);

    // Create a chain of 4 elements
    var elem0 = Element.init(allocator, "html");
    defer elem0.deinit();

    var elem1 = Element.init(allocator, "body");
    defer elem1.deinit();

    var elem2 = Element.init(allocator, "div");
    defer elem2.deinit();

    var elem3 = Element.init(allocator, "span");
    defer elem3.deinit();

    const n0 = elem0.asNode();
    const n1 = elem1.asNode();
    const n2 = elem2.asNode();
    const n3 = elem3.asNode();

    // Build tree: doc > n0 > n1 > n2 > n3
    try doc.child_nodes.append(n0);
    n0.parent_node = &doc;

    try n0.child_nodes.append(n1);
    n1.parent_node = n0;

    try n1.child_nodes.append(n2);
    n2.parent_node = n1;

    try n2.child_nodes.append(n3);
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
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_FRAGMENT_NODE,
        .node_name = "#document-fragment",
        .parent_node = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
    };
    defer {
        frag.child_nodes.deinit();
        frag.registered_observers.deinit();
    }

    var elem = Element.init(allocator, "div");
    defer elem.deinit();

    const node = elem.asNode();

    // Attach element to fragment
    try frag.child_nodes.append(node);
    node.parent_node = &frag;

    // Fragment is not a document, so element is not connected
    try std.testing.expect(!frag.isConnected());
    try std.testing.expect(!node.isConnected());
}
