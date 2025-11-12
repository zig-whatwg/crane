const std = @import("std");
const Node = @import("node").Node;
const Element = @import("element").Element;
const Document = @import("document").Document;

test "Node.getRootNode - document root" {
    const allocator = std.testing.allocator;

    var doc = try Document.create(allocator);
    defer doc.deinit();

    const doc_node = doc.asNode();
    const root_node = doc_node.call_getRootNode(null);

    // Document is its own root
    try std.testing.expect(root_node == doc_node);
}

test "Node.getRootNode - element in document" {
    const allocator = std.testing.allocator;

    var doc = try Document.create(allocator);
    defer doc.deinit();

    var elem = try Element.create(allocator, "div", null, null);
    defer elem.deinit();

    const doc_node = doc.asNode();
    const elem_node = elem.asNode();

    // Append element to document
    _ = try doc_node.appendChild(elem_node);

    const root_node = elem_node.call_getRootNode(null);

    // Element's root should be the document
    try std.testing.expect(root_node == doc_node);
}

test "Node.getRootNode - detached element" {
    const allocator = std.testing.allocator;

    var elem = try Element.create(allocator, "div", null, null);
    defer elem.deinit();

    const elem_node = elem.asNode();
    const root_node = elem_node.call_getRootNode(null);

    // Detached element is its own root
    try std.testing.expect(root_node == elem_node);
}

test "Node.getRootNode - nested elements" {
    const allocator = std.testing.allocator;

    var doc = try Document.create(allocator);
    defer doc.deinit();

    var parent = try Element.create(allocator, "div", null, null);
    defer parent.deinit();

    var child = try Element.create(allocator, "span", null, null);
    defer child.deinit();

    const doc_node = doc.asNode();
    const parent_node = parent.asNode();
    const child_node = child.asNode();

    // Build tree: doc -> parent -> child
    _ = try doc_node.appendChild(parent_node);
    _ = try parent_node.appendChild(child_node);

    const root_node = child_node.call_getRootNode(null);

    // Child's root should be the document
    try std.testing.expect(root_node == doc_node);
}

test "Node.getRootNode - orphaned subtree" {
    const allocator = std.testing.allocator;

    var parent = try Element.create(allocator, "div", null, null);
    defer parent.deinit();

    var child = try Element.create(allocator, "span", null, null);
    defer child.deinit();

    const parent_node = parent.asNode();
    const child_node = child.asNode();

    // Build orphaned subtree: parent -> child
    _ = try parent_node.appendChild(child_node);

    const root_node = child_node.call_getRootNode(null);

    // Child's root should be parent (not connected to document)
    try std.testing.expect(root_node == parent_node);
}

test "Node.getRootNode - options.composed false" {
    const allocator = std.testing.allocator;

    var doc = try Document.create(allocator);
    defer doc.deinit();

    var elem = try Element.create(allocator, "div", null, null);
    defer elem.deinit();

    const doc_node = doc.asNode();
    const elem_node = elem.asNode();

    _ = try doc_node.appendChild(elem_node);

    const GetRootNodeOptions = @import("node").GetRootNodeOptions;
    const root_node = elem_node.call_getRootNode(GetRootNodeOptions{ .composed = false });

    // Should return regular root (document)
    try std.testing.expect(root_node == doc_node);
}

test "Node.getRootNode - options.composed true (shadow root not yet implemented)" {
    const allocator = std.testing.allocator;

    var doc = try Document.create(allocator);
    defer doc.deinit();

    var elem = try Element.create(allocator, "div", null, null);
    defer elem.deinit();

    const doc_node = doc.asNode();
    const elem_node = elem.asNode();

    _ = try doc_node.appendChild(elem_node);

    const GetRootNodeOptions = @import("node").GetRootNodeOptions;
    const root_node = elem_node.call_getRootNode(GetRootNodeOptions{ .composed = true });

    // For now, composed=true falls back to regular root
    // TODO: When Shadow DOM is implemented, this should traverse shadow roots
    try std.testing.expect(root_node == doc_node);
}
