//! Document Creation Methods Tests (DOM Standard §4.6.1)
//! Tests for Document node creation methods

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CharacterData = dom.CharacterData;

const testing = std.testing;
const DocumentFragment = @import("DocumentFragment").DocumentFragment;

test "Document: createElement creates Element node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Verify it's an Element with correct tag name
    try testing.expectEqualStrings("div", elem.get_tagName());
}

test "Document: createElement creates different element types" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create various element types
    const div = try doc.call_createElement("div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }

    const span = try doc.call_createElement("span");
    defer {
        span.deinit();
        allocator.destroy(span);
    }

    const p = try doc.call_createElement("p");
    defer {
        p.deinit();
        allocator.destroy(p);
    }

    try testing.expectEqualStrings("div", div.get_tagName());
    try testing.expectEqualStrings("span", span.get_tagName());
    try testing.expectEqualStrings("p", p.get_tagName());
}

test "Document: createTextNode creates Text node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello, World!");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Text node created successfully
    // TODO: Verify text.data when CharacterData.data is accessible
}

test "Document: createComment creates Comment node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const comment = try doc.call_createComment("This is a comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    // Comment node created successfully
    // TODO: Verify comment.data when CharacterData.data is accessible
}

test "Document: createDocumentFragment creates fragment" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const fragment = try doc.call_createDocumentFragment();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // DocumentFragment created successfully
    // It should be a Node that can contain children
}

test "Document: createElementNS creates namespaced element" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElementNS("http://www.w3.org/2000/svg", "svg");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    try testing.expectEqualStrings("svg", elem.get_tagName());
    // TODO: Verify namespaceURI when namespace handling is implemented
}

test "Document: multiple nodes can be created from same document" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem1 = try doc.call_createElement("div");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }

    const text1 = try doc.call_createTextNode("text1");
    defer {
        text1.deinit();
        allocator.destroy(text1);
    }

    const comment1 = try doc.call_createComment("comment1");
    defer {
        comment1.deinit();
        allocator.destroy(comment1);
    }

    const frag1 = try doc.call_createDocumentFragment();
    defer {
        frag1.deinit();
        allocator.destroy(frag1);
    }

    const elem2 = try doc.call_createElement("span");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }

    // All nodes created successfully
    try testing.expectEqualStrings("div", elem1.get_tagName());
    try testing.expectEqualStrings("span", elem2.get_tagName());
}

test "Document: createElement with custom tag names" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Custom element names
    const custom = try doc.call_createElement("my-custom-element");
    defer {
        custom.deinit();
        allocator.destroy(custom);
    }

    try testing.expectEqualStrings("my-custom-element", custom.get_tagName());
}

// ============================================================================
// Document.adoptNode() tests
// ============================================================================

test "Document: adoptNode changes owner document" {
    const allocator = testing.allocator;

    // Create two documents
    var doc1 = try Document.init(allocator);
    defer doc1.deinit();

    var doc2 = try Document.init(allocator);
    defer doc2.deinit();

    // Create element in doc1
    const elem = try doc1.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    const elem_node: *Node = @ptrCast(elem);

    // Verify initial owner document is doc1
    try testing.expectEqual(&doc1, elem_node.owner_document.?);

    // Adopt elem into doc2
    const adopted = try doc2.call_adoptNode(elem_node);

    // Verify adoptNode returns the same node
    try testing.expectEqual(elem_node, adopted);

    // Verify owner document is now doc2
    try testing.expectEqual(&doc2, elem_node.owner_document.?);
}

test "Document: adoptNode removes from parent" {
    const allocator = testing.allocator;

    // Create two documents
    var doc1 = try Document.init(allocator);
    defer doc1.deinit();

    var doc2 = try Document.init(allocator);
    defer doc2.deinit();

    // Create parent and child in doc1
    const parent = try doc1.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    const child = try doc1.call_createElement("span");
    defer {
        child.deinit();
        allocator.destroy(child);
    }

    const parent_node: *Node = @ptrCast(parent);
    const child_node: *Node = @ptrCast(child);

    // Append child to parent
    _ = try parent_node.call_appendChild(child_node);

    // Verify child is in parent
    try testing.expectEqual(@as(usize, 1), parent_node.child_nodes.len);
    try testing.expectEqual(parent_node, child_node.parent_node.?);

    // Adopt child into doc2
    _ = try doc2.call_adoptNode(child_node);

    // Verify child is removed from parent
    try testing.expectEqual(@as(usize, 0), parent_node.child_nodes.len);
    try testing.expectEqual(@as(?*Node, null), child_node.parent_node);

    // Verify owner document is doc2
    try testing.expectEqual(&doc2, child_node.owner_document.?);
}

test "Document: adoptNode throws NotSupportedError for document node" {
    const allocator = testing.allocator;

    var doc1 = try Document.init(allocator);
    defer doc1.deinit();

    var doc2 = try Document.init(allocator);
    defer doc2.deinit();

    const doc1_node: *Node = @ptrCast(&doc1);

    // Try to adopt a document node - should throw NotSupportedError
    const result = doc2.call_adoptNode(doc1_node);
    try testing.expectError(error.NotSupportedError, result);
}

test "Document: adoptNode with tree of descendants" {
    const allocator = testing.allocator;

    // Create two documents
    var doc1 = try Document.init(allocator);
    defer doc1.deinit();

    var doc2 = try Document.init(allocator);
    defer doc2.deinit();

    // Create a tree in doc1: div > (span, p)
    const div = try doc1.call_createElement("div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }

    const span = try doc1.call_createElement("span");
    defer {
        span.deinit();
        allocator.destroy(span);
    }

    const p = try doc1.call_createElement("p");
    defer {
        p.deinit();
        allocator.destroy(p);
    }

    const div_node: *Node = @ptrCast(div);
    const span_node: *Node = @ptrCast(span);
    const p_node: *Node = @ptrCast(p);

    _ = try div_node.call_appendChild(span_node);
    _ = try div_node.call_appendChild(p_node);

    // Verify all nodes belong to doc1
    try testing.expectEqual(&doc1, div_node.owner_document.?);
    try testing.expectEqual(&doc1, span_node.owner_document.?);
    try testing.expectEqual(&doc1, p_node.owner_document.?);

    // Adopt the div (with descendants) into doc2
    _ = try doc2.call_adoptNode(div_node);

    // Verify all nodes now belong to doc2 (adoption is recursive)
    try testing.expectEqual(&doc2, div_node.owner_document.?);
    try testing.expectEqual(&doc2, span_node.owner_document.?);
    try testing.expectEqual(&doc2, p_node.owner_document.?);

    // Verify tree structure is preserved
    try testing.expectEqual(@as(usize, 2), div_node.child_nodes.len);
    try testing.expectEqual(span_node, div_node.child_nodes.get(0));
    try testing.expectEqual(p_node, div_node.child_nodes.get(1));
}

// ============================================================================
// Document.createElementNS() tests
// ============================================================================

test "Document: createElementNS with namespace sets namespace_uri" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create element with SVG namespace
    const svg_ns = "http://www.w3.org/2000/svg";
    const elem = try doc.call_createElementNS(svg_ns, "circle");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Verify namespace_uri is set
    try testing.expect(elem.namespace_uri != null);
    try testing.expectEqualStrings(svg_ns, elem.namespace_uri.?);

    // Verify tag name is set
    try testing.expectEqualStrings("circle", elem.get_tagName());
}

test "Document: createElementNS with null namespace" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create element with null namespace
    const elem = try doc.call_createElementNS(null, "div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Verify namespace_uri is null
    try testing.expectEqual(@as(?[]const u8, null), elem.namespace_uri);

    // Verify tag name is set
    try testing.expectEqualStrings("div", elem.get_tagName());
}

test "Document: createElementNS with different namespaces" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create HTML namespace element
    const html_ns = "http://www.w3.org/1999/xhtml";
    const html_elem = try doc.call_createElementNS(html_ns, "div");
    defer {
        html_elem.deinit();
        allocator.destroy(html_elem);
    }

    // Create SVG namespace element
    const svg_ns = "http://www.w3.org/2000/svg";
    const svg_elem = try doc.call_createElementNS(svg_ns, "circle");
    defer {
        svg_elem.deinit();
        allocator.destroy(svg_elem);
    }

    // Create MathML namespace element
    const mathml_ns = "http://www.w3.org/1998/Math/MathML";
    const math_elem = try doc.call_createElementNS(mathml_ns, "math");
    defer {
        math_elem.deinit();
        allocator.destroy(math_elem);
    }

    // Verify each has correct namespace
    try testing.expectEqualStrings(html_ns, html_elem.namespace_uri.?);
    try testing.expectEqualStrings(svg_ns, svg_elem.namespace_uri.?);
    try testing.expectEqualStrings(mathml_ns, math_elem.namespace_uri.?);
}

test "Document: createElementNS namespace memory management" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const svg_ns = "http://www.w3.org/2000/svg";

    // Create element
    const elem = try doc.call_createElementNS(svg_ns, "rect");
    defer {
        elem.deinit(); // Should free namespace_uri
        allocator.destroy(elem);
    }

    // Verify namespace is copied (not same pointer)
    try testing.expect(elem.namespace_uri.?.ptr != svg_ns.ptr);
    try testing.expectEqualStrings(svg_ns, elem.namespace_uri.?);
}

// ============================================================================
// Document.baseURI tests
// ============================================================================

test "Document: baseURI defaults to about:blank" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    // Default base URI should be about:blank
    try testing.expectEqualStrings("about:blank", doc.base_uri);
}

test "Node: baseURI returns document's base_uri" {
    const allocator = testing.allocator;
    
    var doc = try Document.init(allocator);
    defer doc.deinit();
    
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }
    
    const elem_node: *Node = @ptrCast(elem);
    
    // Element's baseURI should return document's base_uri
    try testing.expectEqualStrings("about:blank", elem_node.get_baseURI());
}
