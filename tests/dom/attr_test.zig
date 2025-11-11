//! Attr Tests (DOM Standard §4.9)
//! Tests for Attr interface

const std = @import("std");
const testing = std.testing;
const Attr = @import("attr").Attr;

test "Attr: init creates attribute with local name only" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, null, null, "id", "test");
    defer attr.deinit();

    try testing.expect(attr.get_namespaceURI() == null);
    try testing.expect(attr.get_prefix() == null);
    try testing.expectEqualStrings("id", attr.get_localName());
    try testing.expectEqualStrings("test", attr.get_value());
}

test "Attr: init with namespace and prefix" {
    const allocator = testing.allocator;

    var attr = try Attr.init(
        allocator,
        "http://www.w3.org/2000/xmlns/",
        "xmlns",
        "custom",
        "http://example.com",
    );
    defer attr.deinit();

    try testing.expect(attr.get_namespaceURI() != null);
    try testing.expectEqualStrings("http://www.w3.org/2000/xmlns/", attr.get_namespaceURI().?);
    try testing.expect(attr.get_prefix() != null);
    try testing.expectEqualStrings("xmlns", attr.get_prefix().?);
    try testing.expectEqualStrings("custom", attr.get_localName());
}

test "Attr: name returns qualified name with prefix" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, "http://example.com", "ex", "attr", "value");
    defer attr.deinit();

    const name = try attr.get_name();
    defer allocator.free(name);

    try testing.expectEqualStrings("ex:attr", name);
}

test "Attr: name returns local name without prefix" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, null, null, "id", "test");
    defer attr.deinit();

    const name = try attr.get_name();
    // No prefix, so name returns localName directly (no allocation)
    try testing.expectEqualStrings("id", name);
}

test "Attr: value getter and setter" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, null, null, "class", "button");
    defer attr.deinit();

    try testing.expectEqualStrings("button", attr.get_value());

    try attr.set_value("link");
    try testing.expectEqualStrings("link", attr.get_value());
}

test "Attr: value setter with empty string" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, null, null, "disabled", "true");
    defer attr.deinit();

    try attr.set_value("");
    try testing.expectEqualStrings("", attr.get_value());
}

test "Attr: ownerElement is null by default" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, null, null, "id", "test");
    defer attr.deinit();

    try testing.expect(attr.get_ownerElement() == null);
}

test "Attr: specified always returns true" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, null, null, "test", "value");
    defer attr.deinit();

    try testing.expect(attr.get_specified() == true);
}

test "Attr: xmlns attribute with namespace" {
    const allocator = testing.allocator;

    var attr = try Attr.init(
        allocator,
        "http://www.w3.org/2000/xmlns/",
        "xmlns",
        "svg",
        "http://www.w3.org/2000/svg",
    );
    defer attr.deinit();

    try testing.expectEqualStrings("http://www.w3.org/2000/xmlns/", attr.get_namespaceURI().?);
    try testing.expectEqualStrings("xmlns", attr.get_prefix().?);
    try testing.expectEqualStrings("svg", attr.get_localName());
    try testing.expectEqualStrings("http://www.w3.org/2000/svg", attr.get_value());

    const name = try attr.get_name();
    defer allocator.free(name);
    try testing.expectEqualStrings("xmlns:svg", name);
}

test "Attr: xlink attribute" {
    const allocator = testing.allocator;

    var attr = try Attr.init(
        allocator,
        "http://www.w3.org/1999/xlink",
        "xlink",
        "href",
        "http://example.com",
    );
    defer attr.deinit();

    const name = try attr.get_name();
    defer allocator.free(name);

    try testing.expectEqualStrings("xlink:href", name);
    try testing.expectEqualStrings("href", attr.get_localName());
}

test "Attr: multiple value changes" {
    const allocator = testing.allocator;

    var attr = try Attr.init(allocator, null, null, "style", "color: red");
    defer attr.deinit();

    try testing.expectEqualStrings("color: red", attr.get_value());

    try attr.set_value("color: blue");
    try testing.expectEqualStrings("color: blue", attr.get_value());

    try attr.set_value("display: none");
    try testing.expectEqualStrings("display: none", attr.get_value());
}

test "Attr: empty local name is allowed" {
    const allocator = testing.allocator;

    // Spec says local name is non-empty, but we should handle edge case
    var attr = try Attr.init(allocator, null, null, "", "");
    defer attr.deinit();

    try testing.expectEqualStrings("", attr.get_localName());
    try testing.expectEqualStrings("", attr.get_value());
}
