const document_type = @import("document_type");
const std = @import("std");
const Node = @import("node").Node;
const DocumentType = @import("document_type").DocumentType;

test "Node.isEqualNode - DocumentType with same properties" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "", "");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "html", "", "");
    defer doctype_b.deinit();

    const node_a = doctype_a.asNode();
    const node_b = doctype_b.asNode();

    // DocumentTypes with same name, public ID, system ID are equal
    try std.testing.expect(node_a.call_isEqualNode(node_b));
}

test "Node.isEqualNode - DocumentType with different name" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "", "");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "xml", "", "");
    defer doctype_b.deinit();

    const node_a = doctype_a.asNode();
    const node_b = doctype_b.asNode();

    // DocumentTypes with different names are not equal
    try std.testing.expect(!node_a.call_isEqualNode(node_b));
}

test "Node.isEqualNode - DocumentType with different public ID" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "-//W3C//DTD XHTML 1.0//EN", "");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "html", "", "");
    defer doctype_b.deinit();

    const node_a = doctype_a.asNode();
    const node_b = doctype_b.asNode();

    // DocumentTypes with different public IDs are not equal
    try std.testing.expect(!node_a.call_isEqualNode(node_b));
}

test "Node.isEqualNode - DocumentType with different system ID" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "html", "", "");
    defer doctype_b.deinit();

    const node_a = doctype_a.asNode();
    const node_b = doctype_b.asNode();

    // DocumentTypes with different system IDs are not equal
    try std.testing.expect(!node_a.call_isEqualNode(node_b));
}

test "Node.isEqualNode - DocumentType with all properties different" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "-//W3C//DTD XHTML 1.0 Strict//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "xml", "", "");
    defer doctype_b.deinit();

    const node_a = doctype_a.asNode();
    const node_b = doctype_b.asNode();

    // DocumentTypes with all properties different are not equal
    try std.testing.expect(!node_a.call_isEqualNode(node_b));
}

test "Node.isEqualNode - DocumentType with all properties matching" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(
        allocator,
        "html",
        "-//W3C//DTD XHTML 1.0 Strict//EN",
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd",
    );
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(
        allocator,
        "html",
        "-//W3C//DTD XHTML 1.0 Strict//EN",
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd",
    );
    defer doctype_b.deinit();

    const node_a = doctype_a.asNode();
    const node_b = doctype_b.asNode();

    // DocumentTypes with all properties matching are equal
    try std.testing.expect(node_a.call_isEqualNode(node_b));
}
