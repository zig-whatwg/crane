const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");


// Type aliases
const Document = dom.Document;
const Node = dom.Node;
const Range = dom.Range;

const testing = std.testing;

test "Range tracking - per-document isolation" {
    const allocator = testing.allocator;

    // Import types

    // Create two documents
    const doc1_ptr = try allocator.create(Document);
    defer allocator.destroy(doc1_ptr);
    doc1_ptr.* = try Document.init(allocator);
    defer doc1_ptr.deinit();

    const doc2_ptr = try allocator.create(Document);
    defer allocator.destroy(doc2_ptr);
    doc2_ptr.* = try Document.init(allocator);
    defer doc2_ptr.deinit();

    // Get Node pointers
    const doc1_node: *Node = @ptrCast(doc1_ptr);
    const doc2_node: *Node = @ptrCast(doc2_ptr);

    // Set up node types
    doc1_node.node_type = Node.DOCUMENT_NODE;
    doc2_node.node_type = Node.DOCUMENT_NODE;

    // Create ranges for each document
    const range1 = try allocator.create(Range);
    defer allocator.destroy(range1);
    range1.* = try Range.init(allocator, doc1_node);
    defer range1.deinit();
    try range1.registerWithDocument();

    const range2 = try allocator.create(Range);
    defer allocator.destroy(range2);
    range2.* = try Range.init(allocator, doc2_node);
    defer range2.deinit();
    try range2.registerWithDocument();

    // Verify each document tracks its own ranges
    try testing.expectEqual(@as(usize, 1), doc1_ptr.ranges.toSlice().len);
    try testing.expectEqual(@as(usize, 1), doc2_ptr.ranges.toSlice().len);
    try testing.expect(doc1_ptr.ranges.toSlice()[0] == range1);
    try testing.expect(doc2_ptr.ranges.toSlice()[0] == range2);
}

test "Range tracking - auto unregister on deinit" {
    const allocator = testing.allocator;


    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const doc_node: *Node = @ptrCast(doc_ptr);
    doc_node.node_type = Node.DOCUMENT_NODE;

    // Create and register range
    {
        const range = try allocator.create(Range);
        range.* = try Range.init(allocator, doc_node);
        try range.registerWithDocument();

        // Verify registered
        try testing.expectEqual(@as(usize, 1), doc_ptr.ranges.toSlice().len);

        // Deinit should auto-unregister
        range.deinit();
        allocator.destroy(range);
    }

    // Verify unregistered
    try testing.expectEqual(@as(usize, 0), doc_ptr.ranges.toSlice().len);
}

test "Range tracking - replaceData updates range offsets" {
    const allocator = testing.allocator;


    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const doc_node: *Node = @ptrCast(doc_ptr);
    doc_node.node_type = Node.DOCUMENT_NODE;

    // Create a text node with data
    const text = try doc_ptr.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }
    const text_node: *Node = @ptrCast(text);

    // Create range selecting "World" (offset 6-11)
    const range = try allocator.create(Range);
    defer allocator.destroy(range);
    range.* = try Range.init(allocator, doc_node);
    defer range.deinit();
    try range.registerWithDocument();
    try range.call_setStart(text_node, 6);
    try range.call_setEnd(text_node, 11);

    // Replace "Hello " with "Hi " (offset 0, count 6, data "Hi ")
    // This should adjust range offsets
    try text.call_replaceData(0, 6, "Hi ");

    // Range start should be adjusted from 6 to 3 (decreased by 3: old_length=6, new_length=3)
    // Range end should be adjusted from 11 to 8
    try testing.expectEqual(@as(u32, 3), range.start_offset);
    try testing.expectEqual(@as(u32, 8), range.end_offset);
    try testing.expectEqual(text_node, range.start_container);
    try testing.expectEqual(text_node, range.end_container);
}

test "Range tracking - replaceData collapses range within replaced region" {
    const allocator = testing.allocator;


    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const doc_node: *Node = @ptrCast(doc_ptr);
    doc_node.node_type = Node.DOCUMENT_NODE;

    // Create a text node
    const text = try doc_ptr.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }
    const text_node: *Node = @ptrCast(text);

    // Create range within the region to be replaced (offset 2-4)
    const range = try allocator.create(Range);
    defer allocator.destroy(range);
    range.* = try Range.init(allocator, doc_node);
    defer range.deinit();
    try range.registerWithDocument();
    try range.call_setStart(text_node, 2);
    try range.call_setEnd(text_node, 4);

    // Replace region containing the range (offset 0, count 6)
    try text.call_replaceData(0, 6, "Hi");

    // Both start and end should collapse to offset 0 (the replacement point)
    try testing.expectEqual(@as(u32, 0), range.start_offset);
    try testing.expectEqual(@as(u32, 0), range.end_offset);
}

test "Range tracking - splitText updates ranges correctly" {
    const allocator = testing.allocator;


    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const doc_node: *Node = @ptrCast(doc_ptr);
    doc_node.node_type = Node.DOCUMENT_NODE;

    // Create parent element
    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }
    const parent_node: *Node = @ptrCast(parent);

    // Create text node with data
    const text = try doc_ptr.call_createTextNode("Hello World");
    const text_node: *Node = @ptrCast(text);

    // Append text to parent (needed for split to work)
    _ = try parent_node.call_appendChild(text_node);

    // Create range starting in second half of text (offset 8 in "Hello World")
    const range = try allocator.create(Range);
    defer allocator.destroy(range);
    range.* = try Range.init(allocator, doc_node);
    defer range.deinit();
    try range.registerWithDocument();
    try range.call_setStart(text_node, 8);
    try range.call_setEnd(text_node, 11);

    // Split text at offset 6 (splits "Hello World" into "Hello " and "World")
    const new_text = try text.call_splitText(6);

    // Range should now point to new_text with adjusted offsets
    const new_text_node: *Node = @ptrCast(new_text);
    try testing.expectEqual(new_text_node, range.start_container);
    try testing.expectEqual(new_text_node, range.end_container);
    try testing.expectEqual(@as(u32, 2), range.start_offset); // 8 - 6 = 2
    try testing.expectEqual(@as(u32, 5), range.end_offset); // 11 - 6 = 5
}

test "Range tracking - splitText updates parent-relative ranges" {
    const allocator = testing.allocator;


    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const doc_node: *Node = @ptrCast(doc_ptr);
    doc_node.node_type = Node.DOCUMENT_NODE;

    // Create parent element with two text nodes
    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }
    const parent_node: *Node = @ptrCast(parent);

    const text1 = try doc_ptr.call_createTextNode("First");
    const text1_node: *Node = @ptrCast(text1);
    _ = try parent_node.call_appendChild(text1_node);

    const text2 = try doc_ptr.call_createTextNode("Second");
    const text2_node: *Node = @ptrCast(text2);
    _ = try parent_node.call_appendChild(text2_node);

    // Create range with parent as container, pointing after text1 (offset = 1)
    const range = try allocator.create(Range);
    defer allocator.destroy(range);
    range.* = try Range.init(allocator, doc_node);
    defer range.deinit();
    try range.registerWithDocument();
    try range.call_setStart(parent_node, 1);
    try range.call_setEnd(parent_node, 1);

    // Split text1 - this inserts a new node, which should update parent-relative ranges
    _ = try text1.call_splitText(3);

    // Range offset should be increased by 1 (from 1 to 2) since a new node was inserted
    try testing.expectEqual(parent_node, range.start_container);
    try testing.expectEqual(@as(u32, 2), range.start_offset);
    try testing.expectEqual(@as(u32, 2), range.end_offset);
}

test "Range tracking - node removal updates ranges" {
    const allocator = testing.allocator;


    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const doc_node: *Node = @ptrCast(doc_ptr);
    doc_node.node_type = Node.DOCUMENT_NODE;

    // Create parent with two children
    const parent = try doc_ptr.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }
    const parent_node: *Node = @ptrCast(parent);

    const child1 = try doc_ptr.call_createElement("span");
    const child1_node: *Node = @ptrCast(child1);
    _ = try parent_node.call_appendChild(child1_node);

    const child2 = try doc_ptr.call_createElement("p");
    const child2_node: *Node = @ptrCast(child2);
    _ = try parent_node.call_appendChild(child2_node);

    // Create range pointing inside child1
    const range = try allocator.create(Range);
    defer allocator.destroy(range);
    range.* = try Range.init(allocator, doc_node);
    defer range.deinit();
    try range.registerWithDocument();
    try range.call_setStart(child1_node, 0);
    try range.call_setEnd(child1_node, 0);

    // Remove child1 - range should be adjusted to (parent, 0)
    _ = try parent_node.call_removeChild(child1_node);

    try testing.expectEqual(parent_node, range.start_container);
    try testing.expectEqual(parent_node, range.end_container);
    try testing.expectEqual(@as(u32, 0), range.start_offset);
    try testing.expectEqual(@as(u32, 0), range.end_offset);

    // Cleanup removed child
    child1.deinit();
    allocator.destroy(child1);
}

test "Range tracking - multiple ranges update independently" {
    const allocator = testing.allocator;


    const doc_ptr = try allocator.create(Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try Document.init(allocator);
    defer doc_ptr.deinit();

    const doc_node: *Node = @ptrCast(doc_ptr);
    doc_node.node_type = Node.DOCUMENT_NODE;

    // Create text node
    const text = try doc_ptr.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }
    const text_node: *Node = @ptrCast(text);

    // Create two ranges with different positions
    const range1 = try allocator.create(Range);
    defer allocator.destroy(range1);
    range1.* = try Range.init(allocator, doc_node);
    defer range1.deinit();
    try range1.registerWithDocument();
    try range1.call_setStart(text_node, 2);
    try range1.call_setEnd(text_node, 4);

    const range2 = try allocator.create(Range);
    defer allocator.destroy(range2);
    range2.* = try Range.init(allocator, doc_node);
    defer range2.deinit();
    try range2.registerWithDocument();
    try range2.call_setStart(text_node, 8);
    try range2.call_setEnd(text_node, 10);

    // Replace data (offset 0, count 6, data "Hi ")
    try text.call_replaceData(0, 6, "Hi ");

    // range1 was within replaced region - should collapse to 0
    try testing.expectEqual(@as(u32, 0), range1.start_offset);
    try testing.expectEqual(@as(u32, 0), range1.end_offset);

    // range2 was after replaced region - should be adjusted
    // Original: 8-10, after removing 6 and adding 3: 8-6+3=5, 10-6+3=7
    try testing.expectEqual(@as(u32, 5), range2.start_offset);
    try testing.expectEqual(@as(u32, 7), range2.end_offset);
}
