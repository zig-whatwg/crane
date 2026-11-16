//! An element's class membership follows its class attribute.
//!
//! Lane wb1: these two tests held ElementWithBase's `class_bloom_filter`, a
//! per-element filter that type rebuilt on every class change. Production
//! keeps no such filter: an element's classes are a token list of its
//! Browser's attribute values (dom.element_data's ClassSet, what `.class`
//! selectors and getElementsByClassName ask). What the tests asserted of the
//! filter - a class is found once set, and not found once replaced - is
//! asserted of that membership test, on a real element (real_nodes.zig). The
//! filter's own property (a false positive is possible, a false negative is
//! not) has no production equivalent and is not asserted.

const std = @import("std");
const interfaces = @import("interfaces");
const real_nodes = @import("real_nodes.zig");

const str = real_nodes.str;

/// Whether `element` has `class`: by a class selector and by classList.
fn hasClass(element: *real_nodes.Instance, comptime class: []const u8) !bool {
    const matched = try interfaces.Element.call_matches(element, str("." ++ class));
    const listed = try interfaces.DOMTokenList.call_contains(try interfaces.Element.get_classList(element), str(class));
    try std.testing.expectEqual(matched, listed);
    return matched;
}

test "Element - class membership follows the class attribute (was: bloom filter class optimization)" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const elem = try nodes.element(try nodes.document(), "div");

    // Set class attribute
    try nodes.setAttribute(elem, "class", "container main active");

    // Every class is found
    try std.testing.expect(try hasClass(elem, "container"));
    try std.testing.expect(try hasClass(elem, "main"));
    try std.testing.expect(try hasClass(elem, "active"));

    // Non-existent classes are not found
    try std.testing.expect(!try hasClass(elem, "nonexistent"));
    try std.testing.expect(!try hasClass(elem, "randomclass"));

    // Update class attribute
    try nodes.setAttribute(elem, "class", "new-class different");

    // Old classes are not found any more
    try std.testing.expect(!try hasClass(elem, "container"));
    try std.testing.expect(!try hasClass(elem, "main"));

    // New classes are found
    try std.testing.expect(try hasClass(elem, "new-class"));
    try std.testing.expect(try hasClass(elem, "different"));
}

test "Element - class membership is updated on class change (was: bloom filter updated on class change)" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(std.testing.allocator);
    defer nodes.close();
    const elem = try nodes.element(try nodes.document(), "div");

    // Initially no classes
    try std.testing.expect(!try hasClass(elem, "test"));

    // Add class
    try nodes.setAttribute(elem, "class", "test");
    try std.testing.expect(try hasClass(elem, "test"));

    // Modify class
    try nodes.setAttribute(elem, "class", "modified");
    try std.testing.expect(!try hasClass(elem, "test"));
    try std.testing.expect(try hasClass(elem, "modified"));
}
