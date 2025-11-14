const element = @import("element");
const document = @import("document");
const std = @import("std");
const Node = @import("node").Node;
const Element = @import("element").Element;
const Document = @import("document").Document;
const Text = @import("text").Text;

test "Node.parentElement - element parent returns element" {
    const allocator = std.testing.allocator;

    var parent = try Element.create(allocator, "div", null, null);
    defer parent.deinit();

    var child = try Element.create(allocator, "span", null, null);
    defer child.deinit();

    const parent_node = parent.asNode();
    const child_node = child.asNode();

    // Append child to parent
    _ = try parent_node.appendChild(child_node);

    const parent_element = child_node.get_parentElement();

    // Should return parent as Element
    try std.testing.expect(parent_element != null);
    try std.testing.expect(parent_element.? == &parent);
}

test "Node.parentElement - document parent returns null" {
    const allocator = std.testing.allocator;

    var doc = try Document.create(allocator);
    defer doc.deinit();

    var elem = try Element.create(allocator, "html", null, null);
    defer elem.deinit();

    const doc_node = doc.asNode();
    const elem_node = elem.asNode();

    // Append element to document
    _ = try doc_node.appendChild(elem_node);

    const parent_element = elem_node.get_parentElement();

    // Document is not an Element, should return null
    try std.testing.expect(parent_element == null);
}

test "Node.parentElement - no parent returns null" {
    const allocator = std.testing.allocator;

    var elem = try Element.create(allocator, "div", null, null);
    defer elem.deinit();

    const elem_node = elem.asNode();

    const parent_element = elem_node.get_parentElement();

    // No parent, should return null
    try std.testing.expect(parent_element == null);
}

test "Node.parentElement - text node with element parent" {
    const allocator = std.testing.allocator;

    var parent = try Element.create(allocator, "p", null, null);
    defer parent.deinit();

    var text_node = try Text.create(allocator, "Hello");
    defer text_node.deinit();

    const parent_node = parent.asNode();
    const text_as_node = text_node.asNode();

    // Append text to element
    _ = try parent_node.appendChild(text_as_node);

    const parent_element = text_as_node.get_parentElement();

    // Text node's parent is Element
    try std.testing.expect(parent_element != null);
    try std.testing.expect(parent_element.? == &parent);
}

test "Node.parentElement - nested elements" {
    const allocator = std.testing.allocator;

    var grandparent = try Element.create(allocator, "div", null, null);
    defer grandparent.deinit();

    var parent = try Element.create(allocator, "section", null, null);
    defer parent.deinit();

    var child = try Element.create(allocator, "span", null, null);
    defer child.deinit();

    const grandparent_node = grandparent.asNode();
    const parent_node = parent.asNode();
    const child_node = child.asNode();

    // Build tree: grandparent -> parent -> child
    _ = try grandparent_node.appendChild(parent_node);
    _ = try parent_node.appendChild(child_node);

    const child_parent_element = child_node.get_parentElement();
    const parent_parent_element = parent_node.get_parentElement();

    // Child's parent is parent element
    try std.testing.expect(child_parent_element != null);
    try std.testing.expect(child_parent_element.? == &parent);

    // Parent's parent is grandparent element
    try std.testing.expect(parent_parent_element != null);
    try std.testing.expect(parent_parent_element.? == &grandparent);
}
