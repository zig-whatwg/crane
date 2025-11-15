const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");



// Type aliases
const Document = dom.Document;
const Element = dom.Element;
const Node = dom.Node;
const Text = dom.Text;

test "Node.parentElement - element parent returns element" {
    const allocator = std.testing.allocator;

    var parent = try Element.init(allocator, "div");
    defer parent.deinit();

    var child = try Element.init(allocator, "span");
    defer child.deinit();

    const parent_node: *Node = @ptrCast(&parent);
    const child_node: *Node = @ptrCast(&child);

    // Append child to parent
    _ = try parent_node.call_appendChild(child_node);

    const parent_element = child_node.get_parentElement();

    // Should return parent as Element
    try std.testing.expect(parent_element != null);
    try std.testing.expect(parent_element.? == &parent);
}

test "Node.parentElement - document parent returns null" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try Element.init(allocator, "html");
    defer elem.deinit();

    const doc_node: *Node = @ptrCast(&doc);
    const elem_node: *Node = @ptrCast(&elem);

    // Append element to document
    _ = try doc_node.call_appendChild(elem_node);

    const parent_element = elem_node.get_parentElement();

    // Document is not an Element, should return null
    try std.testing.expect(parent_element == null);
}

test "Node.parentElement - no parent returns null" {
    const allocator = std.testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const elem_node: *Node = @ptrCast(&elem);

    const parent_element = elem_node.get_parentElement();

    // No parent, should return null
    try std.testing.expect(parent_element == null);
}

test "Node.parentElement - text node with element parent" {
    const allocator = std.testing.allocator;

    var parent = try Element.init(allocator, "p");
    defer parent.deinit();

    var text_node = try Text.create(allocator, "Hello");
    defer text_node.deinit();

    const parent_node: *Node = @ptrCast(&parent);
    const text_as_node = &text_node;

    // Append text to element
    _ = try parent_node.call_appendChild(text_as_node);

    const parent_element = text_as_node.get_parentElement();

    // Text node's parent is Element
    try std.testing.expect(parent_element != null);
    try std.testing.expect(parent_element.? == &parent);
}

test "Node.parentElement - nested elements" {
    const allocator = std.testing.allocator;

    var grandparent = try Element.init(allocator, "div");
    defer grandparent.deinit();

    var parent = try Element.init(allocator, "section");
    defer parent.deinit();

    var child = try Element.init(allocator, "span");
    defer child.deinit();

    const grandparent_node: *Node = @ptrCast(&grandparent);
    const parent_node: *Node = @ptrCast(&parent);
    const child_node: *Node = @ptrCast(&child);

    // Build tree: grandparent -> parent -> child
    _ = try grandparent_node.call_appendChild(parent_node);
    _ = try parent_node.call_appendChild(child_node);

    const child_parent_element = child_node.get_parentElement();
    const parent_parent_element = parent_node.get_parentElement();

    // Child's parent is parent element
    try std.testing.expect(child_parent_element != null);
    try std.testing.expect(child_parent_element.? == &parent);

    // Parent's parent is grandparent element
    try std.testing.expect(parent_parent_element != null);
    try std.testing.expect(parent_parent_element.? == &grandparent);
}
