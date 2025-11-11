//! Document Creation Methods Tests (DOM Standard §4.6.1)
//! Tests for Document node creation methods

const std = @import("std");
const testing = std.testing;
const Document = @import("document").Document;
const Element = @import("element").Element;
const Text = @import("text").Text;
const Comment = @import("comment").Comment;
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
