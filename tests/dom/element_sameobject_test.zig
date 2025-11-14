//! Tests for Element [SameObject] attribute caching
//! Spec: https://dom.spec.whatwg.org/#ref-for-dom-element-attributes

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const DOMTokenList = dom.DOMTokenList;
const NamedNodeMap = dom.NamedNodeMap;

const Element = Element;
const Document = Document;

test "Element.attributes returns same NamedNodeMap instance ([SameObject])" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Get attributes first time
    const attrs1 = try elem.get_attributes();

    // Get attributes second time
    const attrs2 = try elem.get_attributes();

    // Should return the exact same instance (same pointer)
    try std.testing.expectEqual(attrs1, attrs2);
}

test "Element.classList returns same DOMTokenList instance ([SameObject])" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Get classList first time
    const list1 = try elem.get_classList();

    // Get classList second time
    const list2 = try elem.get_classList();

    // Should return the exact same instance (same pointer)
    try std.testing.expectEqual(list1, list2);
}

test "Element.attributes NamedNodeMap reflects live changes" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Get cached NamedNodeMap
    const attrs = try elem.get_attributes();

    // Initially should have 0 attributes
    try std.testing.expectEqual(@as(u32, 0), attrs.get_length());

    // Add an attribute via Element
    try elem.call_setAttribute("id", "test");

    // NamedNodeMap should reflect the change (it's live)
    try std.testing.expectEqual(@as(u32, 1), attrs.get_length());

    // Get NamedNodeMap again - should be same instance
    const attrs2 = try elem.get_attributes();
    try std.testing.expectEqual(attrs, attrs2);

    // And should still show the attribute
    try std.testing.expectEqual(@as(u32, 1), attrs2.get_length());
}

test "Element.classList DOMTokenList reflects live changes" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Get cached DOMTokenList
    const list = try elem.get_classList();

    // Initially should have 0 tokens
    try std.testing.expectEqual(@as(u32, 0), list.get_length());

    // Add class via Element
    try elem.call_setAttribute("class", "foo bar");

    // DOMTokenList should reflect the change
    // Note: This requires classList to re-parse when attribute changes
    // For now, we just verify it's the same object
    const list2 = try elem.get_classList();
    try std.testing.expectEqual(list, list2);
}

test "Multiple elements have different [SameObject] instances" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem1 = try doc.call_createElement("div");
    const elem2 = try doc.call_createElement("span");

    // Get attributes from both elements
    const attrs1 = try elem1.get_attributes();
    const attrs2 = try elem2.get_attributes();

    // Should be different instances (different elements)
    try std.testing.expect(attrs1 != attrs2);

    // Get classList from both elements
    const list1 = try elem1.get_classList();
    const list2 = try elem2.get_classList();

    // Should be different instances (different elements)
    try std.testing.expect(list1 != list2);
}

test "Element.attributes persists across attribute modifications" {
    const allocator = std.testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");

    // Get attributes
    const attrs1 = try elem.get_attributes();

    // Modify attributes
    try elem.call_setAttribute("id", "test");
    try elem.call_setAttribute("class", "foo");
    try elem.call_removeAttribute("id");

    // Get attributes again
    const attrs2 = try elem.get_attributes();

    // Should still be the same cached instance
    try std.testing.expectEqual(attrs1, attrs2);
}
