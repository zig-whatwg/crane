//! Tests for Node Adoption Algorithm
//! Spec: https://dom.spec.whatwg.org/#concept-node-adopt (§4.2.2)

const std = @import("std");
const testing = std.testing;
const Document = @import("document").Document;
const Node = @import("node").Node;
const Element = @import("element").Element;
const Text = @import("text").Text;
const mutation = @import("dom").mutation;

test "adopt - node already in target document updates ownerDocument" {
    const allocator = testing.allocator;

    // Create document
    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Create element in document
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    const elem_node: *Node = @ptrCast(elem);

    // Set owner document
    elem_node.owner_document = doc;

    // Adopt to same document
    try mutation.adopt(elem_node, doc);

    // ownerDocument should still be doc
    try testing.expectEqual(doc, elem_node.owner_document.?);
}

test "adopt - node removed from old parent" {
    const allocator = testing.allocator;

    // Create two documents
    const doc1 = try allocator.create(Document);
    defer allocator.destroy(doc1);
    doc1.* = try Document.init(allocator);
    defer doc1.deinit();

    const doc2 = try allocator.create(Document);
    defer allocator.destroy(doc2);
    doc2.* = try Document.init(allocator);
    defer doc2.deinit();

    // Create parent element in doc1
    const parent = try doc1.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }
    const parent_node: *Node = @ptrCast(parent);

    // Create child element
    const child = try doc1.call_createElement("span");
    const child_node: *Node = @ptrCast(child);

    // Append child to parent
    _ = try parent_node.call_appendChild(child_node);

    // Verify child has parent
    try testing.expect(child_node.parent_node != null);
    try testing.expectEqual(parent_node, child_node.parent_node.?);

    // Adopt child to doc2
    try mutation.adopt(child_node, doc2);

    // Child should no longer have parent
    try testing.expect(child_node.parent_node == null);
    try testing.expectEqual(doc2, child_node.owner_document.?);

    // Cleanup child (now orphaned)
    child.deinit();
    allocator.destroy(child);
}

test "adopt - all descendants get new document" {
    const allocator = testing.allocator;

    // Create two documents
    const doc1 = try allocator.create(Document);
    defer allocator.destroy(doc1);
    doc1.* = try Document.init(allocator);
    defer doc1.deinit();

    const doc2 = try allocator.create(Document);
    defer allocator.destroy(doc2);
    doc2.* = try Document.init(allocator);
    defer doc2.deinit();

    // Create parent with nested children
    const parent = try doc1.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }
    const parent_node: *Node = @ptrCast(parent);
    parent_node.owner_document = doc1;

    const child1 = try doc1.call_createElement("span");
    const child1_node: *Node = @ptrCast(child1);
    child1_node.owner_document = doc1;
    _ = try parent_node.call_appendChild(child1_node);

    const child2 = try doc1.call_createElement("p");
    const child2_node: *Node = @ptrCast(child2);
    child2_node.owner_document = doc1;
    _ = try child1_node.call_appendChild(child2_node);

    // Adopt parent to doc2
    try mutation.adopt(parent_node, doc2);

    // All nodes should have doc2 as ownerDocument
    try testing.expectEqual(doc2, parent_node.owner_document.?);
    try testing.expectEqual(doc2, child1_node.owner_document.?);
    try testing.expectEqual(doc2, child2_node.owner_document.?);
}

test "adopt - text nodes adopt correctly" {
    const allocator = testing.allocator;

    // Create two documents
    const doc1 = try allocator.create(Document);
    defer allocator.destroy(doc1);
    doc1.* = try Document.init(allocator);
    defer doc1.deinit();

    const doc2 = try allocator.create(Document);
    defer allocator.destroy(doc2);
    doc2.* = try Document.init(allocator);
    defer doc2.deinit();

    // Create text node in doc1
    const text = try doc1.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }
    const text_node: *Node = @ptrCast(text);
    text_node.owner_document = doc1;

    // Adopt to doc2
    try mutation.adopt(text_node, doc2);

    // Text node should have doc2 as ownerDocument
    try testing.expectEqual(doc2, text_node.owner_document.?);
}

test "adopt - node with multiple children all updated" {
    const allocator = testing.allocator;

    // Create two documents
    const doc1 = try allocator.create(Document);
    defer allocator.destroy(doc1);
    doc1.* = try Document.init(allocator);
    defer doc1.deinit();

    const doc2 = try allocator.create(Document);
    defer allocator.destroy(doc2);
    doc2.* = try Document.init(allocator);
    defer doc2.deinit();

    // Create parent with multiple children
    const parent = try doc1.call_createElement("ul");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }
    const parent_node: *Node = @ptrCast(parent);
    parent_node.owner_document = doc1;

    // Add 3 list items
    const li1 = try doc1.call_createElement("li");
    const li1_node: *Node = @ptrCast(li1);
    li1_node.owner_document = doc1;
    _ = try parent_node.call_appendChild(li1_node);

    const li2 = try doc1.call_createElement("li");
    const li2_node: *Node = @ptrCast(li2);
    li2_node.owner_document = doc1;
    _ = try parent_node.call_appendChild(li2_node);

    const li3 = try doc1.call_createElement("li");
    const li3_node: *Node = @ptrCast(li3);
    li3_node.owner_document = doc1;
    _ = try parent_node.call_appendChild(li3_node);

    // Adopt parent to doc2
    try mutation.adopt(parent_node, doc2);

    // All nodes should have doc2 as ownerDocument
    try testing.expectEqual(doc2, parent_node.owner_document.?);
    try testing.expectEqual(doc2, li1_node.owner_document.?);
    try testing.expectEqual(doc2, li2_node.owner_document.?);
    try testing.expectEqual(doc2, li3_node.owner_document.?);
}
