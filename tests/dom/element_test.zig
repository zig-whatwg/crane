const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");


// Type aliases
const Element = dom.Element;

test "Element - bloom filter class optimization" {
    const allocator = std.testing.allocator;
    const ElementWithBase = dom.ElementWithBase;

    var elem = ElementWithBase.init(allocator, "div");
    defer elem.deinit();

    // Set class attribute
    try elem.setAttribute("class", "container main active");

    // Bloom filter should be populated
    try std.testing.expect(elem.class_bloom_filter.contains("container"));
    try std.testing.expect(elem.class_bloom_filter.contains("main"));
    try std.testing.expect(elem.class_bloom_filter.contains("active"));

    // Non-existent classes should (mostly) not be found
    try std.testing.expect(!elem.class_bloom_filter.contains("nonexistent"));
    try std.testing.expect(!elem.class_bloom_filter.contains("randomclass"));

    // Update class attribute
    try elem.setAttribute("class", "new-class different");

    // Old classes should not be in bloom filter anymore
    try std.testing.expect(!elem.class_bloom_filter.contains("container"));
    try std.testing.expect(!elem.class_bloom_filter.contains("main"));

    // New classes should be found
    try std.testing.expect(elem.class_bloom_filter.contains("new-class"));
    try std.testing.expect(elem.class_bloom_filter.contains("different"));
}

test "Element - bloom filter updated on class change" {
    const allocator = std.testing.allocator;
    const ElementWithBase = dom.ElementWithBase;

    var elem = ElementWithBase.init(allocator, "div");
    defer elem.deinit();

    // Initially no classes
    try std.testing.expect(!elem.class_bloom_filter.contains("test"));

    // Add class
    try elem.setAttribute("class", "test");
    try std.testing.expect(elem.class_bloom_filter.contains("test"));

    // Modify class
    try elem.setAttribute("class", "modified");
    try std.testing.expect(!elem.class_bloom_filter.contains("test"));
    try std.testing.expect(elem.class_bloom_filter.contains("modified"));
}
