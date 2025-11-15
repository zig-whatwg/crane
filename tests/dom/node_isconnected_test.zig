const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases
const Document = dom.Document;
const Element = dom.Element;
const Node = dom.Node;

test "Node.isConnected - document is connected" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const doc_node: *Node = @ptrCast(&doc);
    try std.testing.expect(doc_node.get_isConnected());
}

test "Node.isConnected - element in document is connected" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const doc_node: *Node = @ptrCast(&doc);
    const elem_node: *Node = @ptrCast(&elem);

    // Before appending, element is not connected
    try std.testing.expect(!elem_node.get_isConnected());

    // Append to document
    _ = try doc_node.call_appendChild(elem_node);

    // Now element is connected
    try std.testing.expect(elem_node.get_isConnected());
}

test "Node.isConnected - detached element is not connected" {
    const allocator = std.testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const elem_node: *Node = @ptrCast(&elem);
    try std.testing.expect(!elem_node.get_isConnected());
}

test "Node.isConnected - nested elements in document are connected" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var parent = try Element.init(allocator, "div");
    defer parent.deinit();

    var child = try Element.init(allocator, "span");
    defer child.deinit();

    const doc_node: *Node = @ptrCast(&doc);
    const parent_node: *Node = @ptrCast(&parent);
    const child_node: *Node = @ptrCast(&child);

    // Append parent to document
    _ = try doc_node.call_appendChild(parent_node);

    // Append child to parent
    _ = try parent_node.call_appendChild(child_node);

    // Both are connected
    try std.testing.expect(parent_node.get_isConnected());
    try std.testing.expect(child_node.get_isConnected());
}

test "Node.isConnected - element removed from document is not connected" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const doc_node: *Node = @ptrCast(&doc);
    const elem_node: *Node = @ptrCast(&elem);

    // Append to document
    _ = try doc_node.call_appendChild(elem_node);
    try std.testing.expect(elem_node.get_isConnected());

    // Remove from document
    _ = doc_node.call_removeChild(elem_node) catch unreachable;
    try std.testing.expect(!elem_node.get_isConnected());
}

test "Node.isConnected - orphaned subtree is not connected" {
    const allocator = std.testing.allocator;

    var parent = try Element.init(allocator, "div");
    defer parent.deinit();

    var child = try Element.init(allocator, "span");
    defer child.deinit();

    const parent_node: *Node = @ptrCast(&parent);
    const child_node: *Node = @ptrCast(&child);

    // Create orphaned subtree
    _ = try parent_node.call_appendChild(child_node);

    // Neither is connected (no document root)
    try std.testing.expect(!parent_node.get_isConnected());
    try std.testing.expect(!child_node.get_isConnected());
}
