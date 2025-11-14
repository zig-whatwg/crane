//! DOMTokenList Tests (DOM Standard §4.7)
//! Tests for DOMTokenList interface

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const testing = std.testing;
const DOMTokenList = @import("DOMTokenList").DOMTokenList;

test "DOMTokenList: init creates empty token list" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try testing.expectEqual(@as(u32, 0), list.get_length());
}

test "DOMTokenList: add single token" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{"button"});
    
    try testing.expectEqual(@as(u32, 1), list.get_length());
    try testing.expect(list.call_contains("button"));
}

test "DOMTokenList: add multiple tokens" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{ "button", "primary", "large" });
    
    try testing.expectEqual(@as(u32, 3), list.get_length());
    try testing.expect(list.call_contains("button"));
    try testing.expect(list.call_contains("primary"));
    try testing.expect(list.call_contains("large"));
}

test "DOMTokenList: add skips duplicates" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{"button"});
    try list.call_add(&[_][]const u8{"button"}); // Duplicate
    
    try testing.expectEqual(@as(u32, 1), list.get_length());
}

test "DOMTokenList: contains returns false for non-existent token" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{"button"});
    
    try testing.expect(!list.call_contains("link"));
}

test "DOMTokenList: item returns token at index" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{ "first", "second", "third" });
    
    const item0 = list.call_item(0);
    try testing.expect(item0 != null);
    try testing.expectEqualStrings("first", item0.?);
    
    const item1 = list.call_item(1);
    try testing.expectEqualStrings("second", item1.?);
    
    const item2 = list.call_item(2);
    try testing.expectEqualStrings("third", item2.?);
}

test "DOMTokenList: item returns null for out of bounds" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try testing.expect(list.call_item(0) == null);
    try testing.expect(list.call_item(999) == null);
}

test "DOMTokenList: remove single token" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{ "button", "primary" });
    try testing.expectEqual(@as(u32, 2), list.get_length());
    
    try list.call_remove(&[_][]const u8{"button"});
    
    try testing.expectEqual(@as(u32, 1), list.get_length());
    try testing.expect(!list.call_contains("button"));
    try testing.expect(list.call_contains("primary"));
}

test "DOMTokenList: remove multiple tokens" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{ "one", "two", "three", "four" });
    try list.call_remove(&[_][]const u8{ "one", "three" });
    
    try testing.expectEqual(@as(u32, 2), list.get_length());
    try testing.expect(!list.call_contains("one"));
    try testing.expect(list.call_contains("two"));
    try testing.expect(!list.call_contains("three"));
    try testing.expect(list.call_contains("four"));
}

test "DOMTokenList: toggle without force" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    // Toggle adds when not present
    const result1 = try list.call_toggle("active", null);
    try testing.expect(result1); // Now present
    try testing.expect(list.call_contains("active"));
    
    // Toggle removes when present
    const result2 = try list.call_toggle("active", null);
    try testing.expect(!result2); // Now absent
    try testing.expect(!list.call_contains("active"));
}

test "DOMTokenList: toggle with force true adds" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    const result = try list.call_toggle("active", true);
    try testing.expect(result);
    try testing.expect(list.call_contains("active"));
}

test "DOMTokenList: toggle with force false removes" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{"active"});
    
    const result = try list.call_toggle("active", false);
    try testing.expect(!result);
    try testing.expect(!list.call_contains("active"));
}

test "DOMTokenList: replace existing token" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{ "old", "keep" });
    
    const replaced = try list.call_replace("old", "new");
    
    try testing.expect(replaced);
    try testing.expect(!list.call_contains("old"));
    try testing.expect(list.call_contains("new"));
    try testing.expect(list.call_contains("keep"));
}

test "DOMTokenList: replace non-existent token returns false" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    const replaced = try list.call_replace("nonexistent", "new");
    try testing.expect(!replaced);
}

test "DOMTokenList: value getter returns space-separated string" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{ "button", "primary", "large" });
    
    const value = try list.get_value();
    defer allocator.free(value);
    
    try testing.expectEqualStrings("button primary large", value);
}

test "DOMTokenList: value getter returns empty string for empty list" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    const value = try list.get_value();
    try testing.expectEqualStrings("", value);
}

test "DOMTokenList: value setter parses space-separated tokens" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.set_value("one two three");
    
    try testing.expectEqual(@as(u32, 3), list.get_length());
    try testing.expect(list.call_contains("one"));
    try testing.expect(list.call_contains("two"));
    try testing.expect(list.call_contains("three"));
}

test "DOMTokenList: value setter replaces existing tokens" {
    const allocator = testing.allocator;
    
    var list = try DOMTokenList.init(allocator, null, "class");
    defer list.deinit();
    
    try list.call_add(&[_][]const u8{"old"});
    try list.set_value("new");
    
    try testing.expectEqual(@as(u32, 1), list.get_length());
    try testing.expect(!list.call_contains("old"));
    try testing.expect(list.call_contains("new"));
}
