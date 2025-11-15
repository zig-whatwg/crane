const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Attr = dom.Attr;
const Document = dom.Document;
const NamedNodeMap = dom.NamedNodeMap;

test "NamedNodeMap.getNamedItemNS - finds attribute by namespace and local name" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with namespace
    var attr = try dom.Attr.init(allocator, "http://www.w3.org/1999/xhtml", null, "href", "http://example.com");

    // Add to element
    try element.attributes.append(attr);
    attr.owner_element = element;

    // Get NamedNodeMap
    const map = try element.get_attributes();

    // Get attribute by namespace and local name
    const found = map.call_getNamedItemNS("http://www.w3.org/1999/xhtml", "href");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("href", found.?.local_name);
    try std.testing.expectEqualStrings("http://example.com", found.?.value);
}

test "NamedNodeMap.getNamedItemNS - returns null for non-existent attribute" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with namespace
    var attr = try dom.Attr.init(allocator, "http://www.w3.org/1999/xhtml", null, "href", "http://example.com");

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = try element.get_attributes();

    // Try to get attribute with wrong namespace
    const found = map.call_getNamedItemNS("http://www.w3.org/2000/svg", "href");
    try std.testing.expect(found == null);
}

test "NamedNodeMap.getNamedItemNS - handles null namespace" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute without namespace
    var attr = try dom.Attr.init(allocator, null, null, "id", "test-id");

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = try element.get_attributes();

    // Get attribute by null namespace and local name
    const found = map.call_getNamedItemNS(null, "id");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("id", found.?.local_name);
    try std.testing.expectEqualStrings("test", found.?.value);
}

test "NamedNodeMap.getNamedItemNS - distinguishes same local name in different namespaces" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create two attributes with same local name but different namespaces
    var attr1 = try dom.Attr.init(allocator, "http://www.w3.org/1999/xhtml", null, "href", "html-value");

    var attr2 = try dom.Attr.init(allocator, "http://www.w3.org/1999/xlink", null, "href", "xlink-value");

    try element.attributes.append(attr1);
    attr1.owner_element = element;
    try element.attributes.append(attr2);
    attr2.owner_element = element;

    const map = try element.get_attributes();

    // Get XHTML href
    const found1 = map.call_getNamedItemNS("http://www.w3.org/1999/xhtml", "href");
    try std.testing.expect(found1 != null);
    try std.testing.expectEqualStrings("html-value", found1.?.value);

    // Get XLink href
    const found2 = map.call_getNamedItemNS("http://www.w3.org/1999/xlink", "href");
    try std.testing.expect(found2 != null);
    try std.testing.expectEqualStrings("xlink-value", found2.?.value);
}

test "NamedNodeMap - removeNamedItem with qualified name (prefix:localName)" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with prefix and namespace
    var attr = try dom.Attr.init(allocator, "http://www.w3.org/1999/xlink", "xlink", "href", "http://example.com");

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = try element.get_attributes();

    // Remove by qualified name "xlink:href"
    const removed = try map.call_removeNamedItem("xlink:href");
    const removed_name = try removed.get_name();
    defer allocator.free(removed_name);
    try std.testing.expectEqualStrings("xlink:href", removed_name);

    // Verify element no longer has the attribute
    try std.testing.expectEqual(@as(usize, 0), element.attributes.toSlice().len);
}

test "NamedNodeMap - removeNamedItem with local name only (no prefix)" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute without prefix
    var attr = try dom.Attr.init(allocator, null, null, "id", "test");

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = try element.get_attributes();

    // Remove by local name "id"
    const removed = try map.call_removeNamedItem("id");
    const removed_name = try removed.get_name();
    defer allocator.free(removed_name);
    try std.testing.expectEqualStrings("id", removed_name);

    // Verify element no longer has the attribute
    try std.testing.expectEqual(@as(usize, 0), element.attributes.toSlice().len);
}

test "NamedNodeMap - removeNamedItem returns null for non-existent qualified name" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with prefix
    var attr = try dom.Attr.init(allocator, "http://www.w3.org/1999/xlink", "xlink", "href", "http://example.com");

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = try element.get_attributes();

    // Try to remove by wrong qualified name (should throw NotFoundError)
    try std.testing.expectError(error.NotFoundError, map.call_removeNamedItem("svg:href"));

    // Verify element still has the attribute
    try std.testing.expectEqual(@as(usize, 1), element.attributes.toSlice().len);
}

test "NamedNodeMap - removeNamedItem only matches exact qualified name" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with prefix "xlink:href"
    var attr = try dom.Attr.init(allocator, "http://www.w3.org/1999/xlink", "xlink", "href", "http://example.com");

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = try element.get_attributes();

    // Try to remove by local name only (should throw NotFoundError)
    try std.testing.expectError(error.NotFoundError, map.call_removeNamedItem("href"));

    // Verify attribute still exists
    try std.testing.expectEqual(@as(usize, 1), element.attributes.toSlice().len);

    // Remove by full qualified name (should succeed)
    _ = try map.call_removeNamedItem("xlink:href");

    // Verify element no longer has the attribute
    try std.testing.expectEqual(@as(usize, 0), element.attributes.toSlice().len);
}
