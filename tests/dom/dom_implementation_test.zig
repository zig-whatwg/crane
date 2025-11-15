const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases
const Node = dom.Node;

const testing = std.testing;
const Document = dom.Document;
const DOMImplementation = dom.DOMImplementation;
const DocumentType = dom.DocumentType;

test "DOMImplementation: createDocumentType with valid name" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const doctype = try impl.call_createDocumentType("html", "", "");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("html", doctype.name);
    try testing.expectEqualStrings("", doctype.publicId);
    try testing.expectEqualStrings("", doctype.systemId);
}

test "DOMImplementation: createDocumentType with public and system IDs" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const doctype = try impl.call_createDocumentType("html", "-//W3C//DTD HTML 4.01//EN", "http://www.w3.org/TR/html4/strict.dtd");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("html", doctype.name);
    try testing.expectEqualStrings("-//W3C//DTD HTML 4.01//EN", doctype.publicId);
    try testing.expectEqualStrings("http://www.w3.org/TR/html4/strict.dtd", doctype.systemId);
}

test "DOMImplementation: createDocumentType with empty name (valid)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // Empty string is a valid doctype name per spec
    const doctype = try impl.call_createDocumentType("", "", "");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("", doctype.name);
}

test "DOMImplementation: createDocumentType with space in name (invalid)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // Space is ASCII whitespace - should throw InvalidCharacterError
    try testing.expectError(error.InvalidCharacterError, impl.call_createDocumentType("html test", "", ""));
}

test "DOMImplementation: createDocumentType with null character (invalid)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // U+0000 NULL - should throw InvalidCharacterError
    try testing.expectError(error.InvalidCharacterError, impl.call_createDocumentType("html\x00test", "", ""));
}

test "DOMImplementation: createDocumentType with > character (invalid)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // U+003E (>) - should throw InvalidCharacterError
    try testing.expectError(error.InvalidCharacterError, impl.call_createDocumentType("html>test", "", ""));
}

test "DOMImplementation: createDocumentType with tab character (invalid)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // Tab is ASCII whitespace - should throw InvalidCharacterError
    try testing.expectError(error.InvalidCharacterError, impl.call_createDocumentType("html\ttest", "", ""));
}

test "DOMImplementation: createHTMLDocument without title" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const html_doc = try impl.call_createHTMLDocument(null);
    defer {
        html_doc.deinit();
        allocator.destroy(html_doc);
    }

    // Document should have html, head, and body elements
    // TODO: Test document structure when tree methods are available
}

test "DOMImplementation: createHTMLDocument with title" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const html_doc = try impl.call_createHTMLDocument("Test Page");
    defer {
        html_doc.deinit();
        allocator.destroy(html_doc);
    }

    // Document should have html, head (with title), and body elements
    // TODO: Test document structure and title when tree methods are available
}

test "DOMImplementation: createHTMLDocument with empty title" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const html_doc = try impl.call_createHTMLDocument("");
    defer {
        html_doc.deinit();
        allocator.destroy(html_doc);
    }

    // Empty title is valid - should still have title element
}

test "DOMImplementation: createDocument without qualified name" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // Empty qualified name - no document element
    const xml_doc = try impl.call_createDocument(null, "", null);
    defer {
        xml_doc.deinit();
        allocator.destroy(xml_doc);
    }

    // TODO: Verify no document element when tree methods are available
}

test "DOMImplementation: createDocument with qualified name and namespace" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const xml_doc = try impl.call_createDocument("http://www.w3.org/1999/xhtml", "html", null);
    defer {
        xml_doc.deinit();
        allocator.destroy(xml_doc);
    }

    // TODO: Verify document element when tree methods are available
}

test "DOMImplementation: createDocument with doctype" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const doctype = try impl.call_createDocumentType("html", "", "");

    const xml_doc = try impl.call_createDocument(null, "html", doctype);
    defer {
        xml_doc.deinit();
        allocator.destroy(xml_doc);
    }

    // doctype is now owned by xml_doc - will be cleaned up with document
    // TODO: Verify doctype is in document when tree methods are available
}

test "DOMImplementation: hasFeature always returns true" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // hasFeature is legacy and always returns true
    try testing.expect(impl.hasFeature());
}

test "DOMImplementation: Document.implementation getter" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Get implementation from document
    const impl1 = try doc.implementation();
    defer impl1.deinit();

    // Should be [SameObject] - same instance every time
    const impl2 = try doc.implementation();
    defer impl2.deinit();

    // Both should reference the same document
    // TODO: Test [SameObject] semantics when we have pointer equality
}

// ============================================================================
// Document Creation with Tree Structure Tests
// ============================================================================

test "DOMImplementation: createHTMLDocument creates proper tree structure" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const html_doc = try impl.call_createHTMLDocument("Test Title");
    defer {
        html_doc.deinit();
        allocator.destroy(html_doc);
    }

    const html_doc_node: *Node = @ptrCast(html_doc);

    // Document should have 2 children: doctype and html element
    try testing.expectEqual(@as(usize, 2), html_doc_node.child_nodes.len);

    // First child should be doctype
    const first_child = html_doc_node.child_nodes.get(0);
    try testing.expectEqual(Node.DOCUMENT_TYPE_NODE, first_child.node_type);

    // Second child should be html element
    const html_elem = html_doc_node.child_nodes.get(1);
    try testing.expectEqual(Node.ELEMENT_NODE, html_elem.node_type);

    // html element should have 2 children: head and body
    try testing.expectEqual(@as(usize, 2), html_elem.child_nodes.len);

    const head = html_elem.child_nodes.get(0);
    const body = html_elem.child_nodes.get(1);

    // head should have 1 child: title
    try testing.expectEqual(@as(usize, 1), head.child_nodes.len);
    const title_elem = head.child_nodes.get(0);

    // title should have 1 child: text node
    try testing.expectEqual(@as(usize, 1), title_elem.child_nodes.len);
    const text_node = title_elem.child_nodes.get(0);
    try testing.expectEqual(Node.TEXT_NODE, text_node.node_type);

    // body should have no children
    try testing.expectEqual(@as(usize, 0), body.child_nodes.len);
}

test "DOMImplementation: createHTMLDocument without title has no title element" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const html_doc = try impl.call_createHTMLDocument(null);
    defer {
        html_doc.deinit();
        allocator.destroy(html_doc);
    }

    const html_doc_node: *Node = @ptrCast(html_doc);

    // Get html element
    const html_elem = html_doc_node.child_nodes.get(1);

    // html should have 2 children: head and body
    try testing.expectEqual(@as(usize, 2), html_elem.child_nodes.len);

    const head = html_elem.child_nodes.get(0);

    // head should have NO children (no title)
    try testing.expectEqual(@as(usize, 0), head.child_nodes.len);
}

test "DOMImplementation: createDocument with element creates tree" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const xml_doc = try impl.call_createDocument("http://www.example.com/ns", "root", null);
    defer {
        xml_doc.deinit();
        allocator.destroy(xml_doc);
    }

    const xml_doc_node: *Node = @ptrCast(xml_doc);

    // Document should have 1 child: root element
    try testing.expectEqual(@as(usize, 1), xml_doc_node.child_nodes.len);

    const root = xml_doc_node.child_nodes.get(0);
    try testing.expectEqual(Node.ELEMENT_NODE, root.node_type);
}

test "DOMImplementation: createDocument with doctype and element" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const doctype = try impl.call_createDocumentType("myroot", "", "");

    const xml_doc = try impl.call_createDocument(null, "myroot", doctype);
    defer {
        xml_doc.deinit();
        allocator.destroy(xml_doc);
    }

    const xml_doc_node: *Node = @ptrCast(xml_doc);

    // Document should have 2 children: doctype and root element
    try testing.expectEqual(@as(usize, 2), xml_doc_node.child_nodes.len);

    // First child is doctype
    const first = xml_doc_node.child_nodes.get(0);
    try testing.expectEqual(Node.DOCUMENT_TYPE_NODE, first.node_type);

    // Second child is root element
    const second = xml_doc_node.child_nodes.get(1);
    try testing.expectEqual(Node.ELEMENT_NODE, second.node_type);
}

test "DOMImplementation: createDocument with empty qualified name has no element" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    const xml_doc = try impl.call_createDocument(null, "", null);
    defer {
        xml_doc.deinit();
        allocator.destroy(xml_doc);
    }

    const xml_doc_node: *Node = @ptrCast(xml_doc);

    // Document should have 0 children (no element, no doctype)
    try testing.expectEqual(@as(usize, 0), xml_doc_node.child_nodes.len);
}
