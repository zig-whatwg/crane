//! Tests for DOMTokenList
//! Spec: https://dom.spec.whatwg.org/#interface-domtokenlist (§6.1)

const std = @import("std");
const ElementWithBase = @import("dom").ElementWithBase;
const DOMTokenList = @import("dom").DOMTokenListImpl;

test "DOMTokenList - initialization with empty attribute" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Should start with empty token set
    try std.testing.expectEqual(@as(usize, 0), token_list.length());
}

test "DOMTokenList - initialization with existing attribute" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    // Set class attribute before creating token list
    try element.setAttribute("class", "foo bar baz");

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Should parse existing value
    try std.testing.expectEqual(@as(usize, 3), token_list.length());
    try std.testing.expect(token_list.contains("foo"));
    try std.testing.expect(token_list.contains("bar"));
    try std.testing.expect(token_list.contains("baz"));
}

test "DOMTokenList - add single token" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add a token
    const tokens = [_][]const u8{"test-class"};
    try token_list.add(&tokens);

    // Verify it was added
    try std.testing.expectEqual(@as(usize, 1), token_list.length());
    try std.testing.expect(token_list.contains("test-class"));

    // Verify attribute was updated
    const class_attr = element.getAttribute("class");
    try std.testing.expect(class_attr != null);
    try std.testing.expectEqualStrings("test-class", class_attr.?);
}

test "DOMTokenList - add multiple tokens" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add multiple tokens
    const tokens = [_][]const u8{ "foo", "bar", "baz" };
    try token_list.add(&tokens);

    // Verify all were added
    try std.testing.expectEqual(@as(usize, 3), token_list.length());
    try std.testing.expect(token_list.contains("foo"));
    try std.testing.expect(token_list.contains("bar"));
    try std.testing.expect(token_list.contains("baz"));
}

test "DOMTokenList - add duplicate token (should not duplicate)" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add same token twice
    const tokens1 = [_][]const u8{"test"};
    try token_list.add(&tokens1);
    const tokens2 = [_][]const u8{"test"};
    try token_list.add(&tokens2);

    // Should only have one instance
    try std.testing.expectEqual(@as(usize, 1), token_list.length());
}

test "DOMTokenList - add empty string throws SyntaxError" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Adding empty string should throw
    const tokens = [_][]const u8{""};
    try std.testing.expectError(error.SyntaxError, token_list.add(&tokens));
}

test "DOMTokenList - add token with whitespace throws InvalidCharacterError" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Adding token with space should throw
    const tokens = [_][]const u8{"has space"};
    try std.testing.expectError(error.InvalidCharacterError, token_list.add(&tokens));
}

test "DOMTokenList - remove token" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add then remove
    const add_tokens = [_][]const u8{ "foo", "bar", "baz" };
    try token_list.add(&add_tokens);

    const remove_tokens = [_][]const u8{"bar"};
    try token_list.remove(&remove_tokens);

    // Verify removal
    try std.testing.expectEqual(@as(usize, 2), token_list.length());
    try std.testing.expect(token_list.contains("foo"));
    try std.testing.expect(!token_list.contains("bar"));
    try std.testing.expect(token_list.contains("baz"));
}

test "DOMTokenList - toggle token (add when not present)" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Toggle (should add)
    const result = try token_list.toggle("active", null);

    // Should return true (now present) and contain the token
    try std.testing.expect(result);
    try std.testing.expect(token_list.contains("active"));
}

test "DOMTokenList - toggle token (remove when present)" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add first
    const tokens = [_][]const u8{"active"};
    try token_list.add(&tokens);

    // Toggle (should remove)
    const result = try token_list.toggle("active", null);

    // Should return false (no longer present)
    try std.testing.expect(!result);
    try std.testing.expect(!token_list.contains("active"));
}

test "DOMTokenList - toggle with force=true always adds" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Toggle with force=true (should add)
    const result1 = try token_list.toggle("active", true);
    try std.testing.expect(result1);

    // Toggle again with force=true (should keep)
    const result2 = try token_list.toggle("active", true);
    try std.testing.expect(result2);
    try std.testing.expect(token_list.contains("active"));
}

test "DOMTokenList - toggle with force=false always removes" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add first
    const tokens = [_][]const u8{"active"};
    try token_list.add(&tokens);

    // Toggle with force=false (should remove)
    const result = try token_list.toggle("active", false);
    try std.testing.expect(!result);
    try std.testing.expect(!token_list.contains("active"));
}

test "DOMTokenList - replace token" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add tokens
    const tokens = [_][]const u8{ "foo", "bar", "baz" };
    try token_list.add(&tokens);

    // Replace bar with qux
    const result = try token_list.replace("bar", "qux");

    // Should return true and have replacement
    try std.testing.expect(result);
    try std.testing.expectEqual(@as(usize, 3), token_list.length());
    try std.testing.expect(token_list.contains("foo"));
    try std.testing.expect(!token_list.contains("bar"));
    try std.testing.expect(token_list.contains("qux"));
    try std.testing.expect(token_list.contains("baz"));
}

test "DOMTokenList - replace non-existent token returns false" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Try to replace token that doesn't exist
    const result = try token_list.replace("missing", "new");

    // Should return false
    try std.testing.expect(!result);
}

test "DOMTokenList - item returns token at index" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    // Add tokens
    const tokens = [_][]const u8{ "first", "second", "third" };
    try token_list.add(&tokens);

    // Check items by index
    const item0 = token_list.item(0);
    try std.testing.expect(item0 != null);
    // Note: items are stored as u16 internally, so we can't directly compare
    // We'll just verify it's not null for now

    const item3 = token_list.item(3);
    try std.testing.expect(item3 == null);
}

test "DOMTokenList - contains returns correct boolean" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    const tokens = [_][]const u8{ "foo", "bar" };
    try token_list.add(&tokens);

    try std.testing.expect(token_list.contains("foo"));
    try std.testing.expect(token_list.contains("bar"));
    try std.testing.expect(!token_list.contains("baz"));
}

test "DOMTokenList - value getter returns serialized string" {
    const allocator = std.testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    var token_list = try DOMTokenList.init(allocator, &element, "class");
    defer token_list.deinit();

    const tokens = [_][]const u8{ "foo", "bar", "baz" };
    try token_list.add(&tokens);

    const val = token_list.getValue();
    try std.testing.expect(val.len > 0);
    // Tokens should be space-separated
    try std.testing.expect(std.mem.indexOf(u8, val, " ") != null);
}
