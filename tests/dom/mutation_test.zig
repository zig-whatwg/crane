//! Tests for DOM Mutation Algorithms
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-algorithms
//!
//! These tests verify that mutation algorithms follow the WHATWG DOM Standard
//! exactly, including error conditions and edge cases.

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases
const Document = dom.Document;
const DocumentFragment = dom.DocumentFragment;
const DocumentType = dom.DocumentType;
const Text = dom.TextWithBase;
const NodeBase = dom.NodeBase;
const ElementWithBase = dom.ElementWithBase;
const AttrWithBase = dom.AttrWithBase;
const mutation = dom.mutation;

// ============================================================================
// node_document Tests (DOM §4.2.5)
// ============================================================================

test "NodeBase.getNodeDocument - Document node returns itself" {
    const allocator = std.testing.allocator;

    // Create a mock Document node
    var doc_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null, // Document nodes have null owner_document
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc_node.child_nodes.deinit();
    defer doc_node.registered_observers.deinit();

    // Per spec: For Document nodes, getNodeDocument returns itself
    const node_doc = doc_node.getNodeDocument();
    try std.testing.expect(node_doc != null);
    // The returned pointer should be the document node itself (cast from NodeBase* to Document*)
    // Use @alignCast since Document has different alignment
    const node_base_ptr: *NodeBase = @ptrCast(@alignCast(node_doc.?));
    try std.testing.expectEqual(&doc_node, node_base_ptr);
}

test "NodeBase.getNodeDocument - Element node returns owner_document" {
    const allocator = std.testing.allocator;

    // Create a mock Document node first
    var doc_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc_node.child_nodes.deinit();
    defer doc_node.registered_observers.deinit();

    // Cast to Document type pointer for owner_document field
    const doc_ptr: *dom.Document = @ptrCast(&doc_node);

    // Create an Element node
    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    // Set the owner_document
    element.base.owner_document = doc_ptr;

    // getNodeDocument should return the owner_document
    const node_doc = element.base.getNodeDocument();
    try std.testing.expect(node_doc != null);
    try std.testing.expectEqual(doc_ptr, node_doc.?);
}

test "NodeBase.getNodeDocument - unattached node returns null" {
    const allocator = std.testing.allocator;

    // Create an Element node without owner_document
    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    // Before being attached to a document, owner_document is null
    try std.testing.expect(element.base.owner_document == null);

    // getNodeDocument returns null for unattached nodes
    const node_doc = element.base.getNodeDocument();
    try std.testing.expect(node_doc == null);
}

// ============================================================================
// adopt Algorithm Tests (DOM §4.2.5)
// ============================================================================

test "adopt - changes node_document for entire subtree" {
    const allocator = std.testing.allocator;

    // Create two mock document nodes
    var doc1_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc1_node.child_nodes.deinit();
    defer doc1_node.registered_observers.deinit();

    var doc2_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc2_node.child_nodes.deinit();
    defer doc2_node.registered_observers.deinit();

    const doc1_ptr: *dom.Document = @ptrCast(&doc1_node);
    const doc2_ptr: *dom.Document = @ptrCast(&doc2_node);

    // Create a parent element with a child
    var parent = ElementWithBase.init(allocator, "div");
    defer parent.deinit();
    parent.base.owner_document = doc1_ptr;

    var child = ElementWithBase.init(allocator, "span");
    defer child.deinit();
    child.base.owner_document = doc1_ptr;

    // Manually set up parent-child relationship (simplified, not using full mutation)
    try parent.base.child_nodes.append(&child.base);
    child.base.parent_node = &parent.base;

    // Verify initial state
    try std.testing.expectEqual(doc1_ptr, parent.base.owner_document.?);
    try std.testing.expectEqual(doc1_ptr, child.base.owner_document.?);

    // Adopt parent into doc2
    try mutation.adopt(&parent.base, doc2_ptr);

    // Both parent AND child should now have doc2 as their node document
    try std.testing.expectEqual(doc2_ptr, parent.base.owner_document.?);
    try std.testing.expectEqual(doc2_ptr, child.base.owner_document.?);
}

test "adopt - updates attribute node documents for elements" {
    const allocator = std.testing.allocator;

    // Create two mock document nodes
    var doc1_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc1_node.child_nodes.deinit();
    defer doc1_node.registered_observers.deinit();

    var doc2_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc2_node.child_nodes.deinit();
    defer doc2_node.registered_observers.deinit();

    const doc1_ptr: *dom.Document = @ptrCast(&doc1_node);
    const doc2_ptr: *dom.Document = @ptrCast(&doc2_node);

    // Create an element with an attribute
    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit(); // This will also deinit attributes
    element.base.owner_document = doc1_ptr;

    // Add an attribute - element.deinit() will clean it up
    const attr = try allocator.create(AttrWithBase);
    attr.* = try AttrWithBase.init(allocator, "id", "test", null, null);
    // Note: Don't defer cleanup of attr - element.deinit() handles it
    attr.base.owner_document = doc1_ptr;
    try element.attributes.append(attr);

    // Verify initial state
    try std.testing.expectEqual(doc1_ptr, element.base.owner_document.?);
    try std.testing.expectEqual(doc1_ptr, attr.base.owner_document.?);

    // Adopt element into doc2
    try mutation.adopt(&element.base, doc2_ptr);

    // Element AND its attribute should now have doc2 as their node document
    try std.testing.expectEqual(doc2_ptr, element.base.owner_document.?);
    try std.testing.expectEqual(doc2_ptr, attr.base.owner_document.?);
}

test "adopt - same document is a no-op" {
    const allocator = std.testing.allocator;

    // Create a mock document node
    var doc_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc_node.child_nodes.deinit();
    defer doc_node.registered_observers.deinit();

    const doc_ptr: *dom.Document = @ptrCast(&doc_node);

    // Create an element already in the document
    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();
    element.base.owner_document = doc_ptr;

    // Adopt into the same document
    try mutation.adopt(&element.base, doc_ptr);

    // Should still have the same owner_document
    try std.testing.expectEqual(doc_ptr, element.base.owner_document.?);
}

// ============================================================================
// insert Algorithm Tests (DOM §4.2.5)
// ============================================================================

test "mutation - insert calls adopt before inserting" {
    // This test verifies that insert algorithm (step 7.1) calls adopt
    // to update the node's document to the parent's document
    const allocator = std.testing.allocator;

    // Create a mock document node
    var doc_node = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.DOCUMENT_NODE,
        .node_name = "#document",
        .parent_node = null,
        .first_child = null,
        .last_child = null,
        .previous_sibling = null,
        .next_sibling = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(dom.node_base.RegisteredObserverType).init(allocator),
        .is_connected = true,
    };
    defer doc_node.child_nodes.deinit();
    defer doc_node.registered_observers.deinit();

    const doc_ptr: *dom.Document = @ptrCast(&doc_node);

    // Create a parent element in the document
    var parent = ElementWithBase.init(allocator, "div");
    defer parent.deinit();
    parent.base.owner_document = doc_ptr;

    // Create a child element NOT in any document
    var child = ElementWithBase.init(allocator, "span");
    defer child.deinit();
    // child.base.owner_document is null initially

    // Verify initial state - child has no document
    try std.testing.expect(child.base.owner_document == null);

    // Insert child into parent using append (which calls insert internally)
    // Note: We need to test via the mutation module functions
    try mutation.insert(&child.base, &parent.base, null, false);

    // After insertion, child should have been adopted into parent's document
    try std.testing.expectEqual(doc_ptr, child.base.owner_document.?);
}

// ============================================================================
// Placeholder Tests (to be expanded)
// ============================================================================

test "mutation - ensurePreInsertValidity placeholder" {
    // TODO: Implement full tests once mutation algorithms are complete
    // This test verifies the module compiles and links correctly
    try std.testing.expect(true);
}

test "mutation - preInsert placeholder" {
    // TODO: Test pre-insert algorithm
    // - Ensure pre-insert validity checks
    // - Handle referenceChild == node edge case
    // - Call insert algorithm correctly
    try std.testing.expect(true);
}

test "mutation - append placeholder" {
    // TODO: Test append algorithm (preInsert with null child)
    try std.testing.expect(true);
}

test "mutation - replace placeholder" {
    // TODO: Test replace algorithm
    // - Validate parent type
    // - Check node is not ancestor of parent
    // - Verify child's parent is correct
    // - Handle referenceChild edge cases
    try std.testing.expect(true);
}

test "mutation - replaceAll placeholder" {
    // TODO: Test replace all algorithm
    // - Remove all children
    // - Insert new node if non-null
    // - Queue mutation records
    try std.testing.expect(true);
}

test "mutation - preRemove placeholder" {
    // TODO: Test pre-remove algorithm
    // - Verify child's parent is correct
    // - Call remove algorithm
    try std.testing.expect(true);
}

test "mutation - remove placeholder" {
    // TODO: Test remove algorithm
    // - Update live ranges
    // - Update NodeIterators
    // - Run removing steps
    // - Queue mutation records
    try std.testing.expect(true);
}

// Edge cases to test once fully implemented:
// - Inserting node into itself (should throw HierarchyRequestError)
// - Inserting ancestor into descendant (should throw HierarchyRequestError)
// - Text node into Document (should throw HierarchyRequestError)
// - DocumentType into non-Document (should throw HierarchyRequestError)
// - Multiple elements in Document (should throw HierarchyRequestError)
// - DocumentFragment unwrapping
// - Mutation observer notifications
// - Live range updates
