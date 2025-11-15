const std = @import("std");
const Element = @import("dom").Element;
const Node = @import("dom").Node;

test "@ptrCast Element -> Node works correctly" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Direct field access
    element.node_type = 1; // ELEMENT_NODE
    try std.testing.expectEqual(@as(u16, 1), element.node_type);

    // Cast to Node pointer
    const node: *Node = @ptrCast(&element);

    // Access through Node pointer - if @ptrCast is broken, this reads garbage
    try std.testing.expectEqual(@as(u16, 1), node.node_type);

    // Write through Node pointer
    node.node_type = 99;

    // Verify it updated the Element's field
    try std.testing.expectEqual(@as(u16, 99), element.node_type);
    try std.testing.expectEqual(@as(u16, 99), node.node_type);
}

test "@ptrCast preserves all Node fields" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "span");
    defer element.deinit();

    // Set Node fields directly on Element
    element.node_type = 1;
    element.node_name = "SPAN";

    // Cast to Node
    const node: *Node = @ptrCast(&element);

    // Verify all fields are accessible and correct
    try std.testing.expectEqual(@as(u16, 1), node.node_type);
    try std.testing.expectEqualStrings("SPAN", node.node_name);
}
