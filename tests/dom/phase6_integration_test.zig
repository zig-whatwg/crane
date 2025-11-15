const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const testing = std.testing;
const Document = dom.Document;
const DOMImplementation = dom.DOMImplementation;
const Element = dom.Element;
const Text = dom.Text;
const Comment = dom.Comment;
const CharacterData = dom.CharacterData;
const ProcessingInstruction = dom.ProcessingInstruction;
const CDATASection = dom.CDATASection;
const DocumentType = dom.DocumentType;
const Attr = dom.Attr;
const NodeList = dom.NodeList;
const NamedNodeMap = dom.NamedNodeMap;

// ============================================================================
// INTEGRATION TESTS - Cross-Interface Interactions
// ============================================================================

test "Integration: Document creates all node types" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create element
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Create text node
    const text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Create comment
    const comment = try doc.call_createComment("A comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    // Create processing instruction
    const pi = try doc.call_createProcessingInstruction("xml-stylesheet", "href=\"style.css\"");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    // Create CDATA section
    const cdata = try doc.call_createCDATASection("<![CDATA[content]]>");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    // Create doctype
    const doctype = try doc.call_createDocumentType("html", "", "");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    // All nodes created successfully
}

test "Integration: DOMImplementation creates documents with nodes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // Create doctype via implementation
    const doctype = try impl.call_createDocumentType("html", "-//W3C//DTD HTML 4.01//EN", "http://www.w3.org/TR/html4/strict.dtd");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("html", doctype.name);
    try testing.expectEqualStrings("-//W3C//DTD HTML 4.01//EN", doctype.publicId);
    try testing.expectEqualStrings("http://www.w3.org/TR/html4/strict.dtd", doctype.systemId);

    // Create XML document
    const xml_doc = try impl.call_createDocument("http://www.w3.org/1999/xhtml", "html", null);
    defer {
        xml_doc.deinit();
        allocator.destroy(xml_doc);
    }

    // Create HTML document
    const html_doc = try impl.call_createHTMLDocument("Test Page");
    defer {
        html_doc.deinit();
        allocator.destroy(html_doc);
    }
}

test "Integration: Text node (CharacterData) operations" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Test initial data
    const initial_data = try text.call_substringData(0, 5);
    defer allocator.free(initial_data);
    try testing.expectEqualStrings("Hello", initial_data);

    // Append data
    try text.call_appendData(" of DOM!");
    try testing.expectEqual(@as(usize, 21), text.data.len);

    // Insert data
    try text.call_insertData(11, " Amazing");
    try testing.expectEqual(@as(usize, 29), text.data.len);

    // Delete data
    try text.call_deleteData(11, 8);
    try testing.expectEqual(@as(usize, 21), text.data.len);

    // Replace data
    try text.call_replaceData(6, 5, "DOM");
    try testing.expectEqual(@as(usize, 19), text.data.len);
}

test "Integration: Comment node (CharacterData) operations" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const comment = try doc.call_createComment("Initial comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    // Test substringData
    const substr = try comment.call_substringData(0, 7);
    defer allocator.free(substr);
    try testing.expectEqualStrings("Initial", substr);

    // Test appendData
    try comment.call_appendData(" text");
    try testing.expectEqual(@as(usize, 20), comment.data.len);
}

test "Integration: ProcessingInstruction extends CharacterData" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const pi = try doc.call_createProcessingInstruction("xml-stylesheet", "href=\"style.css\"");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    // Check target (read-only)
    try testing.expectEqualStrings("xml-stylesheet", pi.target);

    // CharacterData operations work
    try pi.call_appendData(" type=\"text/css\"");
    const new_data_len = std.mem.len(pi.data);
    try testing.expect(new_data_len > 16);
}

test "Integration: CDATASection extends Text extends CharacterData" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const cdata = try doc.call_createCDATASection("Some CDATA content");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    // CharacterData operations work
    try cdata.call_appendData(" more");
    try testing.expectEqual(@as(usize, 23), cdata.data.len);

    // Text operations work (splitText)
    const new_text = try cdata.call_splitText(4);
    defer {
        new_text.deinit();
        allocator.destroy(new_text);
    }

    try testing.expectEqual(@as(usize, 4), cdata.data.len);
    try testing.expectEqual(@as(usize, 19), new_text.data.len);
}

test "Integration: Element with Attr nodes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Create attributes
    const attr1 = try Attr.init(allocator, null, null, "class", "container");
    try elem.attributes.append(attr1);

    const attr2 = try Attr.init(allocator, null, null, "id", "main");
    try elem.attributes.append(attr2);

    // Check attribute count
    try testing.expectEqual(@as(usize, 2), elem.attributes.items.len);

    // Access via NamedNodeMap
    var map = NamedNodeMap.init(&elem);
    try testing.expectEqual(@as(usize, 2), map.length);

    const class_attr = map.getNamedItem("class");
    try testing.expect(class_attr != null);
    if (class_attr) |attr| {
        try testing.expectEqualStrings("container", attr.value);
    }
}

test "Integration: NodeList with multiple elements" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create elements
    const elem1 = try doc.call_createElement("div");
    const elem2 = try doc.call_createElement("span");
    const elem3 = try doc.call_createElement("p");

    // Create a NodeList (simulated collection)
    var nodes = std.ArrayList(*Element).init(allocator);
    defer nodes.deinit();
    try nodes.append(elem1);
    try nodes.append(elem2);
    try nodes.append(elem3);

    // Create NodeList wrapper
    var node_list = NodeList.init(allocator, nodes.items);
    defer node_list.deinit();

    // Test length
    try testing.expectEqual(@as(usize, 3), node_list.length);

    // Test item access
    const item = node_list.item(1);
    try testing.expect(item != null);
    if (item) |node| {
        try testing.expectEqualStrings("span", node.local_name);
    }

    // Clean up elements
    elem1.deinit();
    allocator.destroy(elem1);
    elem2.deinit();
    allocator.destroy(elem2);
    elem3.deinit();
    allocator.destroy(elem3);
}

test "Integration: DocumentType with DOMImplementation" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var impl = try DOMImplementation.init(allocator, &doc);
    defer impl.deinit();

    // Create various doctypes
    const html5_doctype = try impl.call_createDocumentType("html", "", "");
    defer {
        html5_doctype.deinit();
        allocator.destroy(html5_doctype);
    }
    try testing.expectEqualStrings("html", html5_doctype.name);
    try testing.expectEqualStrings("", html5_doctype.publicId);
    try testing.expectEqualStrings("", html5_doctype.systemId);

    const html4_doctype = try impl.call_createDocumentType("HTML", "-//W3C//DTD HTML 4.01 Transitional//EN", "http://www.w3.org/TR/html4/loose.dtd");
    defer {
        html4_doctype.deinit();
        allocator.destroy(html4_doctype);
    }
    try testing.expectEqualStrings("HTML", html4_doctype.name);
}

test "Integration: CharacterData unicode handling across types" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const emoji = "Hello 👋 World 🌍";

    // Test Text with unicode
    const text = try doc.call_createTextNode(emoji);
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Test Comment with unicode
    const comment = try doc.call_createComment(emoji);
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    // Test ProcessingInstruction with unicode
    const pi = try doc.call_createProcessingInstruction("target", emoji);
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    // Test CDATASection with unicode
    const cdata = try doc.call_createCDATASection(emoji);
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    // All should handle unicode correctly
    try testing.expect(text.data.len > 0);
    try testing.expect(comment.data.len > 0);
    try testing.expect(pi.data.len > 0);
    try testing.expect(cdata.data.len > 0);
}

test "Integration: Document.implementation [SameObject] behavior" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Get implementation first time
    const impl1 = try doc.get_implementation();

    // Get implementation second time
    const impl2 = try doc.get_implementation();

    // Both should reference the same document
    try testing.expect(impl1.document == impl2.document);
    try testing.expect(impl1.document == &doc);
}

test "Integration: Text.splitText creates new Text node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const original_text = try doc.call_createTextNode("Hello World");
    defer {
        original_text.deinit();
        allocator.destroy(original_text);
    }

    // Split at offset 6
    const new_text = try original_text.call_splitText(6);
    defer {
        new_text.deinit();
        allocator.destroy(new_text);
    }

    // Original should have "Hello "
    try testing.expectEqual(@as(usize, 6), original_text.data.len);
    const original_str = try original_text.call_substringData(0, 6);
    defer allocator.free(original_str);
    try testing.expectEqualStrings("Hello ", original_str);

    // New should have "World"
    try testing.expectEqual(@as(usize, 5), new_text.data.len);
    const new_str = try new_text.call_substringData(0, 5);
    defer allocator.free(new_str);
    try testing.expectEqualStrings("World", new_str);
}

test "Integration: Attr namespace handling" {
    const allocator = testing.allocator;

    // Create namespaced attribute (xmlns)
    const xmlns_attr = try Attr.init(allocator, "http://www.w3.org/2000/xmlns/", "xmlns", "xlink", "http://www.w3.org/1999/xlink");
    defer {
        xmlns_attr.deinit();
        allocator.destroy(xmlns_attr);
    }

    try testing.expectEqualStrings("http://www.w3.org/2000/xmlns/", xmlns_attr.namespaceURI.?);
    try testing.expectEqualStrings("xmlns", xmlns_attr.prefix.?);
    try testing.expectEqualStrings("xlink", xmlns_attr.localName);
    try testing.expectEqualStrings("xmlns:xlink", xmlns_attr.name);

    // Create non-namespaced attribute
    const simple_attr = try Attr.init(allocator, null, null, "class", "container");
    defer {
        simple_attr.deinit();
        allocator.destroy(simple_attr);
    }

    try testing.expect(simple_attr.namespaceURI == null);
    try testing.expect(simple_attr.prefix == null);
    try testing.expectEqualStrings("class", simple_attr.localName);
    try testing.expectEqualStrings("class", simple_attr.name);
}

test "Integration: NamedNodeMap wraps Element attributes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Add attributes directly to element
    const attr1 = try Attr.init(allocator, null, null, "id", "main");
    try elem.attributes.append(attr1);

    const attr2 = try Attr.init(allocator, null, null, "class", "container");
    try elem.attributes.append(attr2);

    const attr3 = try Attr.init(allocator, null, null, "title", "Main Container");
    try elem.attributes.append(attr3);

    // Access via NamedNodeMap
    var map = NamedNodeMap.init(&elem);

    // Test length
    try testing.expectEqual(@as(usize, 3), map.length);

    // Test item() access
    const first = map.item(0);
    try testing.expect(first != null);

    const out_of_bounds = map.item(10);
    try testing.expect(out_of_bounds == null);

    // Test getNamedItem()
    const id_attr = map.getNamedItem("id");
    try testing.expect(id_attr != null);
    if (id_attr) |attr| {
        try testing.expectEqualStrings("main", attr.value);
    }

    const missing_attr = map.getNamedItem("nonexistent");
    try testing.expect(missing_attr == null);
}
