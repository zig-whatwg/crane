//! Tests migrated from webidl/src/dom/dom.Document.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;

test "dom.Document - internString basic deduplication" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(dom.Document);
    defer allocator.destroy(doc);
    doc.* = try dom.Document.init(allocator);
    defer doc.deinit();

    // Intern same string twice
    const str1 = try doc.internString("div");
    const str2 = try doc.internString("div");

    // Should return same pointer (deduplicated)
    try std.testing.expect(str1.ptr == str2.ptr);
    try std.testing.expectEqualStrings("div", str1);
}
test "dom.Document - internString different strings" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(dom.Document);
    defer allocator.destroy(doc);
    doc.* = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.internString("div");
    const span = try doc.internString("span");

    // Different strings should have different pointers
    try std.testing.expect(div.ptr != span.ptr);
    try std.testing.expectEqualStrings("div", div);
    try std.testing.expectEqualStrings("span", span);
}
test "dom.Document - createElement uses interned tag names" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(dom.Document);
    defer allocator.destroy(doc);
    doc.* = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create multiple elements with same tag
    const div1 = try doc.call_createElement("div");
    defer {
        div1.deinit();
        allocator.destroy(div1);
    }

    const div2 = try doc.call_createElement("div");
    defer {
        div2.deinit();
        allocator.destroy(div2);
    }

    // Both elements should share the same interned tag name
    try std.testing.expect(div1.tag_name.ptr == div2.tag_name.ptr);
    try std.testing.expectEqualStrings("div", div1.tag_name);
}
test "dom.Document - string interning memory cleanup" {
    const allocator = std.testing.allocator;

    // Create and destroy document with interned strings
    {
        const doc = try allocator.create(dom.Document);
        defer allocator.destroy(doc);
        doc.* = try dom.Document.init(allocator);

        // Intern several strings
        _ = try doc.internString("div");
        _ = try doc.internString("span");
        _ = try doc.internString("p");

        // deinit should free all interned strings
        doc.deinit();
    }

    // std.testing.allocator will fail if there are memory leaks
}