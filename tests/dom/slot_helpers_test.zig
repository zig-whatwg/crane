//! Tests migrated from src/dom/slot_helpers.zig
//! Per WHATWG specifications

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// slot_helpers is available through dom module
const slot_helpers = dom.slot_helpers;
// Type aliases
const Element = dom.Element;
// Note: slot_helpers functions are available as dom.isElement, dom.asElement, etc.

test "slot_helpers - isElement" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Element should be recognized
    try std.testing.expect(dom.isElement(@ptrCast(&element)));
}
test "slot_helpers - asElement" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Should successfully cast to Element
    const maybe_elem = dom.asElement(@ptrCast(&element));
    try std.testing.expect(maybe_elem != null);

    if (maybe_elem) |elem| {
        try std.testing.expectEqualStrings("div", elem.tag_name);
    }
}
test "slot_helpers - isSlottable" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Elements are slottables
    try std.testing.expect(slot_helpers.isSlottable(@ptrCast(&element)));
}
test "slot_helpers - isSlot detects slot elements" {
    const allocator = std.testing.allocator;

    var slot_elem = try Element.init(allocator, "slot");
    defer slot_elem.deinit();

    var div_elem = try Element.init(allocator, "div");
    defer div_elem.deinit();

    // Slot element should be detected
    try std.testing.expect(slot_helpers.isSlot(@ptrCast(&slot_elem)));

    // Non-slot element should not be detected
    try std.testing.expect(!slot_helpers.isSlot(@ptrCast(&div_elem)));
}
test "slot_helpers - getSlottableName" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Default slottable name is empty
    const name = slot_helpers.getSlottableName(@ptrCast(&element));
    try std.testing.expectEqualStrings("", name);

    // Set a name
    element.Slottable.setSlottableName("header");
    const name2 = slot_helpers.getSlottableName(@ptrCast(&element));
    try std.testing.expectEqualStrings("header", name2);
}
