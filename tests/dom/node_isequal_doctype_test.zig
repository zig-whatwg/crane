const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases
const DocumentType = dom.DocumentType;
const Node = dom.Node;

test "Node.isEqualNode - DocumentType with same properties" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "", "");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "html", "", "");
    defer doctype_b.deinit();

    // DocumentTypes with same name, public ID, system ID are equal
    try std.testing.expect(doctype_a.call_isEqualNode(@ptrCast(&doctype_b)));
}

test "Node.isEqualNode - DocumentType with different name" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "", "");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "xml", "", "");
    defer doctype_b.deinit();

    // DocumentTypes with different names are not equal
    try std.testing.expect(!doctype_a.call_isEqualNode(@ptrCast(&doctype_b)));
}

test "Node.isEqualNode - DocumentType with different public ID" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "-//W3C//DTD XHTML 1.0//EN", "");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "html", "", "");
    defer doctype_b.deinit();

    // DocumentTypes with different public IDs are not equal
    try std.testing.expect(!doctype_a.call_isEqualNode(@ptrCast(&doctype_b)));
}

test "Node.isEqualNode - DocumentType with different system ID" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "html", "", "");
    defer doctype_b.deinit();

    // DocumentTypes with different system IDs are not equal
    try std.testing.expect(!doctype_a.call_isEqualNode(@ptrCast(&doctype_b)));
}

test "Node.isEqualNode - DocumentType with all properties different" {
    const allocator = std.testing.allocator;

    var doctype_a = try DocumentType.init(allocator, "html", "-//W3C//DTD XHTML 1.0 Strict//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd");
    defer doctype_a.deinit();

    var doctype_b = try DocumentType.init(allocator, "xml", "", "");
    defer doctype_b.deinit();

    // DocumentTypes with all properties different are not equal
    try std.testing.expect(!doctype_a.call_isEqualNode(@ptrCast(&doctype_b)));
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

    // DocumentTypes with all properties matching are equal
    try std.testing.expect(doctype_a.call_isEqualNode(@ptrCast(&doctype_b)));
}
