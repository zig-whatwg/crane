//! Tests for Document string interning feature
//! Tests memory savings and pointer equality optimization

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Document = dom.Document;
const Element = dom.Element;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "Document - internString basic functionality" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Intern first string
    const str1 = try doc.internString("div");
    try expectEqualStrings("div", str1);

    // Intern same string again - should return same pointer
    const str2 = try doc.internString("div");
    try expectEqualStrings("div", str2);

    // Pointer equality check - both should point to same memory
    try expect(str1.ptr == str2.ptr);
    try expectEqual(str1.len, str2.len);
}

test "Document - internString different strings" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    const div = try doc.internString("div");
    const span = try doc.internString("span");
    const p = try doc.internString("p");

    // All should have correct values
    try expectEqualStrings("div", div);
    try expectEqualStrings("span", span);
    try expectEqualStrings("p", p);

    // All should have different pointers
    try expect(div.ptr != span.ptr);
    try expect(div.ptr != p.ptr);
    try expect(span.ptr != p.ptr);
}

test "Document - internString repeated calls" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Intern same string multiple times
    const str1 = try doc.internString("button");
    const str2 = try doc.internString("button");
    const str3 = try doc.internString("button");
    const str4 = try doc.internString("button");

    // All should return the same pointer
    try expect(str1.ptr == str2.ptr);
    try expect(str1.ptr == str3.ptr);
    try expect(str1.ptr == str4.ptr);
}

test "Document - internString empty string" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    const empty1 = try doc.internString("");
    const empty2 = try doc.internString("");

    try expectEqualStrings("", empty1);
    try expectEqualStrings("", empty2);
    try expect(empty1.ptr == empty2.ptr);
}

test "Document - internString common tag names" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Common HTML tags
    const tags = [_][]const u8{
        "div", "span", "p",     "a",  "img", "h1",   "h2",    "h3",
        "ul",  "li",   "table", "tr", "td",  "form", "input",
    };

    var interned_tags: [tags.len][]const u8 = undefined;

    // Intern all tags
    for (tags, 0..) |tag, i| {
        interned_tags[i] = try doc.internString(tag);
        try expectEqualStrings(tag, interned_tags[i]);
    }

    // Intern again and verify same pointers
    for (tags, 0..) |tag, i| {
        const re_interned = try doc.internString(tag);
        try expect(interned_tags[i].ptr == re_interned.ptr);
    }
}

test "Document - createElement uses interned strings" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Intern a tag name first
    const interned_div = try doc.internString("div");

    // Create element with same tag name
    const element = try doc.call_createElement("div");
    defer {
        element.deinit();
        allocator.destroy(element);
    }

    // Element's tag name should be the same interned string
    try expect(element.tag_name.ptr == interned_div.ptr);
    try expectEqualStrings("div", element.tag_name);
}

test "Document - multiple elements share interned tag names" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Create multiple elements with same tag name
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

    const div3 = try doc.call_createElement("div");
    defer {
        div3.deinit();
        allocator.destroy(div3);
    }

    // All should share the same interned string
    try expect(div1.tag_name.ptr == div2.tag_name.ptr);
    try expect(div1.tag_name.ptr == div3.tag_name.ptr);
    try expectEqualStrings("div", div1.tag_name);
    try expectEqualStrings("div", div2.tag_name);
    try expectEqualStrings("div", div3.tag_name);
}

test "Document - memory cleanup of interned strings" {
    const allocator = std.testing.allocator;

    // Create and destroy document
    {
        const doc = try allocator.create(Document);
        defer allocator.destroy(doc);
        doc.* = try Document.init(allocator);

        // Intern several strings
        _ = try doc.internString("div");
        _ = try doc.internString("span");
        _ = try doc.internString("p");
        _ = try doc.internString("a");

        // deinit should free all interned strings
        doc.deinit();
    }

    // If memory cleanup worked correctly, no leaks should be detected
    // (std.testing.allocator will fail the test if there are leaks)
}

test "Document - internString with special characters" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Test with special characters (Unicode)
    const str1 = try doc.internString("custom-element");
    const str2 = try doc.internString("custom-element");
    const str3 = try doc.internString("café");
    const str4 = try doc.internString("café");

    try expectEqualStrings("custom-element", str1);
    try expect(str1.ptr == str2.ptr);

    try expectEqualStrings("café", str3);
    try expect(str3.ptr == str4.ptr);

    try expect(str1.ptr != str3.ptr);
}

test "Document - internString performance characteristic" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Intern a few strings
    const div = try doc.internString("div");
    const span = try doc.internString("span");
    const p = try doc.internString("p");

    // Second intern should be fast (hash lookup only, no allocation)
    const div2 = try doc.internString("div");
    const span2 = try doc.internString("span");
    const p2 = try doc.internString("p");

    // Verify pointer equality (demonstrating O(1) comparison)
    try expect(div.ptr == div2.ptr);
    try expect(span.ptr == span2.ptr);
    try expect(p.ptr == p2.ptr);
}

test "Document - string comparison via pointer equality" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    const div1 = try doc.internString("div");
    const div2 = try doc.internString("div");
    const span1 = try doc.internString("span");

    // Fast comparison: pointer equality
    try expect(div1.ptr == div2.ptr); // Same tag - O(1) comparison
    try expect(div1.ptr != span1.ptr); // Different tag - O(1) comparison

    // This is much faster than:
    // std.mem.eql(u8, div1, div2) // O(n) comparison
}

test "Document - internString with dynamically allocated strings" {
    const allocator = std.testing.allocator;

    const doc = try allocator.create(Document);
    defer allocator.destroy(doc);
    doc.* = try Document.init(allocator);
    defer doc.deinit();

    // Create a dynamically allocated string
    const dynamic_str = try std.fmt.allocPrint(allocator, "element-{d}", .{42});
    defer allocator.free(dynamic_str);

    // Intern it
    const interned = try doc.internString(dynamic_str);
    try expectEqualStrings("element-42", interned);

    // Intern another copy of the same value
    const dynamic_str2 = try std.fmt.allocPrint(allocator, "element-{d}", .{42});
    defer allocator.free(dynamic_str2);

    const interned2 = try doc.internString(dynamic_str2);

    // Should return the same interned copy
    try expect(interned.ptr == interned2.ptr);
}
