const std = @import("std");
const Node = @import("node").Node;
const Text = @import("text").Text;
const Comment = @import("comment").Comment;
const Element = @import("element").Element;
const Attr = @import("attr").Attr;

test "Node.nodeValue - Text node returns data" {
    const allocator = std.testing.allocator;

    var text = try Text.create(allocator, "Hello World");
    defer text.deinit();

    const text_node = text.asNode();

    const node_value = text_node.get_nodeValue();
    try std.testing.expect(node_value != null);
    try std.testing.expectEqualStrings("Hello World", node_value.?);
}

test "Node.nodeValue - Comment node returns data" {
    const allocator = std.testing.allocator;

    var comment = try Comment.create(allocator, "This is a comment");
    defer comment.deinit();

    const comment_node = comment.asNode();

    const node_value = comment_node.get_nodeValue();
    try std.testing.expect(node_value != null);
    try std.testing.expectEqualStrings("This is a comment", node_value.?);
}

test "Node.nodeValue - Element returns null" {
    const allocator = std.testing.allocator;

    var elem = try Element.create(allocator, "div", null, null);
    defer elem.deinit();

    const elem_node = elem.asNode();

    const node_value = elem_node.get_nodeValue();
    try std.testing.expect(node_value == null);
}

test "Node.nodeValue - Attr returns value" {
    const allocator = std.testing.allocator;

    var attr = try Attr.init(allocator, null, "id", "myId");
    defer attr.deinit();

    const attr_node = attr.asNode();

    const node_value = attr_node.get_nodeValue();
    try std.testing.expect(node_value != null);
    try std.testing.expectEqualStrings("myId", node_value.?);
}

test "Node.nodeValue - set Text node value" {
    const allocator = std.testing.allocator;

    var text = try Text.create(allocator, "Original");
    defer text.deinit();

    const text_node = text.asNode();

    // Set new value
    try text_node.set_nodeValue("Updated");

    // Verify it changed
    const node_value = text_node.get_nodeValue();
    try std.testing.expectEqualStrings("Updated", node_value.?);
}

test "Node.nodeValue - set Attr value" {
    const allocator = std.testing.allocator;

    var attr = try Attr.init(allocator, null, "class", "old-class");
    defer attr.deinit();

    const attr_node = attr.asNode();

    // Set new value
    try attr_node.set_nodeValue("new-class");

    // Verify it changed
    const node_value = attr_node.get_nodeValue();
    try std.testing.expectEqualStrings("new-class", node_value.?);
}

test "Node.nodeValue - set Element value does nothing" {
    const allocator = std.testing.allocator;

    var elem = try Element.create(allocator, "div", null, null);
    defer elem.deinit();

    const elem_node = elem.asNode();

    // Set value on element (should do nothing)
    try elem_node.set_nodeValue("ignored");

    // Should still be null
    const node_value = elem_node.get_nodeValue();
    try std.testing.expect(node_value == null);
}

test "Node.nodeValue - set null treated as empty string" {
    const allocator = std.testing.allocator;

    var text = try Text.create(allocator, "Original");
    defer text.deinit();

    const text_node = text.asNode();

    // Set null (should be treated as empty string)
    try text_node.set_nodeValue(null);

    // Verify it's now empty
    const node_value = text_node.get_nodeValue();
    try std.testing.expectEqualStrings("", node_value.?);
}
