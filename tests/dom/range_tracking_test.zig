const std = @import("std");
const testing = std.testing;

test "Range tracking - per-document isolation" {
    const allocator = testing.allocator;

    // Import types
    const Document = @import("document").Document;
    const Range = @import("range").Range;
    const Node = @import("node").Node;

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
    try testing.expectEqual(@as(usize, 1), doc1_ptr.ranges.items.len);
    try testing.expectEqual(@as(usize, 1), doc2_ptr.ranges.items.len);
    try testing.expect(doc1_ptr.ranges.items[0] == range1);
    try testing.expect(doc2_ptr.ranges.items[0] == range2);
}

test "Range tracking - auto unregister on deinit" {
    const allocator = testing.allocator;

    const Document = @import("document").Document;
    const Range = @import("range").Range;
    const Node = @import("node").Node;

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
        try testing.expectEqual(@as(usize, 1), doc_ptr.ranges.items.len);

        // Deinit should auto-unregister
        range.deinit();
        allocator.destroy(range);
    }

    // Verify unregistered
    try testing.expectEqual(@as(usize, 0), doc_ptr.ranges.items.len);
}
