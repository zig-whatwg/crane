const document = @import("document");
const std = @import("std");
const testing = std.testing;

// Import DOM types
const Document = @import("document").Document;
const Element = @import("element").Element;
const Text = @import("text").Text;
const Node = @import("node").Node;
const mutation = @import("mutation");

test "Move algorithm - basic element move" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent element
    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    // Create child elements
    const child1 = try doc_ptr.call_createElement("span");
    defer {
        child1.deinit();
        allocator.destroy(child1);
    }

    const child2 = try doc_ptr.call_createElement("p");
    defer {
        child2.deinit();
        allocator.destroy(child2);
    }

    const child3 = try doc_ptr.call_createElement("a");
    defer {
        child3.deinit();
        allocator.destroy(child3);
    }

    // Set up initial tree: parent -> [child1, child2, child3]
    const parent_node: *Node = @ptrCast(parent);
    const child1_node: *Node = @ptrCast(child1);
    const child2_node: *Node = @ptrCast(child2);
    const child3_node: *Node = @ptrCast(child3);

    _ = try parent_node.call_appendChild(child1_node);
    _ = try parent_node.call_appendChild(child2_node);
    _ = try parent_node.call_appendChild(child3_node);

    // Verify initial order
    try testing.expectEqual(@as(usize, 3), parent_node.child_nodes.size());
    try testing.expect(parent_node.child_nodes.items()[0] == child1_node);
    try testing.expect(parent_node.child_nodes.items()[1] == child2_node);
    try testing.expect(parent_node.child_nodes.items()[2] == child3_node);

    // Move child3 before child1
    try mutation.move(child3_node, parent_node, child1_node);

    // Verify new order: [child3, child1, child2]
    try testing.expectEqual(@as(usize, 3), parent_node.child_nodes.size());
    try testing.expect(parent_node.child_nodes.items()[0] == child3_node);
    try testing.expect(parent_node.child_nodes.items()[1] == child1_node);
    try testing.expect(parent_node.child_nodes.items()[2] == child2_node);

    // Verify parent relationships are intact
    try testing.expect(child1_node.parent_node == parent_node);
    try testing.expect(child2_node.parent_node == parent_node);
    try testing.expect(child3_node.parent_node == parent_node);
}

test "Move algorithm - move to end (child = null)" {
    const allocator = testing.allocator;

    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    const child1 = try doc_ptr.call_createElement("a");
    defer {
        child1.deinit();
        allocator.destroy(child1);
    }

    const child2 = try doc_ptr.call_createElement("b");
    defer {
        child2.deinit();
        allocator.destroy(child2);
    }

    const parent_node: *Node = @ptrCast(parent);
    const child1_node: *Node = @ptrCast(child1);
    const child2_node: *Node = @ptrCast(child2);

    _ = try parent_node.call_appendChild(child1_node);
    _ = try parent_node.call_appendChild(child2_node);

    // Move child1 to end (null reference)
    try mutation.move(child1_node, parent_node, null);

    // Verify order: [child2, child1]
    try testing.expectEqual(@as(usize, 2), parent_node.child_nodes.size());
    try testing.expect(parent_node.child_nodes.items()[0] == child2_node);
    try testing.expect(parent_node.child_nodes.items()[1] == child1_node);
}

test "Move algorithm - error: different shadow-including roots" {
    const allocator = testing.allocator;

    // Create two separate documents
    const doc1_ptr = try allocator.create(Document);
    defer allocator.destroy(doc1_ptr);
    doc1_ptr.* = try Document.init(allocator);
    defer doc1_ptr.deinit();

    const doc2_ptr = try allocator.create(Document);
    defer allocator.destroy(doc2_ptr);
    doc2_ptr.* = try Document.init(allocator);
    defer doc2_ptr.deinit();

    // Create elements in different documents
    const parent1 = try doc1_ptr.call_createElement("div");
    defer {
        parent1.deinit();
        allocator.destroy(parent1);
    }

    const child1 = try doc1_ptr.call_createElement("span");
    defer {
        child1.deinit();
        allocator.destroy(child1);
    }

    const parent2 = try doc2_ptr.call_createElement("div");
    defer {
        parent2.deinit();
        allocator.destroy(parent2);
    }

    const parent1_node: *Node = @ptrCast(parent1);
    const child1_node: *Node = @ptrCast(child1);
    const parent2_node: *Node = @ptrCast(parent2);

    _ = try parent1_node.call_appendChild(child1_node);

    // Try to move child from doc1 to parent in doc2 - should fail
    try testing.expectError(error.HierarchyRequestError, mutation.move(child1_node, parent2_node, null));
}

test "Move algorithm - error: node is ancestor of newParent" {
    const allocator = testing.allocator;

    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    const child = try doc_ptr.call_createElement("span");
    defer {
        child.deinit();
        allocator.destroy(child);
    }

    const grandchild = try doc_ptr.call_createElement("a");
    defer {
        grandchild.deinit();
        allocator.destroy(grandchild);
    }

    const parent_node: *Node = @ptrCast(parent);
    const child_node: *Node = @ptrCast(child);
    const grandchild_node: *Node = @ptrCast(grandchild);

    _ = try parent_node.call_appendChild(child_node);
    _ = try child_node.call_appendChild(grandchild_node);

    // Try to move parent into grandchild - should fail
    try testing.expectError(error.HierarchyRequestError, mutation.move(parent_node, grandchild_node, null));
}

test "Move algorithm - error: child not in newParent" {
    const allocator = testing.allocator;

    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const parent1 = try doc_ptr.call_createElement("div");
    defer {
        parent1.deinit();
        allocator.destroy(parent1);
    }

    const parent2 = try doc_ptr.call_createElement("div");
    defer {
        parent2.deinit();
        allocator.destroy(parent2);
    }

    const child1 = try doc_ptr.call_createElement("span");
    defer {
        child1.deinit();
        allocator.destroy(child1);
    }

    const child2 = try doc_ptr.call_createElement("a");
    defer {
        child2.deinit();
        allocator.destroy(child2);
    }

    const parent1_node: *Node = @ptrCast(parent1);
    const parent2_node: *Node = @ptrCast(parent2);
    const child1_node: *Node = @ptrCast(child1);
    const child2_node: *Node = @ptrCast(child2);

    _ = try parent1_node.call_appendChild(child1_node);
    _ = try parent2_node.call_appendChild(child2_node);

    // Try to move child1 into parent1 before child2 (which is in parent2) - should fail
    try testing.expectError(error.NotFoundError, mutation.move(child1_node, parent1_node, child2_node));
}

test "Move algorithm - error: node is not Element or CharacterData" {
    const allocator = testing.allocator;

    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    const parent_node: *Node = @ptrCast(parent);
    const doc_node: *Node = @ptrCast(doc_ptr);

    // Try to move document node - should fail (not Element or CharacterData)
    try testing.expectError(error.HierarchyRequestError, mutation.move(doc_node, parent_node, null));
}

test "Move algorithm - Text node move" {
    const allocator = testing.allocator;

    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    const text1 = try doc_ptr.call_createTextNode("Hello");
    defer {
        text1.deinit();
        allocator.destroy(text1);
    }

    const text2 = try doc_ptr.call_createTextNode("World");
    defer {
        text2.deinit();
        allocator.destroy(text2);
    }

    const parent_node: *Node = @ptrCast(parent);
    const text1_node: *Node = @ptrCast(text1);
    const text2_node: *Node = @ptrCast(text2);

    _ = try parent_node.call_appendChild(text1_node);
    _ = try parent_node.call_appendChild(text2_node);

    // Move text2 before text1
    try mutation.move(text2_node, parent_node, text1_node);

    // Verify order
    try testing.expectEqual(@as(usize, 2), parent_node.child_nodes.size());
    try testing.expect(parent_node.child_nodes.items()[0] == text2_node);
    try testing.expect(parent_node.child_nodes.items()[1] == text1_node);
}

test "ParentNode.moveBefore - basic usage" {
    const allocator = testing.allocator;

    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const parent = try doc_ptr.call_createElement("ul");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    const child1 = try doc_ptr.call_createElement("li");
    defer {
        child1.deinit();
        allocator.destroy(child1);
    }

    const child2 = try doc_ptr.call_createElement("li");
    defer {
        child2.deinit();
        allocator.destroy(child2);
    }

    const child3 = try doc_ptr.call_createElement("li");
    defer {
        child3.deinit();
        allocator.destroy(child3);
    }

    const parent_node: *Node = @ptrCast(parent);
    const child1_node: *Node = @ptrCast(child1);
    const child2_node: *Node = @ptrCast(child2);
    const child3_node: *Node = @ptrCast(child3);

    _ = try parent_node.call_appendChild(child1_node);
    _ = try parent_node.call_appendChild(child2_node);
    _ = try parent_node.call_appendChild(child3_node);

    // Use ParentNode.moveBefore to move child3 before child1
    try parent.call_moveBefore(child3, child1);

    // Verify order: [child3, child1, child2]
    try testing.expectEqual(@as(usize, 3), parent_node.child_nodes.size());
    try testing.expect(parent_node.child_nodes.items()[0] == child3_node);
    try testing.expect(parent_node.child_nodes.items()[1] == child1_node);
    try testing.expect(parent_node.child_nodes.items()[2] == child2_node);
}

test "ParentNode.moveBefore - reference is node (moves to next sibling)" {
    const allocator = testing.allocator;

    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    const child1 = try doc_ptr.call_createElement("a");
    defer {
        child1.deinit();
        allocator.destroy(child1);
    }

    const child2 = try doc_ptr.call_createElement("b");
    defer {
        child2.deinit();
        allocator.destroy(child2);
    }

    const child3 = try doc_ptr.call_createElement("c");
    defer {
        child3.deinit();
        allocator.destroy(child3);
    }

    const parent_node: *Node = @ptrCast(parent);
    const child1_node: *Node = @ptrCast(child1);
    const child2_node: *Node = @ptrCast(child2);
    const child3_node: *Node = @ptrCast(child3);

    _ = try parent_node.call_appendChild(child1_node);
    _ = try parent_node.call_appendChild(child2_node);
    _ = try parent_node.call_appendChild(child3_node);

    // Move child2 before itself - should move to next sibling (child3)
    try parent.call_moveBefore(child2, child2);

    // Verify order: [child1, child3, child2] or [child1, child2, child3] depending on implementation
    // Spec says: if referenceChild is node, set referenceChild to node's next sibling
    // So child2 moves before child3
    try testing.expectEqual(@as(usize, 3), parent_node.child_nodes.size());
    // The order should be: child1, child3, child2
    try testing.expect(parent_node.child_nodes.items()[0] == child1_node);
    try testing.expect(parent_node.child_nodes.items()[1] == child3_node);
    try testing.expect(parent_node.child_nodes.items()[2] == child2_node);
}
