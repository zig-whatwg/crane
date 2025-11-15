//! Tests for DOM Attribute Change Algorithms
//! Spec: https://dom.spec.whatwg.org/#interface-element (§4.9)

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Element = dom.Element;
const Attr = dom.Attr;
const attribute_algorithms = @import("dom").attribute_algorithms;

test "changeAttribute - updates value and calls handle" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Create and append an attribute
    const attr = try allocator.create(Attr);
    defer {
        attr.deinit();
        allocator.destroy(attr);
    }

    attr.* = try Attr.init(allocator, "class", "foo", null, null);
    try attribute_algorithms.appendAttribute(@ptrCast(attr), @ptrCast(&element));

    // Change the attribute value
    try attribute_algorithms.changeAttribute(@ptrCast(attr), "bar");

    // Verify the value changed
    try std.testing.expectEqualStrings("bar", attr.value);
}

test "appendAttribute - adds to list and handles changes" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    const attr = try allocator.create(Attr);
    defer {
        attr.deinit();
        allocator.destroy(attr);
    }

    attr.* = try Attr.init(allocator, "title", "Hello", null, null);

    // Append the attribute
    try attribute_algorithms.appendAttribute(@ptrCast(attr), @ptrCast(&element));

    // Verify it was added to the attribute list
    try std.testing.expectEqual(@as(usize, 1), element.attributes.size());

    // Verify the attribute's element pointer was set
    try std.testing.expect(attr.owner_element != null);
}

test "removeAttribute - removes from list and handles changes" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    const attr = try allocator.create(Attr);
    defer {
        attr.deinit();
        allocator.destroy(attr);
    }

    attr.* = try Attr.init(allocator, "data-test", "value", null, null);
    try attribute_algorithms.appendAttribute(@ptrCast(attr), @ptrCast(&element));

    // Remove the attribute
    try attribute_algorithms.removeAttribute(attr);

    // Verify it was removed from the list
    try std.testing.expectEqual(@as(usize, 0), element.attributes.size());

    // Verify the attribute's element pointer was cleared
    try std.testing.expect(attr.owner_element == null);
}

test "replaceAttribute - swaps in list and handles changes" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    const old_attr = try allocator.create(Attr);
    defer {
        old_attr.deinit();
        allocator.destroy(old_attr);
    }

    const new_attr = try allocator.create(Attr);
    defer {
        new_attr.deinit();
        allocator.destroy(new_attr);
    }

    old_attr.* = try Attr.init(allocator, "id", "old-id", null, null);
    new_attr.* = try Attr.init(allocator, "id", "new-id", null, null);

    try attribute_algorithms.appendAttribute(old_attr, &element);

    // Replace the attribute
    try attribute_algorithms.replaceAttribute(old_attr, new_attr);

    // Verify the list still has one attribute (the new one)
    try std.testing.expectEqual(@as(usize, 1), element.attributes.size());

    // Verify it's the new attribute
    const attr = element.attributes.get(0).?;
    try std.testing.expectEqualStrings("new-id", attr.value);

    // Verify the old attribute's element pointer was cleared
    try std.testing.expect(old_attr.owner_element == null);

    // Verify the new attribute's element pointer was set
    try std.testing.expect(new_attr.owner_element != null);
}

test "setAttributeValue - creates new attribute if none exists" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Set a new attribute
    try attribute_algorithms.setAttributeValue(&element, "data-foo", "bar", null, null);

    // Verify the attribute was created and added
    try std.testing.expectEqual(@as(usize, 1), element.attributes.size());

    const attr = element.attributes.get(0).?;
    try std.testing.expectEqualStrings("data-foo", attr.local_name);
    try std.testing.expectEqualStrings("bar", attr.value);

    // Clean up the attribute
    attr.deinit();
    allocator.destroy(attr);
}

test "setAttributeValue - changes existing attribute" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    const attr = try allocator.create(Attr);
    defer {
        attr.deinit();
        allocator.destroy(attr);
    }

    attr.* = try Attr.init(allocator, "class", "old-class", null, null);
    try attribute_algorithms.appendAttribute(@ptrCast(attr), @ptrCast(&element));

    // Change the attribute value
    try attribute_algorithms.setAttributeValue(&element, "class", "new-class", null, null);

    // Verify the value changed
    try std.testing.expectEqualStrings("new-class", attr.value);

    // Verify we still have only one attribute
    try std.testing.expectEqual(@as(usize, 1), element.attributes.size());
}

test "ID attribute change steps - sets element's unique ID" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Set the id attribute
    try attribute_algorithms.setAttributeValue(&element, "id", "my-element", null, null);

    // Verify the unique_id field was set
    try std.testing.expect(element.unique_id != null);
    try std.testing.expectEqualStrings("my-element", element.unique_id.?);

    // Clean up the attribute
    if (element.attributes.get(0)) |attr| {
        attr.deinit();
        allocator.destroy(attr);
    }
}

test "ID attribute change steps - unsets element's unique ID on empty value" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Set the id attribute first
    try attribute_algorithms.setAttributeValue(&element, "id", "my-element", null, null);
    try std.testing.expect(element.unique_id != null);

    // Change to empty string
    try attribute_algorithms.setAttributeValue(&element, "id", "", null, null);

    // Verify the unique_id field was cleared
    try std.testing.expect(element.unique_id == null);

    // Clean up the attribute
    if (element.attributes.get(0)) |attr| {
        attr.deinit();
        allocator.destroy(attr);
    }
}

test "ID attribute change steps - updates unique ID on change" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Set initial id
    try attribute_algorithms.setAttributeValue(&element, "id", "first-id", null, null);
    try std.testing.expectEqualStrings("first-id", element.unique_id.?);

    // Change to new id
    try attribute_algorithms.setAttributeValue(&element, "id", "second-id", null, null);

    // Verify the unique_id was updated
    try std.testing.expectEqualStrings("second-id", element.unique_id.?);

    // Clean up the attribute
    if (element.attributes.get(0)) |attr| {
        attr.deinit();
        allocator.destroy(attr);
    }
}

test "namespace attribute handling" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "svg");
    defer element.deinit();

    const ns = "http://www.w3.org/2000/svg";

    // Set an attribute with namespace
    try attribute_algorithms.setAttributeValue(&element, "width", "100", null, ns);

    // Verify it was created
    try std.testing.expectEqual(@as(usize, 1), element.attributes.size());

    const attr = element.attributes.get(0).?;
    try std.testing.expectEqualStrings("width", attr.local_name);
    try std.testing.expectEqualStrings("100", attr.value);
    try std.testing.expect(attr.namespace_uri != null);
    try std.testing.expectEqualStrings(ns, attr.namespace_uri.?);

    // Clean up the attribute
    attr.deinit();
    allocator.destroy(attr);
}
