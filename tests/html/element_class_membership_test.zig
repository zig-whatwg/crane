//! An element's class membership follows its class attribute.
//!
//! Lane wb1: these two tests held ElementWithBase's `class_bloom_filter`, a
//! per-element filter that type rebuilt on every class change. Production
//! keeps no such filter: an element's classes are a token list of its
//! Browser's attribute values (dom.element_data's ClassSet, what `.class`
//! selectors and getElementsByClassName ask). What the tests asserted of the
//! filter - a class is found once set, and not found once replaced - is
//! asserted of that membership test, on a real element. The filter's own
//! property (a false positive is possible, a false negative is not) has no
//! production equivalent and is not asserted.
//!
//! Lane lk1 moved the file here from tests/dom (it was element_test.zig):
//! the membership test reads the element's classList, an object its wrapper
//! ends, and tests/dom's realm has no engine (native_read_page.zig). Each
//! test has a page of a real Browser on std.testing.allocator.

const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const native_read_page = @import("native_read_page.zig");

const str = native_read_page.str;

/// Whether `element` has `class`: by a class selector and by classList.
fn hasClass(element: *runtime.Instance, comptime class: []const u8) !bool {
    const matched = try interfaces.Element.call_matches(element, str("." ++ class));
    const listed = try interfaces.DOMTokenList.call_contains(try interfaces.Element.get_classList(element), str(class));
    try std.testing.expectEqual(matched, listed);
    return matched;
}

fn setClass(element: *runtime.Instance, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, str("class"), .{ .domstring = str(value) });
}

fn membershipFollowsTheAttribute(page: native_read_page.Page) !void {
    const elem = try page.element("div");

    // Set class attribute
    try setClass(elem, "container main active");

    // Every class is found
    try std.testing.expect(try hasClass(elem, "container"));
    try std.testing.expect(try hasClass(elem, "main"));
    try std.testing.expect(try hasClass(elem, "active"));

    // Non-existent classes are not found
    try std.testing.expect(!try hasClass(elem, "nonexistent"));
    try std.testing.expect(!try hasClass(elem, "randomclass"));

    // Update class attribute
    try setClass(elem, "new-class different");

    // Old classes are not found any more
    try std.testing.expect(!try hasClass(elem, "container"));
    try std.testing.expect(!try hasClass(elem, "main"));

    // New classes are found
    try std.testing.expect(try hasClass(elem, "new-class"));
    try std.testing.expect(try hasClass(elem, "different"));
}

test "Element - class membership follows the class attribute (was: bloom filter class optimization)" {
    try native_read_page.onPage(membershipFollowsTheAttribute);
}

fn membershipIsUpdatedOnChange(page: native_read_page.Page) !void {
    const elem = try page.element("div");

    // Initially no classes
    try std.testing.expect(!try hasClass(elem, "test"));

    // Add class
    try setClass(elem, "test");
    try std.testing.expect(try hasClass(elem, "test"));

    // Modify class
    try setClass(elem, "modified");
    try std.testing.expect(!try hasClass(elem, "test"));
    try std.testing.expect(try hasClass(elem, "modified"));
}

test "Element - class membership is updated on class change (was: bloom filter updated on class change)" {
    try native_read_page.onPage(membershipIsUpdatedOnChange);
}
