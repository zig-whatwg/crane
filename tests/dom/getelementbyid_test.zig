const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Node = dom.Node;

test "Document.getElementById - finds element by id attribute" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create element with id
    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));

    // Set id attribute
    try div.call_setAttribute("id", "test-id");

    // Find by id
    const found = doc.call_getElementById("test-id");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(div)), @as(*Node, @ptrCast(found.?)));
}

test "Document.getElementById - returns null for non-existent id" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));
    try div.call_setAttribute("id", "existing");

    // Try to find non-existent id
    const found = doc.call_getElementById("nonexistent");
    try std.testing.expect(found == null);
}

test "Document.getElementById - finds nested element" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create nested structure: div > span > em
    const div = try doc.call_createElement("div");
    const span = try doc.call_createElement("span");
    const em = try doc.call_createElement("em");

    _ = try doc.call_appendChild(@ptrCast(div));
    _ = try div.call_appendChild(@ptrCast(span));
    _ = try span.call_appendChild(@ptrCast(em));

    // Set id on deeply nested element
    try em.call_setAttribute("id", "nested");

    // Find by id
    const found = doc.call_getElementById("nested");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(em)), @as(*Node, @ptrCast(found.?)));
}

test "Document.getElementById - returns first element when multiple have same id" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create two elements with same id (not spec-compliant, but should handle gracefully)
    const div1 = try doc.call_createElement("div");
    const div2 = try doc.call_createElement("div");

    _ = try doc.call_appendChild(@ptrCast(div1));
    _ = try doc.call_appendChild(@ptrCast(div2));

    try div1.call_setAttribute("id", "duplicate");
    try div2.call_setAttribute("id", "duplicate");

    // Should return first in tree order
    const found = doc.call_getElementById("duplicate");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(div1)), @as(*Node, @ptrCast(found.?)));
}

test "Document.getElementById - case sensitive matching" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));
    try div.call_setAttribute("id", "MyID");

    // Case sensitive - should not match
    const found_lower = doc.call_getElementById("myid");
    try std.testing.expect(found_lower == null);

    // Exact match - should match
    const found_exact = doc.call_getElementById("MyID");
    try std.testing.expect(found_exact != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(div)), @as(*Node, @ptrCast(found_exact.?)));
}

test "Document.getElementById - ignores elements without id attribute" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create elements, only one with id
    const div1 = try doc.call_createElement("div");
    const div2 = try doc.call_createElement("div");
    const div3 = try doc.call_createElement("div");

    _ = try doc.call_appendChild(@ptrCast(div1));
    _ = try doc.call_appendChild(@ptrCast(div2));
    _ = try doc.call_appendChild(@ptrCast(div3));

    // Only middle element has id
    try div2.call_setAttribute("id", "middle");

    const found = doc.call_getElementById("middle");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(div2)), @as(*Node, @ptrCast(found.?)));
}

test "Document.getElementById - empty id never matches" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));

    // Set empty id attribute
    try div.call_setAttribute("id", "");

    // Search for empty id - should not match
    const found = doc.call_getElementById("");
    try std.testing.expect(found == null);
}

test "Document.getElementById - finds element after id attribute added" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));

    // Initially no id
    const found_before = doc.call_getElementById("added-later");
    try std.testing.expect(found_before == null);

    // Add id attribute
    try div.call_setAttribute("id", "added-later");

    // Now should find it
    const found_after = doc.call_getElementById("added-later");
    try std.testing.expect(found_after != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(div)), @ptrCast(found_after?));
}

test "Document.getElementById - does not find element after id attribute removed" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));
    try div.call_setAttribute("id", "will-remove");

    // Initially should find it
    const found_before = doc.call_getElementById("will-remove");
    try std.testing.expect(found_before != null);

    // Remove id attribute
    try div.call_removeAttribute("id");

    // Now should not find it
    const found_after = doc.call_getElementById("will-remove");
    try std.testing.expect(found_after == null);
}

test "Document.getElementById - special characters in id" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));

    // Set id with special characters (valid per HTML spec)
    try div.call_setAttribute("id", "my:id-with.special_chars");

    const found = doc.call_getElementById("my:id-with.special_chars");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(div)), @as(*Node, @ptrCast(found.?)));
}

test "Document.getElementById - unicode in id" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));

    // Set id with unicode characters
    try div.call_setAttribute("id", "元素-🌍");

    const found = doc.call_getElementById("元素-🌍");
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(*Node, @ptrCast(div)), @as(*Node, @ptrCast(found.?)));
}
