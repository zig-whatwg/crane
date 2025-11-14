const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");



// Type aliases
const Document = dom.Document;
const Element = dom.Element;

test "NodeBase.tryCast - successful downcast to Element with auto-initialized type_tag" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Verify type_tag is automatically set
    try std.testing.expectEqual(NodeBase.NodeTypeTag.Element, element.base.type_tag);

    const node_base: *NodeBase = element.toBase();

    // Test successful downcast
    if (node_base.tryCast(Element)) |elem| {
        try std.testing.expectEqualStrings("div", elem.tag_name);
    } else {
        return error.DowncastFailed;
    }
}

test "NodeBase.tryCast - failed downcast to wrong type" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    const node_base: *NodeBase = element.toBase();

    // Test failed downcast to wrong type
    const doc = node_base.tryCast(Document);
    try std.testing.expectEqual(@as(?*Document, null), doc);
}

test "NodeBase type tag is correctly set" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    const node_base: *NodeBase = element.toBase();

    // Verify type tag is Element
    try std.testing.expectEqual(NodeBase.NodeTypeTag.Element, node_base.type_tag);
}

test "tryCastConst works with const pointers" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    const node_base: *const NodeBase = element.toBase();

    // Test const downcast
    if (node_base.tryCastConst(Element)) |elem| {
        try std.testing.expectEqualStrings("div", elem.tag_name);
    } else {
        return error.DowncastFailed;
    }
}
