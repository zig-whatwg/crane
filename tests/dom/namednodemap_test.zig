//! NamedNodeMap Tests (DOM Standard §4.9)
//! Tests for NamedNodeMap interface

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const testing = std.testing;
const NamedNodeMap = @import("NamedNodeMap").NamedNodeMap;


// Type aliases
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

    // Add an attribute directly to element
    const attr = Attr{ .name = "id", .value = "test" };
    try elem.attributes.append(attr);

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
    try elem.attributes.append(Attr{ .name = "id", .value = "test" });
    try elem.attributes.append(Attr{ .name = "class", .value = "button" });

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    const first = map.call_item(0);
    try testing.expect(first != null);
    try testing.expectEqualStrings("id", first.?.name);
    try testing.expectEqualStrings("test", first.?.value);

    const second = map.call_item(1);
    try testing.expect(second != null);
    try testing.expectEqualStrings("class", second.?.name);
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
    try elem.attributes.append(Attr{ .name = "id", .value = "test-id" });
    try elem.attributes.append(Attr{ .name = "class", .value = "btn" });
    try elem.attributes.append(Attr{ .name = "data-value", .value = "123" });

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

    try elem.attributes.append(Attr{ .name = "id", .value = "test" });

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
    try elem.attributes.append(Attr{ .name = "id", .value = "test" });

    // Map reflects the change (it's live)
    try testing.expectEqual(@as(u32, 1), map.get_length());
    const attr = map.call_item(0);
    try testing.expect(attr != null);
    try testing.expectEqualStrings("id", attr.?.name);
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
    try elem.attributes.append(Attr{ .name = "type", .value = "text" });
    try elem.attributes.append(Attr{ .name = "name", .value = "username" });
    try elem.attributes.append(Attr{ .name = "placeholder", .value = "Enter name" });
    try elem.attributes.append(Attr{ .name = "required", .value = "" });

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    try testing.expectEqual(@as(u32, 4), map.get_length());

    // Check order is preserved
    try testing.expectEqualStrings("type", map.call_item(0).?.name);
    try testing.expectEqualStrings("name", map.call_item(1).?.name);
    try testing.expectEqualStrings("placeholder", map.call_item(2).?.name);
    try testing.expectEqualStrings("required", map.call_item(3).?.name);
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

    try elem.attributes.append(Attr{ .name = "DataValue", .value = "test" });

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

    try elem.attributes.append(Attr{ .name = "disabled", .value = "" });

    var map = NamedNodeMap.init(elem);
    defer map.deinit();

    const attr = map.call_getNamedItem("disabled");
    try testing.expect(attr != null);
    try testing.expectEqualStrings("", attr.?.value);
}
