//! NodeFilter Tests (DOM Standard §6.1)
//! Tests for NodeFilter constants and filtering logic

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases
const Document = dom.Document;
const Node = dom.Node;
const NodeFilter = dom.NodeFilter;

const testing = std.testing;

test "NodeFilter: FILTER constants have correct values" {
    try testing.expectEqual(@as(u16, 1), NodeFilter.FILTER_ACCEPT);
    try testing.expectEqual(@as(u16, 2), NodeFilter.FILTER_REJECT);
    try testing.expectEqual(@as(u16, 3), NodeFilter.FILTER_SKIP);
}

test "NodeFilter: SHOW_ALL constant includes all bits" {
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), NodeFilter.SHOW_ALL);
}

test "NodeFilter: SHOW constants have correct bit positions" {
    try testing.expectEqual(@as(u32, 0x1), NodeFilter.SHOW_ELEMENT);
    try testing.expectEqual(@as(u32, 0x2), NodeFilter.SHOW_ATTRIBUTE);
    try testing.expectEqual(@as(u32, 0x4), NodeFilter.SHOW_TEXT);
    try testing.expectEqual(@as(u32, 0x8), NodeFilter.SHOW_CDATA_SECTION);
    try testing.expectEqual(@as(u32, 0x10), NodeFilter.SHOW_ENTITY_REFERENCE);
    try testing.expectEqual(@as(u32, 0x20), NodeFilter.SHOW_ENTITY);
    try testing.expectEqual(@as(u32, 0x40), NodeFilter.SHOW_PROCESSING_INSTRUCTION);
    try testing.expectEqual(@as(u32, 0x80), NodeFilter.SHOW_COMMENT);
    try testing.expectEqual(@as(u32, 0x100), NodeFilter.SHOW_DOCUMENT);
    try testing.expectEqual(@as(u32, 0x200), NodeFilter.SHOW_DOCUMENT_TYPE);
    try testing.expectEqual(@as(u32, 0x400), NodeFilter.SHOW_DOCUMENT_FRAGMENT);
    try testing.expectEqual(@as(u32, 0x800), NodeFilter.SHOW_NOTATION);
}

test "NodeFilter: isNodeTypeShown returns true for matching type" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // SHOW_ELEMENT should match element nodes
    try testing.expect(NodeFilter.isNodeTypeShown(NodeFilter.SHOW_ELEMENT, elem.node_type));

    // SHOW_ALL should match all nodes
    try testing.expect(NodeFilter.isNodeTypeShown(NodeFilter.SHOW_ALL, elem.node_type));
}

test "NodeFilter: isNodeTypeShown returns false for non-matching type" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // SHOW_TEXT should not match element nodes
    try testing.expect(!NodeFilter.isNodeTypeShown(NodeFilter.SHOW_TEXT, elem.node_type));

    // SHOW_COMMENT should not match element nodes
    try testing.expect(!NodeFilter.isNodeTypeShown(NodeFilter.SHOW_COMMENT, elem.node_type));
}

test "NodeFilter: isNodeTypeShown works with combined bitmask" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("hello");
    const comment = try doc.call_createComment("comment");

    // Combined mask: SHOW_ELEMENT | SHOW_TEXT
    const showElementAndText = NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT;

    // Should match element
    try testing.expect(NodeFilter.isNodeTypeShown(showElementAndText, elem.node_type));

    // Should match text
    try testing.expect(NodeFilter.isNodeTypeShown(showElementAndText, text.node_type));

    // Should not match comment
    try testing.expect(!NodeFilter.isNodeTypeShown(showElementAndText, comment.node_type));
}

test "NodeFilter: filterNode skips non-matching types" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Filter with SHOW_TEXT only (element should be skipped)
    const result = NodeFilter.filterNode(NodeFilter.SHOW_TEXT, null, @ptrCast(elem));
    try testing.expectEqual(NodeFilter.FILTER_SKIP, result);
}

test "NodeFilter: filterNode accepts matching types with no callback" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Filter with SHOW_ELEMENT and no callback (should accept)
    const result = NodeFilter.filterNode(NodeFilter.SHOW_ELEMENT, null, @ptrCast(elem));
    try testing.expectEqual(NodeFilter.FILTER_ACCEPT, result);
}

test "NodeFilter: filterNode calls callback for matching types" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Create a filter callback that always rejects
    const rejectFilter = struct {
        fn filter(_: *Node) u16 {
            return NodeFilter.FILTER_REJECT;
        }
    }.filter;

    // Filter with callback
    const result = NodeFilter.filterNode(NodeFilter.SHOW_ELEMENT, rejectFilter, @ptrCast(elem));
    try testing.expectEqual(NodeFilter.FILTER_REJECT, result);
}

test "NodeFilter: filterNode callback can accept nodes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Create a filter callback that always accepts
    const acceptFilter = struct {
        fn filter(_: *Node) u16 {
            return NodeFilter.FILTER_ACCEPT;
        }
    }.filter;

    // Filter with callback
    const result = NodeFilter.filterNode(NodeFilter.SHOW_ELEMENT, acceptFilter, @ptrCast(elem));
    try testing.expectEqual(NodeFilter.FILTER_ACCEPT, result);
}

test "NodeFilter: filterNode callback can skip nodes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Create a filter callback that skips
    const skipFilter = struct {
        fn filter(_: *Node) u16 {
            return NodeFilter.FILTER_SKIP;
        }
    }.filter;

    // Filter with callback
    const result = NodeFilter.filterNode(NodeFilter.SHOW_ELEMENT, skipFilter, @ptrCast(elem));
    try testing.expectEqual(NodeFilter.FILTER_SKIP, result);
}

test "NodeFilter: filterNode with SHOW_ALL and no callback accepts all" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Test different node types
    const elem = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("text");
    const comment = try doc.call_createComment("comment");

    // All should be accepted with SHOW_ALL
    try testing.expectEqual(NodeFilter.FILTER_ACCEPT, NodeFilter.filterNode(NodeFilter.SHOW_ALL, null, @ptrCast(elem)));
    try testing.expectEqual(NodeFilter.FILTER_ACCEPT, NodeFilter.filterNode(NodeFilter.SHOW_ALL, null, @ptrCast(text)));
    try testing.expectEqual(NodeFilter.FILTER_ACCEPT, NodeFilter.filterNode(NodeFilter.SHOW_ALL, null, @ptrCast(comment)));
}

test "NodeFilter: filterNode respects callback even with SHOW_ALL" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Callback rejects even though SHOW_ALL would match
    const rejectFilter = struct {
        fn filter(_: *Node) u16 {
            return NodeFilter.FILTER_REJECT;
        }
    }.filter;

    const result = NodeFilter.filterNode(NodeFilter.SHOW_ALL, rejectFilter, elem);
    try testing.expectEqual(NodeFilter.FILTER_REJECT, result);
}
