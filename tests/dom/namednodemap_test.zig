//! NamedNodeMap Tests (DOM Standard §4.9)
//! Tests for NamedNodeMap interface

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const testing = std.testing;

// Type aliases
const NamedNodeMap = dom.NamedNodeMap;
const Attr = dom.Attr;
const Document = dom.Document;

test "NamedNodeMap: init creates empty map" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    try testing.expectEqual(@as(u32, 0), map.get_length());
}

test "NamedNodeMap: length returns attribute count" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Add an attribute to element
    try elem.call_setAttribute("id", "test");

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    try testing.expectEqual(@as(u32, 1), map.get_length());
}

test "NamedNodeMap: item returns attribute at index" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Add attributes
    try elem.call_setAttribute("id", "test");
    try elem.call_setAttribute("class", "button");

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    const first = map.call_item(0);
    try testing.expect(first != null);
    const first_name = try first.?.get_name();
    defer allocator.free(first_name);
    try testing.expectEqualStrings("id", first_name);
    try testing.expectEqualStrings("test", first.?.value);

    const second = map.call_item(1);
    try testing.expect(second != null);
    const second_name = try second.?.get_name();
    defer allocator.free(second_name);
    try testing.expectEqualStrings("class", second_name);
    try testing.expectEqualStrings("button", second.?.value);
}

test "NamedNodeMap: item returns null for out of bounds" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    try testing.expect(map.call_item(0) == null);
    try testing.expect(map.call_item(999) == null);
}

test "NamedNodeMap: getNamedItem finds attribute by name" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Add attributes
    try elem.call_setAttribute("id", "test-id");
    try elem.call_setAttribute("class", "btn");
    try elem.call_setAttribute("data-value", "123");

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    const id_attr = map.call_getNamedItem("id");
    try testing.expect(id_attr != null);
    try testing.expectEqualStrings("test-id", id_attr.?.value);

    const class_attr = map.call_getNamedItem("class");
    try testing.expect(class_attr != null);
    try testing.expectEqualStrings("btn", class_attr.?.value);

    const data_attr = map.call_getNamedItem("data-value");
    try testing.expect(data_attr != null);
    try testing.expectEqualStrings("123", data_attr.?.value);
}

test "NamedNodeMap: getNamedItem returns null for missing attribute" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    try elem.call_setAttribute("id", "test");

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    try testing.expect(map.call_getNamedItem("missing") == null);
    try testing.expect(map.call_getNamedItem("nonexistent") == null);
}

test "NamedNodeMap: is live collection" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    // Initially empty
    try testing.expectEqual(@as(u32, 0), map.get_length());

    // Add attribute to element
    try elem.call_setAttribute("id", "test");

    // Map reflects the change (it's live)
    try testing.expectEqual(@as(u32, 1), map.get_length());
    const attr = map.call_item(0);
    try testing.expect(attr != null);
    const attr_name = try attr.?.get_name();
    defer allocator.free(attr_name);
    try testing.expectEqualStrings("id", attr_name);
}

test "NamedNodeMap: multiple attributes in order" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("input");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Add multiple attributes
    try elem.call_setAttribute("type", "text");
    try elem.call_setAttribute("name", "username");
    try elem.call_setAttribute("placeholder", "Enter name");
    try elem.call_setAttribute("required", "");

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    try testing.expectEqual(@as(u32, 4), map.get_length());

    // Check order is preserved
    const name0 = try map.call_item(0).?.get_name();
    defer allocator.free(name0);
    try testing.expectEqualStrings("type", name0);

    const name1 = try map.call_item(1).?.get_name();
    defer allocator.free(name1);
    try testing.expectEqualStrings("name", name1);

    const name2 = try map.call_item(2).?.get_name();
    defer allocator.free(name2);
    try testing.expectEqualStrings("placeholder", name2);

    const name3 = try map.call_item(3).?.get_name();
    defer allocator.free(name3);
    try testing.expectEqualStrings("required", name3);
}

test "NamedNodeMap: getNamedItem is case-sensitive" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    try elem.call_setAttribute("DataValue", "test");

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    // Exact match works
    const exact = map.call_getNamedItem("DataValue");
    try testing.expect(exact != null);
    try testing.expectEqualStrings("test", exact.?.value);

    // Different case doesn't match
    try testing.expect(map.call_getNamedItem("datavalue") == null);
    try testing.expect(map.call_getNamedItem("DATAVALUE") == null);
}

test "NamedNodeMap: empty attribute value" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    try elem.call_setAttribute("disabled", "");

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    const attr = map.call_getNamedItem("disabled");
    try testing.expect(attr != null);
    try testing.expectEqualStrings("", attr.?.value);
}
