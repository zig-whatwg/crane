const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const NodeList = @import("node_list").NodeList;


// Type aliases
const Element = dom.Element;
const Node = dom.Node;

test "Node.childNodes - [SameObject] returns same NodeList" {
    const allocator = std.testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const elem_node = &elem;

    // Get childNodes first time
    const list1 = try elem_node.get_childNodes();

    // Get childNodes second time
    const list2 = try elem_node.get_childNodes();

    // Should return the SAME object per [SameObject]
    try std.testing.expect(list1 == list2);
}

test "Node.childNodes - NodeList is initially populated" {
    const allocator = std.testing.allocator;

    var parent = try Element.init(allocator, "div");
    defer parent.deinit();

    var child1 = try Element.init(allocator, "span");
    defer child1.deinit();

    var child2 = try Element.init(allocator, "p");
    defer child2.deinit();

    const parent_node = &parent;
    const child1_node = child1.asNode();
    const child2_node = child2.asNode();

    // Add children before getting NodeList
    _ = try parent_node.call_appendChild(child1_node);
    _ = try parent_node.call_appendChild(child2_node);

    // Get childNodes
    const list = try parent_node.get_childNodes();

    // Should contain both children
    try std.testing.expectEqual(@as(u32, 2), list.get_length());
    try std.testing.expect(list.call_item(0) == child1_node);
    try std.testing.expect(list.call_item(1) == child2_node);
}

test "Node.childNodes - empty node has empty NodeList" {
    const allocator = std.testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const elem_node = &elem;

    // Get childNodes for empty node
    const list = try elem_node.get_childNodes();

    // Should be empty
    try std.testing.expectEqual(@as(u32, 0), list.get_length());
}

test "Node.childNodes - NodeList uses item() method" {
    const allocator = std.testing.allocator;

    var parent = try Element.init(allocator, "ul");
    defer parent.deinit();

    var child = try Element.init(allocator, "li");
    defer child.deinit();

    const parent_node = &parent;
    const child_node = &child;

    _ = try parent_node.call_appendChild(child_node);

    const list = try parent_node.get_childNodes();

    // item(0) should return first child
    try std.testing.expect(list.call_item(0) == child_node);

    // item(1) should return null (out of bounds)
    try std.testing.expect(list.call_item(1) == null);
}
