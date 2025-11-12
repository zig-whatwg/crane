const std = @import("std");
const dom = @import("dom");

test "NamedNodeMap.getNamedItemNS - finds attribute by namespace and local name" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with namespace
    var attr = try dom.Attr.init(allocator, "href", "http://www.w3.org/1999/xhtml");
    attr.local_name = "href";
    attr.namespace_uri = "http://www.w3.org/1999/xhtml";
    attr.value = "http://example.com";

    // Add to element
    try element.attributes.append(attr);
    attr.owner_element = element;

    // Get NamedNodeMap
    const map = element.get_attributes();

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
    var attr = try dom.Attr.init(allocator, "href", "http://www.w3.org/1999/xhtml");
    attr.local_name = "href";
    attr.namespace_uri = "http://www.w3.org/1999/xhtml";
    attr.value = "http://example.com";

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = element.get_attributes();

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
    var attr = try dom.Attr.init(allocator, "id", null);
    attr.local_name = "id";
    attr.namespace_uri = null;
    attr.value = "test";

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = element.get_attributes();

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
    var attr1 = try dom.Attr.init(allocator, "href", "http://www.w3.org/1999/xhtml");
    attr1.local_name = "href";
    attr1.namespace_uri = "http://www.w3.org/1999/xhtml";
    attr1.value = "html-value";

    var attr2 = try dom.Attr.init(allocator, "href", "http://www.w3.org/1999/xlink");
    attr2.local_name = "href";
    attr2.namespace_uri = "http://www.w3.org/1999/xlink";
    attr2.value = "xlink-value";

    try element.attributes.append(attr1);
    attr1.owner_element = element;
    try element.attributes.append(attr2);
    attr2.owner_element = element;

    const map = element.get_attributes();

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
    var attr = try dom.Attr.init(allocator, "xlink:href", "http://www.w3.org/1999/xlink");
    attr.prefix = "xlink";
    attr.local_name = "href";
    attr.namespace_uri = "http://www.w3.org/1999/xlink";
    attr.value = "http://example.com";

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = element.get_attributes();

    // Remove by qualified name "xlink:href"
    const removed = try map.call_removeNamedItem("xlink:href");
    try std.testing.expect(removed != null);
    try std.testing.expectEqualStrings("xlink:href", try removed.?.get_name());

    // Verify element no longer has the attribute
    try std.testing.expectEqual(@as(usize, 0), element.attributes.items.len);
}

test "NamedNodeMap - removeNamedItem with local name only (no prefix)" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute without prefix
    var attr = try dom.Attr.init(allocator, "id", null);
    attr.prefix = null;
    attr.local_name = "id";
    attr.namespace_uri = null;
    attr.value = "test";

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = element.get_attributes();

    // Remove by local name "id"
    const removed = try map.call_removeNamedItem("id");
    try std.testing.expect(removed != null);
    try std.testing.expectEqualStrings("id", try removed.?.get_name());

    // Verify element no longer has the attribute
    try std.testing.expectEqual(@as(usize, 0), element.attributes.items.len);
}

test "NamedNodeMap - removeNamedItem returns null for non-existent qualified name" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with prefix
    var attr = try dom.Attr.init(allocator, "xlink:href", "http://www.w3.org/1999/xlink");
    attr.prefix = "xlink";
    attr.local_name = "href";
    attr.namespace_uri = "http://www.w3.org/1999/xlink";
    attr.value = "http://example.com";

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = element.get_attributes();

    // Try to remove by wrong qualified name
    const removed = try map.call_removeNamedItem("svg:href");
    try std.testing.expect(removed == null);

    // Verify element still has the attribute
    try std.testing.expectEqual(@as(usize, 1), element.attributes.items.len);
}

test "NamedNodeMap - removeNamedItem only matches exact qualified name" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Create an attribute with prefix "xlink:href"
    var attr = try dom.Attr.init(allocator, "xlink:href", "http://www.w3.org/1999/xlink");
    attr.prefix = "xlink";
    attr.local_name = "href";
    attr.namespace_uri = "http://www.w3.org/1999/xlink";
    attr.value = "http://example.com";

    try element.attributes.append(attr);
    attr.owner_element = element;

    const map = element.get_attributes();

    // Try to remove by local name only (should fail)
    const removed1 = try map.call_removeNamedItem("href");
    try std.testing.expect(removed1 == null);

    // Verify attribute still exists
    try std.testing.expectEqual(@as(usize, 1), element.attributes.items.len);

    // Remove by full qualified name (should succeed)
    const removed2 = try map.call_removeNamedItem("xlink:href");
    try std.testing.expect(removed2 != null);

    // Verify element no longer has the attribute
    try std.testing.expectEqual(@as(usize, 0), element.attributes.items.len);
}
