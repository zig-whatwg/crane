const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");



// Type aliases
const Attr = dom.Attr;
const Comment = dom.Comment;
const Element = dom.Element;
const Node = dom.Node;
const Text = dom.Text;

test "Node.nodeValue - Text node returns data" {
    const allocator = std.testing.allocator;

    var text = try Text.init(allocator, "Hello World");
    defer text.deinit();

    const text_node: *Node = @ptrCast(&text);

    const node_value = text_node.get_nodeValue();
    try std.testing.expect(node_value != null);
    try std.testing.expectEqualStrings("Hello World", node_value.?);
}

test "Node.nodeValue - Comment node returns data" {
    const allocator = std.testing.allocator;

    var comment = try Comment.init(allocator, "This is a comment");
    defer comment.deinit();

    const comment_node: *Node = @ptrCast(&comment);

    const node_value = comment_node.get_nodeValue();
    try std.testing.expect(node_value != null);
    try std.testing.expectEqualStrings("This is a comment", node_value.?);
}

test "Node.nodeValue - Element returns null" {
    const allocator = std.testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const elem_node: *Node = @ptrCast(&elem);

    const node_value = elem_node.get_nodeValue();
    try std.testing.expect(node_value == null);
}

test "Node.nodeValue - Attr returns value" {
    const allocator = std.testing.allocator;

    var attr = try Attr.init(allocator, null, null, "id", "myId");
    defer attr.deinit();

    const attr_node: *Node = @ptrCast(&attr);

    const node_value = attr_node.get_nodeValue();
    try std.testing.expect(node_value != null);
    try std.testing.expectEqualStrings("myId", node_value.?);
}

test "Node.nodeValue - set Text node value" {
    const allocator = std.testing.allocator;

    var text = try Text.init(allocator, "Original");
    defer text.deinit();

    const text_node: *Node = @ptrCast(&text);

    // Set new value
    try text_node.set_nodeValue("Updated");

    // Verify it changed
    const node_value = text_node.get_nodeValue();
    try std.testing.expectEqualStrings("Updated", node_value.?);
}

test "Node.nodeValue - set Attr value" {
    const allocator = std.testing.allocator;

    var attr = try Attr.init(allocator, null, null, "class", "old-class");
    defer attr.deinit();

    const attr_node: *Node = @ptrCast(&attr);

    // Set new value
    try attr_node.set_nodeValue("new-class");

    // Verify it changed
    const node_value = attr_node.get_nodeValue();
    try std.testing.expectEqualStrings("new-class", node_value.?);
}

test "Node.nodeValue - set Element value does nothing" {
    const allocator = std.testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const elem_node: *Node = @ptrCast(&elem);

    // Set value on element (should do nothing)
    try elem_node.set_nodeValue("ignored");

    // Should still be null
    const node_value = elem_node.get_nodeValue();
    try std.testing.expect(node_value == null);
}

test "Node.nodeValue - set null treated as empty string" {
    const allocator = std.testing.allocator;

    var text = try Text.init(allocator, "Original");
    defer text.deinit();

    const text_node: *Node = @ptrCast(&text);

    // Set null (should be treated as empty string)
    try text_node.set_nodeValue(null);

    // Verify it's now empty
    const node_value = text_node.get_nodeValue();
    try std.testing.expectEqualStrings("", node_value.?);
}
