//! Tests for AbstractRange and StaticRange interfaces
//! Per WHATWG DOM Standard §5

const std = @import("std");
const dom = @import("dom");

test "StaticRange - basic construction" {
    const allocator = std.testing.allocator;

    // Create a simple document node
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const doc_node: *dom.Node = @ptrCast(&doc);

    // Create a StaticRange
    const static_range = try dom.StaticRange.init(.{
        .startContainer = doc_node,
        .startOffset = 0,
        .endContainer = doc_node,
        .endOffset = 0,
    });

    // Test AbstractRange getters (inherited)
    try std.testing.expectEqual(doc_node, static_range.get_startContainer());
    try std.testing.expectEqual(@as(u32, 0), static_range.get_startOffset());
    try std.testing.expectEqual(doc_node, static_range.get_endContainer());
    try std.testing.expectEqual(@as(u32, 0), static_range.get_endOffset());
    try std.testing.expect(static_range.get_collapsed());
}

test "StaticRange - rejects DocumentType nodes" {
    const allocator = std.testing.allocator;

    // Create a DocumentType node
    var doctype = try dom.DocumentType.init(allocator, "html");
    defer doctype.deinit();

    const doctype_node: *dom.Node = @ptrCast(&doctype);

    // Try to create StaticRange with DocumentType - should fail
    const result = dom.StaticRange.init(.{
        .startContainer = doctype_node,
        .startOffset = 0,
        .endContainer = doctype_node,
        .endOffset = 0,
    });

    try std.testing.expectError(error.InvalidNodeTypeError, result);
}

test "StaticRange - collapsed property" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const doc_node: *dom.Node = @ptrCast(&doc);

    // Collapsed range (same position)
    const collapsed_range = try dom.StaticRange.init(.{
        .startContainer = doc_node,
        .startOffset = 5,
        .endContainer = doc_node,
        .endOffset = 5,
    });
    try std.testing.expect(collapsed_range.get_collapsed());

    // Non-collapsed range (different positions)
    const non_collapsed_range = try dom.StaticRange.init(.{
        .startContainer = doc_node,
        .startOffset = 5,
        .endContainer = doc_node,
        .endOffset = 10,
    });
    try std.testing.expect(!non_collapsed_range.get_collapsed());
}

test "AbstractRange - basic interface" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const doc_node: *dom.Node = @ptrCast(&doc);

    // Create a Range (which extends AbstractRange)
    var range = try dom.Range.init(allocator, doc_node);
    defer range.deinit();

    // Test AbstractRange interface through Range
    try std.testing.expectEqual(doc_node, range.get_startContainer());
    try std.testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try std.testing.expectEqual(doc_node, range.get_endContainer());
    try std.testing.expectEqual(@as(u32, 0), range.get_endOffset());
    try std.testing.expect(range.get_collapsed());
}
