//! Tests for DOM Mutation Algorithms
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-algorithms
//!
//! These tests verify that mutation algorithms follow the WHATWG DOM Standard
//! exactly, including error conditions and edge cases.
//!
//! The nodes are real ones (real_nodes.zig; lane wb1): documents, elements
//! and attribute nodes made through the generated interfaces, and src/dom's
//! algorithms called on their NodeBases. They were mock Document NodeBases
//! and the ElementWithBase / AttrWithBase types, which nothing in production
//! makes.

const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const real_nodes = @import("real_nodes.zig");

const NodeBase = dom.NodeBase;
const mutation = dom.mutation;
const baseOf = real_nodes.baseOf;
const str = real_nodes.str;

// ============================================================================
// node_document Tests (DOM §4.2.5)
// ============================================================================

test "NodeBase.getNodeDocument - Document node returns itself" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc_node = baseOf(try nodes.document());

    // Per spec: For Document nodes, getNodeDocument returns itself
    const node_doc = doc_node.getNodeDocument();
    try std.testing.expect(node_doc != null);
    // The returned pointer is the document node itself.
    try std.testing.expectEqual(doc_node, node_doc.?);
}

test "NodeBase.getNodeDocument - Element node returns owner_document" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const element = baseOf(try nodes.element(doc, "div"));

    // getNodeDocument should return the node document
    const node_doc = element.getNodeDocument();
    try std.testing.expect(node_doc != null);
    try std.testing.expectEqual(baseOf(doc), node_doc.?);
}

test "NodeBase.getNodeDocument - unattached node returns null" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    // An Element made with no node document.
    const element = try nodes.bare(.element);

    // Before being given a document, it names none
    try std.testing.expect(element.documentBase() == null);

    // getNodeDocument returns null for such a node
    const node_doc = element.getNodeDocument();
    try std.testing.expect(node_doc == null);
}

// ============================================================================
// adopt Algorithm Tests (DOM §4.2.5)
// ============================================================================

test "adopt - changes node_document for entire subtree" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc1 = try nodes.document();
    const doc2 = try nodes.document();

    // Create a parent element with a child
    const parent_instance = try nodes.element(doc1, "div");
    const child_instance = try nodes.element(doc1, "span");
    try nodes.append(parent_instance, child_instance);
    const parent = baseOf(parent_instance);
    const child = baseOf(child_instance);

    // Verify initial state
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc1)), parent.documentBase());
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc1)), child.documentBase());

    // Adopt parent into doc2
    try mutation.adopt(parent, baseOf(doc2));

    // Both parent AND child should now have doc2 as their node document
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc2)), parent.documentBase());
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc2)), child.documentBase());
    // And script reads the same document.
    try std.testing.expectEqual(@as(?*real_nodes.Instance, doc2), try interfaces.Node.get_ownerDocument(child_instance));
}

test "adopt - updates attribute node documents for elements" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc1 = try nodes.document();
    const doc2 = try nodes.document();

    // Create an element with an attribute, and the attribute's node (a
    // platform element makes an Attr node only when script asks for one).
    const element_instance = try nodes.element(doc1, "div");
    try nodes.setAttribute(element_instance, "id", "test");
    const attr_instance = (try interfaces.Element.call_getAttributeNode(element_instance, str("id"))).?;
    const element = baseOf(element_instance);
    const attr = baseOf(attr_instance);

    // Verify initial state
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc1)), element.documentBase());
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc1)), attr.documentBase());

    // Adopt element into doc2
    try mutation.adopt(element, baseOf(doc2));

    // Element AND its attribute should now have doc2 as their node document
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc2)), element.documentBase());
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc2)), attr.documentBase());
}

test "adopt - same document is a no-op" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();

    // Create an element already in the document
    const element = baseOf(try nodes.element(doc, "div"));

    // Adopt into the same document
    try mutation.adopt(element, baseOf(doc));

    // Should still have the same node document
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc)), element.documentBase());
}

// ============================================================================
// insert Algorithm Tests (DOM §4.2.5)
// ============================================================================

test "mutation - insert calls adopt before inserting" {
    // This test verifies that insert algorithm (step 7.1) calls adopt
    // to update the node's document to the parent's document
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();

    // Create a parent element in the document
    const parent = baseOf(try nodes.element(doc, "div"));

    // Create a child element NOT in any document
    const child = try nodes.bare(.element);

    // Verify initial state - child has no document
    try std.testing.expect(child.documentBase() == null);

    // Insert child into parent with the mutation module's insert
    try mutation.insert(child, parent, null, false);

    // After insertion, child should have been adopted into parent's document
    try std.testing.expectEqual(@as(?*NodeBase, baseOf(doc)), child.documentBase());
    try std.testing.expectEqual(@as(?*NodeBase, parent), child.parent_node);
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
