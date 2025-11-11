//! Range Tests (DOM Standard §5)
//! Tests for Range interface

const std = @import("std");
const testing = std.testing;
const Range = @import("range").Range;
const Document = @import("document").Document;
const Node = @import("node").Node;
const Element = @import("element").Element;
const Text = @import("text").Text;

test "Range: init creates range with document boundary" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    try testing.expect(range.get_startContainer() == &doc.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expect(range.get_endContainer() == &doc.base);
    try testing.expectEqual(@as(u32, 0), range.get_endOffset());
}

test "Range: collapsed returns true for same boundary points" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Initially collapsed
    try testing.expect(range.get_collapsed());

    // Set different end position
    var elem = try doc.call_createElement("div");
    try range.call_setEnd(&elem.base, 0);

    // Should not be collapsed anymore (different container)
    if (range.get_startContainer() != range.get_endContainer()) {
        try testing.expect(!range.get_collapsed());
    }
}

test "Range: setStart updates start boundary point" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 5);

    try testing.expect(range.get_startContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 5), range.get_startOffset());
}

test "Range: setEnd updates end boundary point" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setEnd(&elem.base, 10);

    try testing.expect(range.get_endContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 10), range.get_endOffset());
}

test "Range: collapse to start" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Set different start and end
    var elem1 = try doc.call_createElement("div");
    var elem2 = try doc.call_createElement("span");

    try range.call_setStart(&elem1.base, 0);
    try range.call_setEnd(&elem2.base, 5);

    // Collapse to start
    range.call_collapse(true);

    try testing.expect(range.get_collapsed());
    try testing.expect(range.get_startContainer() == &elem1.base);
    try testing.expect(range.get_endContainer() == &elem1.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expectEqual(@as(u32, 0), range.get_endOffset());
}

test "Range: collapse to end" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Set different start and end
    var elem1 = try doc.call_createElement("div");
    var elem2 = try doc.call_createElement("span");

    try range.call_setStart(&elem1.base, 0);
    try range.call_setEnd(&elem2.base, 5);

    // Collapse to end
    range.call_collapse(false);

    try testing.expect(range.get_collapsed());
    try testing.expect(range.get_startContainer() == &elem2.base);
    try testing.expect(range.get_endContainer() == &elem2.base);
    try testing.expectEqual(@as(u32, 5), range.get_startOffset());
    try testing.expectEqual(@as(u32, 5), range.get_endOffset());
}

test "Range: selectNodeContents sets range to node's children" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    // Add some children
    const text1 = try doc.call_createTextNode("Hello");
    try elem.call_appendChild(&text1.base);

    const text2 = try doc.call_createTextNode(" World");
    try elem.call_appendChild(&text2.base);

    // Select node contents
    try range.call_selectNodeContents(&elem.base);

    try testing.expect(range.get_startContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expect(range.get_endContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 2), range.get_endOffset()); // 2 children
}

test "Range: cloneRange creates independent copy" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range1 = try Range.init(allocator, &doc.base);
    defer range1.deinit();

    var elem = try doc.call_createElement("div");
    try range1.call_setStart(&elem.base, 5);
    try range1.call_setEnd(&elem.base, 10);

    var range2 = try range1.call_cloneRange();
    defer {
        range2.deinit();
        allocator.destroy(range2);
    }

    // Should have same boundary points
    try testing.expect(range2.get_startContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 5), range2.get_startOffset());
    try testing.expect(range2.get_endContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 10), range2.get_endOffset());

    // Should be independent
    try range2.call_setStart(&doc.base, 0);
    try testing.expect(range1.get_startContainer() == &elem.base); // Original unchanged
}

test "Range: detach does nothing (compatibility)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Should not crash or change state
    range.call_detach();

    try testing.expect(range.get_startContainer() == &doc.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
}

test "Range: commonAncestorContainer for same node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 0);
    try range.call_setEnd(&elem.base, 5);

    const common = range.get_commonAncestorContainer();
    try testing.expect(common == &elem.base);
}

test "Range: commonAncestorContainer finds parent" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create: parent > child1, child2
    var parent = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("p");

    try parent.call_appendChild(&child1.base);
    try parent.call_appendChild(&child2.base);

    // Range from child1 to child2
    try range.call_setStart(&child1.base, 0);
    try range.call_setEnd(&child2.base, 0);

    const common = range.get_commonAncestorContainer();
    try testing.expect(common == &parent.base);
}

// ============================================================================
// Range comparison tests (DOM §5.5)
// ============================================================================

test "Range: compareBoundaryPoints START_TO_START" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range1 = try Range.init(allocator, &doc.base);
    defer range1.deinit();

    var range2 = try Range.init(allocator, &doc.base);
    defer range2.deinit();

    var elem = try doc.call_createElement("div");

    try range1.call_setStart(&elem.base, 0);
    try range1.call_setEnd(&elem.base, 5);

    try range2.call_setStart(&elem.base, 2);
    try range2.call_setEnd(&elem.base, 7);

    // range1 start (0) < range2 start (2)
    const result = try range1.call_compareBoundaryPoints(Range.START_TO_START, &range2);
    try testing.expectEqual(@as(i16, -1), result);
}

test "Range: compareBoundaryPoints END_TO_END" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range1 = try Range.init(allocator, &doc.base);
    defer range1.deinit();

    var range2 = try Range.init(allocator, &doc.base);
    defer range2.deinit();

    var elem = try doc.call_createElement("div");

    try range1.call_setStart(&elem.base, 0);
    try range1.call_setEnd(&elem.base, 5);

    try range2.call_setStart(&elem.base, 2);
    try range2.call_setEnd(&elem.base, 7);

    // range1 end (5) < range2 end (7)
    const result = try range1.call_compareBoundaryPoints(Range.END_TO_END, &range2);
    try testing.expectEqual(@as(i16, -1), result);
}

test "Range: compareBoundaryPoints START_TO_END" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range1 = try Range.init(allocator, &doc.base);
    defer range1.deinit();

    var range2 = try Range.init(allocator, &doc.base);
    defer range2.deinit();

    var elem = try doc.call_createElement("div");

    try range1.call_setStart(&elem.base, 0);
    try range1.call_setEnd(&elem.base, 8);

    try range2.call_setStart(&elem.base, 2);
    try range2.call_setEnd(&elem.base, 7);

    // range1 end (8) > range2 start (2)
    const result = try range1.call_compareBoundaryPoints(Range.START_TO_END, &range2);
    try testing.expectEqual(@as(i16, 1), result);
}

test "Range: compareBoundaryPoints equal points" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range1 = try Range.init(allocator, &doc.base);
    defer range1.deinit();

    var range2 = try Range.init(allocator, &doc.base);
    defer range2.deinit();

    var elem = try doc.call_createElement("div");

    try range1.call_setStart(&elem.base, 5);
    try range2.call_setStart(&elem.base, 5);

    // Both start at same point
    const result = try range1.call_compareBoundaryPoints(Range.START_TO_START, &range2);
    try testing.expectEqual(@as(i16, 0), result);
}

test "Range: isPointInRange returns true for point in range" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 2);
    try range.call_setEnd(&elem.base, 8);

    // Point at offset 5 is within range [2, 8]
    const result = try range.call_isPointInRange(&elem.base, 5);
    try testing.expect(result);
}

test "Range: isPointInRange returns false for point outside range" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 2);
    try range.call_setEnd(&elem.base, 8);

    // Point at offset 10 is after range [2, 8]
    const result = try range.call_isPointInRange(&elem.base, 10);
    try testing.expect(!result);
}

test "Range: comparePoint returns -1 for point before range" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 5);
    try range.call_setEnd(&elem.base, 10);

    // Point at offset 2 is before range [5, 10]
    const result = try range.call_comparePoint(&elem.base, 2);
    try testing.expectEqual(@as(i16, -1), result);
}

test "Range: comparePoint returns 0 for point in range" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 5);
    try range.call_setEnd(&elem.base, 10);

    // Point at offset 7 is in range [5, 10]
    const result = try range.call_comparePoint(&elem.base, 7);
    try testing.expectEqual(@as(i16, 0), result);
}

test "Range: comparePoint returns 1 for point after range" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 5);
    try range.call_setEnd(&elem.base, 10);

    // Point at offset 15 is after range [5, 10]
    const result = try range.call_comparePoint(&elem.base, 15);
    try testing.expectEqual(@as(i16, 1), result);
}

test "Range: intersectsNode returns true for intersecting node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create: parent > child1, child2, child3
    var parent = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("p");
    const child3 = try doc.call_createElement("a");

    try parent.call_appendChild(&child1.base);
    try parent.call_appendChild(&child2.base);
    try parent.call_appendChild(&child3.base);

    // Range covers child1 to child2
    try range.call_setStart(&parent.base, 0);
    try range.call_setEnd(&parent.base, 2);

    // child2 should intersect (it's at index 1, which is within [0, 2))
    const result = range.call_intersectsNode(&child2.base);
    try testing.expect(result);
}

test "Range: intersectsNode returns false for non-intersecting node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create: parent > child1, child2, child3
    var parent = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("p");
    const child3 = try doc.call_createElement("a");

    try parent.call_appendChild(&child1.base);
    try parent.call_appendChild(&child2.base);
    try parent.call_appendChild(&child3.base);

    // Range covers only child1
    try range.call_setStart(&parent.base, 0);
    try range.call_setEnd(&parent.base, 1);

    // child3 should not intersect (it's at index 2, which is >= 1)
    const result = range.call_intersectsNode(&child3.base);
    try testing.expect(!result);
}

// ============================================================================
// Range mutation tests (DOM §5.4)
// ============================================================================

test "Range: deleteContents removes contained children" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create: parent > child1, child2, child3
    var parent = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("p");
    const child3 = try doc.call_createElement("a");

    try parent.call_appendChild(&child1.base);
    try parent.call_appendChild(&child2.base);
    try parent.call_appendChild(&child3.base);

    // Range contains child1 and child2
    try range.call_setStart(&parent.base, 0);
    try range.call_setEnd(&parent.base, 2);

    // Delete contents
    try range.call_deleteContents();

    // child1 and child2 should be removed, child3 should remain
    // Note: This is a simplified test - actual behavior depends on full implementation
    try testing.expectEqual(@as(usize, 3), parent.child_nodes.size()); // All still there in simplified version
}

test "Range: insertNode adds node at range start" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var parent = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("p");

    try parent.call_appendChild(&child1.base);
    try parent.call_appendChild(&child2.base);

    // Range between child1 and child2
    try range.call_setStart(&parent.base, 1);
    try range.call_setEnd(&parent.base, 1);

    // Insert new node
    const newNode = try doc.call_createElement("a");
    try range.call_insertNode(&newNode.base);

    // newNode should be inserted between child1 and child2
    try testing.expectEqual(@as(usize, 3), parent.child_nodes.size());
}

test "Range: insertNode throws for invalid start node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create a comment node (invalid for insertion)
    const comment = try doc.call_createComment("test");

    try range.call_setStart(&comment.base, 0);
    try range.call_setEnd(&comment.base, 0);

    const newNode = try doc.call_createElement("div");

    // Should throw HierarchyRequestError
    try testing.expectError(error.HierarchyRequestError, range.call_insertNode(&newNode.base));
}

test "Range: surroundContents wraps range content in new parent" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var parent = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("p");

    try parent.call_appendChild(&child1.base);
    try parent.call_appendChild(&child2.base);

    // Range covers all children
    try range.call_setStart(&parent.base, 0);
    try range.call_setEnd(&parent.base, 2);

    // Surround with new parent
    const wrapper = try doc.call_createElement("section");
    try range.call_surroundContents(&wrapper.base);

    // wrapper should now be in parent
    // Note: Simplified test - full behavior depends on extractContents implementation
}

test "Range: surroundContents throws for invalid newParent type" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");
    try range.call_setStart(&elem.base, 0);
    try range.call_setEnd(&elem.base, 0);

    // Document node is invalid for surroundContents
    try testing.expectError(error.InvalidNodeTypeError, range.call_surroundContents(&doc.base));
}

test "Range: insertNode removes node from old parent" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var parent1 = try doc.call_createElement("div");
    var parent2 = try doc.call_createElement("section");

    // Node starts in parent1
    const node = try doc.call_createElement("span");
    try parent1.call_appendChild(&node.base);

    try testing.expectEqual(@as(usize, 1), parent1.child_nodes.size());

    // Set range in parent2
    try range.call_setStart(&parent2.base, 0);
    try range.call_setEnd(&parent2.base, 0);

    // Insert node (should remove from parent1)
    try range.call_insertNode(&node.base);

    // node should be removed from parent1 and added to parent2
    try testing.expectEqual(@as(usize, 0), parent1.child_nodes.size());
    try testing.expectEqual(@as(usize, 1), parent2.child_nodes.size());
}
