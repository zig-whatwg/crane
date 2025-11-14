//! Element and Document Integration Tests
//! Tests for Element and Document working together in typical DOM scenarios

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const DocumentFragment = dom.DocumentFragment;

const testing = std.testing;

test "Integration: Create element with document and set attributes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create element using document
    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Set attributes on element
    try elem.set_id("container");
    try elem.set_className("wrapper main");

    // Verify attributes
    try testing.expectEqualStrings("container", elem.get_id());
    try testing.expectEqualStrings("wrapper main", elem.get_className());
    try testing.expectEqualStrings("div", elem.get_tagName());
}

test "Integration: Document creates multiple elements with different attributes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create multiple elements
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

    // Set different attributes
    try div.set_id("main");
    try div.set_className("container");

    try span.set_id("text");
    try span.set_className("highlight");

    try p.set_id("paragraph");

    // Verify all have correct attributes
    try testing.expectEqualStrings("main", div.get_id());
    try testing.expectEqualStrings("container", div.get_className());

    try testing.expectEqualStrings("text", span.get_id());
    try testing.expectEqualStrings("highlight", span.get_className());

    try testing.expectEqualStrings("paragraph", p.get_id());
    try testing.expectEqualStrings("", p.get_className());
}

test "Integration: Element attribute manipulation" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Set attribute using setAttribute
    try elem.call_setAttribute("data-test", "value1");

    // Get attribute using getAttribute
    const attr = elem.call_getAttribute("data-test");
    try testing.expect(attr != null);
    try testing.expectEqualStrings("value1", attr.?);

    // Check has attribute
    try testing.expect(elem.call_hasAttribute("data-test"));
    try testing.expect(!elem.call_hasAttribute("data-other"));

    // Update attribute
    try elem.call_setAttribute("data-test", "value2");
    const updated = elem.call_getAttribute("data-test");
    try testing.expectEqualStrings("value2", updated.?);

    // Remove attribute
    elem.call_removeAttribute("data-test");
    try testing.expect(!elem.call_hasAttribute("data-test"));
    try testing.expect(elem.call_getAttribute("data-test") == null);
}

test "Integration: Document creates text and comment nodes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create text node
    const text = try doc.call_createTextNode("Hello, World!");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Create comment
    const comment = try doc.call_createComment("This is a comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    // Create element
    const elem = try doc.call_createElement("p");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // All nodes created from same document
    // TODO: Verify they have same ownerDocument when implemented
}

test "Integration: DocumentFragment from document" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const fragment = try doc.call_createDocumentFragment();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment created successfully
    // TODO: Add children to fragment when tree manipulation is implemented
}

test "Integration: Element with namespaced creation" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create SVG element
    const svg = try doc.call_createElementNS("http://www.w3.org/2000/svg", "svg");
    defer {
        svg.deinit();
        allocator.destroy(svg);
    }

    try testing.expectEqualStrings("svg", svg.get_tagName());

    // Create HTML element in XHTML namespace
    const div = try doc.call_createElementNS("http://www.w3.org/1999/xhtml", "div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }

    try testing.expectEqualStrings("div", div.get_tagName());
}

test "Integration: Element slot attribute" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Initially no slot
    try testing.expectEqualStrings("", elem.get_slot());

    // Set slot
    try elem.set_slot("header");
    try testing.expectEqualStrings("header", elem.get_slot());

    // Update slot
    try elem.set_slot("footer");
    try testing.expectEqualStrings("footer", elem.get_slot());
}

test "Integration: Multiple documents create independent elements" {
    const allocator = testing.allocator;

    var doc1 = try Document.init(allocator);
    defer doc1.deinit();

    var doc2 = try Document.init(allocator);
    defer doc2.deinit();

    // Create element from first document
    const elem1 = try doc1.call_createElement("div");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }
    try elem1.set_id("doc1-elem");

    // Create element from second document
    const elem2 = try doc2.call_createElement("div");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }
    try elem2.set_id("doc2-elem");

    // Both elements exist independently
    try testing.expectEqualStrings("doc1-elem", elem1.get_id());
    try testing.expectEqualStrings("doc2-elem", elem2.get_id());
}
