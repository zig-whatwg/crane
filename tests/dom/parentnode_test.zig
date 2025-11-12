// DOM Standard: ParentNode mixin tests
// Spec: https://dom.spec.whatwg.org/#interface-parentnode

const std = @import("std");
const testing = std.testing;

// NOTE: These are placeholder tests. Full implementation requires:
// - Complete Element implementation
// - Complete HTMLCollection implementation
// - Complete NodeList implementation
// - Text node creation for string conversion
// - DocumentFragment creation for multi-node insertion

// ============================================================================
// Element Child Navigation Tests
// ============================================================================

test "ParentNode - children attribute returns HTMLCollection" {
    const allocator = testing.allocator;
    const Document = @import("document").Document;
    const Node = @import("node").Node;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // 1. Create parent element
    const parent = try doc.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    // 2. Append multiple child elements and non-elements
    const elem1 = try doc.call_createElement("span");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }

    const text = try doc.call_createTextNode("text content");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    const elem2 = try doc.call_createElement("p");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }

    const comment = try doc.call_createComment("comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    const elem3 = try doc.call_createElement("div");
    defer {
        elem3.deinit();
        allocator.destroy(elem3);
    }

    const parent_node: *Node = @ptrCast(parent);
    _ = try parent_node.call_appendChild(@as(*Node, @ptrCast(elem1)));
    _ = try parent_node.call_appendChild(@as(*Node, @ptrCast(text)));
    _ = try parent_node.call_appendChild(@as(*Node, @ptrCast(elem2)));
    _ = try parent_node.call_appendChild(@as(*Node, @ptrCast(comment)));
    _ = try parent_node.call_appendChild(@as(*Node, @ptrCast(elem3)));

    // 3. Call parent.children
    const children = try parent.get_children();
    defer {
        children.deinit();
        allocator.destroy(children);
    }

    // 4. Verify HTMLCollection contains only element children
    try testing.expectEqual(@as(u32, 3), children.get_length());

    // 5. Verify elements are in correct order (elem1, elem2, elem3)
    try testing.expectEqual(elem1, children.call_item(0).?);
    try testing.expectEqual(elem2, children.call_item(1).?);
    try testing.expectEqual(elem3, children.call_item(2).?);

    // 6. Verify non-elements (text, comment) not included
    // Already verified by length == 3 (not 5)
}

test "ParentNode - children returns empty HTMLCollection when no elements" {
    const allocator = testing.allocator;
    const Document = @import("document").Document;
    const Node = @import("node").Node;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const parent = try doc.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    // Add only non-element children
    const text = try doc.call_createTextNode("text");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    const comment = try doc.call_createComment("comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    const parent_node: *Node = @ptrCast(parent);
    _ = try parent_node.call_appendChild(@as(*Node, @ptrCast(text)));
    _ = try parent_node.call_appendChild(@as(*Node, @ptrCast(comment)));

    // Get children
    const children = try parent.get_children();
    defer {
        children.deinit();
        allocator.destroy(children);
    }

    // Should be empty (no element children)
    try testing.expectEqual(@as(u32, 0), children.get_length());
}

test "ParentNode - firstElementChild with element children" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append text node (non-element)
    // 3. Append element1
    // 4. Append element2
    // 5. Call parent.firstElementChild
    // 6. Verify returns element1 (skipping text node)
}

test "ParentNode - firstElementChild returns null when no elements" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append only text and comment nodes (no elements)
    // 3. Call parent.firstElementChild
    // 4. Verify returns null
}

test "ParentNode - lastElementChild with element children" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append element1
    // 3. Append element2
    // 4. Append text node (non-element)
    // 5. Call parent.lastElementChild
    // 6. Verify returns element2 (skipping text node)
}

test "ParentNode - lastElementChild returns null when no elements" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append only text and comment nodes (no elements)
    // 3. Call parent.lastElementChild
    // 4. Verify returns null
}

test "ParentNode - childElementCount counts only elements" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append: text, element1, comment, element2, text, element3
    // 3. Call parent.childElementCount
    // 4. Verify returns 3 (only elements counted)
}

test "ParentNode - childElementCount returns 0 for no elements" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Append only text and comment nodes
    // 3. Call parent.childElementCount
    // 4. Verify returns 0
}

// ============================================================================
// Prepend/Append/ReplaceChildren Tests
// ============================================================================

test "ParentNode - prepend() with single node" {
    // TODO: Implement test
    // 1. Create parent with existing children
    // 2. Create new node
    // 3. Call parent.prepend(new_node)
    // 4. Verify new_node is first child
    // 5. Verify existing children shifted
}

test "ParentNode - prepend() with multiple nodes" {
    // TODO: Implement test
    // 1. Create parent with existing children
    // 2. Call parent.prepend(node1, node2, node3)
    // 3. Verify all nodes prepended in order
    // 4. Verify existing children preserved
}

test "ParentNode - prepend() with string (converted to Text)" {
    // TODO: Implement test
    // Per spec: strings replaced with Text nodes
    // 1. Create parent element
    // 2. Call parent.prepend("text content")
    // 3. Verify Text node created with string content
    // 4. Verify Text node is first child
}

test "ParentNode - append() with single node" {
    // TODO: Implement test
    // 1. Create parent with existing children
    // 2. Create new node
    // 3. Call parent.append(new_node)
    // 4. Verify new_node is last child
    // 5. Verify existing children preserved
}

test "ParentNode - append() with multiple nodes" {
    // TODO: Implement test
    // 1. Create parent with existing children
    // 2. Call parent.append(node1, node2, node3)
    // 3. Verify all nodes appended in order
    // 4. Verify existing children preserved
}

test "ParentNode - append() with string (converted to Text)" {
    // TODO: Implement test
    // Per spec: strings replaced with Text nodes
    // 1. Create parent element
    // 2. Call parent.append("text content")
    // 3. Verify Text node created with string content
    // 4. Verify Text node is last child
}

test "ParentNode - replaceChildren() replaces all children" {
    // TODO: Implement test
    // 1. Create parent with existing children
    // 2. Call parent.replaceChildren(node1, node2)
    // 3. Verify all old children removed
    // 4. Verify only new children present
    // 5. Verify new children in correct order
}

test "ParentNode - replaceChildren() with empty args clears all" {
    // TODO: Implement test
    // 1. Create parent with existing children
    // 2. Call parent.replaceChildren() (no arguments)
    // 3. Verify all children removed
    // 4. Verify parent has no children
}

test "ParentNode - replaceChildren() with strings" {
    // TODO: Implement test
    // Per spec: strings replaced with Text nodes
    // 1. Create parent with existing children
    // 2. Call parent.replaceChildren("text1", "text2")
    // 3. Verify old children removed
    // 4. Verify Text nodes created for strings
}

// ============================================================================
// MoveBefore Tests
// ============================================================================

test "ParentNode - moveBefore() moves node to new position" {
    // TODO: Implement test
    // Per spec: Moves without first removing, preserves state
    // 1. Create parent with children: [child1, child2, child3]
    // 2. Call parent.moveBefore(child3, child2)
    // 3. Verify order is now: [child1, child3, child2]
    // 4. Verify state preserved (no removal/re-insertion)
}

test "ParentNode - moveBefore() with null child (moves to end)" {
    // TODO: Implement test
    // Per spec: null child means move to end
    // 1. Create parent with children: [child1, child2, child3]
    // 2. Call parent.moveBefore(child1, null)
    // 3. Verify order is now: [child2, child3, child1]
}

test "ParentNode - moveBefore() with referenceChild same as node" {
    // TODO: Implement test
    // Per spec step 2: If referenceChild is node, adjust to node's next sibling
    // 1. Create parent with children: [child1, child2, child3]
    // 2. Call parent.moveBefore(child2, child2)
    // 3. Verify no change (node stays in same position)
}

test "ParentNode - moveBefore() moves from different parent" {
    // TODO: Implement test
    // 1. Create parent1 with child
    // 2. Create parent2 with children
    // 3. Call parent2.moveBefore(parent1_child, some_child)
    // 4. Verify child moved from parent1 to parent2
    // 5. Verify state preserved
}

// ============================================================================
// QuerySelector Tests (using Selectors mock)
// ============================================================================

test "ParentNode - querySelector() returns first match" {
    // TODO: Implement test
    // Uses Selectors mock (basic support)
    // 1. Create parent with multiple matching elements
    // 2. Call parent.querySelector("div")
    // 3. Verify returns first matching element (tree order)
}

test "ParentNode - querySelector() returns null when no match" {
    // TODO: Implement test
    // 1. Create parent with elements
    // 2. Call parent.querySelector("nonexistent")
    // 3. Verify returns null
}

test "ParentNode - querySelector() throws SyntaxError on invalid selector" {
    // TODO: Implement test
    // Per spec step 2: throw SyntaxError if parse fails
    // 1. Create parent element
    // 2. Call parent.querySelector("!!!invalid")
    // 3. Verify SyntaxError thrown
}

test "ParentNode - querySelector() with ID selector" {
    // TODO: Implement test
    // Selectors mock supports #id
    // 1. Create parent with child having id="myId"
    // 2. Call parent.querySelector("#myId")
    // 3. Verify returns correct element
}

test "ParentNode - querySelector() with class selector" {
    // TODO: Implement test
    // Selectors mock supports .class
    // 1. Create parent with child having class="myClass"
    // 2. Call parent.querySelector(".myClass")
    // 3. Verify returns correct element
}

test "ParentNode - querySelectorAll() returns all matches" {
    // TODO: Implement test
    // 1. Create parent with multiple matching elements
    // 2. Call parent.querySelectorAll("div")
    // 3. Verify returns NodeList with all matches
    // 4. Verify elements in tree order
}

test "ParentNode - querySelectorAll() returns empty list when no match" {
    // TODO: Implement test
    // 1. Create parent with elements
    // 2. Call parent.querySelectorAll("nonexistent")
    // 3. Verify returns empty NodeList
}

test "ParentNode - querySelectorAll() throws SyntaxError on invalid selector" {
    // TODO: Implement test
    // 1. Create parent element
    // 2. Call parent.querySelectorAll("!!!invalid")
    // 3. Verify SyntaxError thrown
}

test "ParentNode - querySelectorAll() with universal selector" {
    // TODO: Implement test
    // Selectors mock supports *
    // 1. Create parent with multiple children
    // 2. Call parent.querySelectorAll("*")
    // 3. Verify returns all element descendants
}

// ============================================================================
// Convert Nodes Into Node Helper Tests
// ============================================================================

test "ParentNode - convertNodesIntoNode with single node" {
    // TODO: Implement test
    // Per spec step 3: If single node, return it
    // 1. Call convertNodesIntoNode([node])
    // 2. Verify returns the node (not wrapped)
}

test "ParentNode - convertNodesIntoNode with multiple nodes" {
    // TODO: Implement test
    // Per spec step 4: Create DocumentFragment, append all
    // 1. Call convertNodesIntoNode([node1, node2, node3])
    // 2. Verify returns DocumentFragment
    // 3. Verify all nodes appended to fragment
}

test "ParentNode - convertNodesIntoNode with string" {
    // TODO: Implement test
    // Per spec step 2: Replace strings with Text nodes
    // 1. Call convertNodesIntoNode(["text content"])
    // 2. Verify returns Text node with string data
}

test "ParentNode - convertNodesIntoNode with mixed nodes and strings" {
    // TODO: Implement test
    // 1. Call convertNodesIntoNode([node1, "text", node2])
    // 2. Verify returns DocumentFragment
    // 3. Verify string converted to Text node
    // 4. Verify all nodes in correct order
}

// ============================================================================
// Mixin Inclusion Tests
// ============================================================================

test "ParentNode - Document includes ParentNode" {
    // TODO: Verify Document has ParentNode members
    // 1. Create Document
    // 2. Verify .children exists
    // 3. Verify .prepend() exists
    // 4. Verify .querySelector() exists
}

test "ParentNode - DocumentFragment includes ParentNode" {
    // TODO: Verify DocumentFragment has ParentNode members
    // 1. Create DocumentFragment
    // 2. Verify .children exists
    // 3. Verify .prepend() exists
    // 4. Verify .querySelector() exists
}

test "ParentNode - Element includes ParentNode" {
    // TODO: Verify Element has ParentNode members
    // 1. Create Element
    // 2. Verify .children exists
    // 3. Verify .prepend() exists
    // 4. Verify .querySelector() exists
}

// ============================================================================
// HierarchyRequestError Tests
// ============================================================================

test "ParentNode - prepend() throws HierarchyRequestError on invalid insertion" {
    // TODO: Implement test
    // 1. Create invalid hierarchy (e.g., insert parent into child)
    // 2. Call prepend() with invalid structure
    // 3. Verify HierarchyRequestError thrown
    // 4. Verify tree unchanged
}

test "ParentNode - append() throws HierarchyRequestError on invalid insertion" {
    // TODO: Implement test
    // Similar to prepend test
}

test "ParentNode - replaceChildren() throws HierarchyRequestError on invalid insertion" {
    // TODO: Implement test
    // Per spec step 2: Ensure pre-insert validity
    // 1. Create invalid hierarchy
    // 2. Call replaceChildren() with invalid structure
    // 3. Verify HierarchyRequestError thrown
    // 4. Verify existing children preserved (operation failed)
}
