//! Element Attributes Tests (DOM Standard §4.10.1)
//! Tests for Element id, className, classList, and slot attributes

const std = @import("std");
const testing = std.testing;
const Element = @import("element").Element;

test "Element: id getter returns empty string when not set" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    const id = elem.get_id();
    try testing.expectEqualStrings("", id);
}

test "Element: id setter and getter" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    // Set id
    try elem.set_id("myElement");
    
    // Get id
    const id = elem.get_id();
    try testing.expectEqualStrings("myElement", id);
    
    // Verify it's stored as attribute
    const attr = elem.call_getAttribute("id");
    try testing.expect(attr != null);
    try testing.expectEqualStrings("myElement", attr.?);
}

test "Element: id can be updated" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    try elem.set_id("first");
    try testing.expectEqualStrings("first", elem.get_id());
    
    try elem.set_id("second");
    try testing.expectEqualStrings("second", elem.get_id());
}

test "Element: className getter returns empty string when not set" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    const className = elem.get_className();
    try testing.expectEqualStrings("", className);
}

test "Element: className setter and getter" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    // Set className
    try elem.set_className("button primary");
    
    // Get className
    const className = elem.get_className();
    try testing.expectEqualStrings("button primary", className);
    
    // Verify it's stored as class attribute
    const attr = elem.call_getAttribute("class");
    try testing.expect(attr != null);
    try testing.expectEqualStrings("button primary", attr.?);
}

test "Element: className can be updated" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    try elem.set_className("foo");
    try testing.expectEqualStrings("foo", elem.get_className());
    
    try elem.set_className("bar baz");
    try testing.expectEqualStrings("bar baz", elem.get_className());
}

test "Element: slot getter returns empty string when not set" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    const slot = elem.get_slot();
    try testing.expectEqualStrings("", slot);
}

test "Element: slot setter and getter" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    // Set slot
    try elem.set_slot("header");
    
    // Get slot
    const slot = elem.get_slot();
    try testing.expectEqualStrings("header", slot);
    
    // Verify it's stored as attribute
    const attr = elem.call_getAttribute("slot");
    try testing.expect(attr != null);
    try testing.expectEqualStrings("header", attr.?);
}

test "Element: slot can be updated" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    try elem.set_slot("header");
    try testing.expectEqualStrings("header", elem.get_slot());
    
    try elem.set_slot("footer");
    try testing.expectEqualStrings("footer", elem.get_slot());
}

test "Element: attributes are independent" {
    const allocator = testing.allocator;
    
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();
    
    // Set multiple attributes
    try elem.set_id("myId");
    try elem.set_className("myClass");
    try elem.set_slot("mySlot");
    
    // Verify all are set correctly
    try testing.expectEqualStrings("myId", elem.get_id());
    try testing.expectEqualStrings("myClass", elem.get_className());
    try testing.expectEqualStrings("mySlot", elem.get_slot());
    
    // Update one shouldn't affect others
    try elem.set_id("newId");
    try testing.expectEqualStrings("newId", elem.get_id());
    try testing.expectEqualStrings("myClass", elem.get_className());
    try testing.expectEqualStrings("mySlot", elem.get_slot());
}
