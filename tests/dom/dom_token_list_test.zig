//! Tests for DOMTokenList
//! Spec: https://dom.spec.whatwg.org/#interface-domtokenlist (§6.1)
//!
//! Lane wb1: the list is the real one - `element.classList` of a real
//! element (real_nodes.zig), through the generated DOMTokenList interface.
//! The tests drove src/dom/dom_token_list.zig, an old DOMTokenList over
//! ElementWithBase that nothing in production used (deleted with those
//! types). Each test keeps its assertions; three say more than they could:
//! `item` compares the token (the old list kept UTF-16 units the test could
//! not compare), `value` compares the whole serialization, and the tests
//! that change the list read the class attribute back from the element.

const std = @import("std");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const real_nodes = @import("real_nodes.zig");

const str = real_nodes.str;
const Tokens = interfaces.DOMTokenList;

/// A div and its classList.
const ClassList = struct {
    /// Over an arena: the classList object is its wrapper's to end, and an
    /// engine-less realm has none (real_nodes.ArenaNodes).
    arena_nodes: real_nodes.ArenaNodes,
    nodes: *real_nodes.Nodes = undefined,
    element: *real_nodes.Instance = undefined,
    list: *real_nodes.Instance = undefined,

    /// In place. `class`: the class attribute set BEFORE the list is made.
    fn open(self: *ClassList, class: ?[]const u8) !void {
        self.* = .{ .arena_nodes = undefined };
        self.nodes = try self.arena_nodes.open();
        errdefer self.arena_nodes.close();
        const document = try self.nodes.document();
        self.element = try self.nodes.element(document, "div");
        try self.nodes.append(document, self.element);
        if (class) |value| try self.nodes.setAttribute(self.element, "class", value);
        self.list = try interfaces.Element.get_classList(self.element);
    }

    fn close(self: *ClassList) void {
        self.arena_nodes.close();
    }

    fn strings(buffer: *[4]runtime.DOMString, tokens: []const []const u8) []const runtime.DOMString {
        for (tokens, 0..) |token, i| buffer[i] = str(token);
        return buffer[0..tokens.len];
    }

    fn add(self: *ClassList, tokens: []const []const u8) !void {
        var buffer: [4]runtime.DOMString = undefined;
        try Tokens.call_add(self.list, strings(&buffer, tokens));
    }

    fn remove(self: *ClassList, tokens: []const []const u8) !void {
        var buffer: [4]runtime.DOMString = undefined;
        try Tokens.call_remove(self.list, strings(&buffer, tokens));
    }

    fn toggle(self: *ClassList, token: []const u8, force: ?bool) !bool {
        return Tokens.call_toggle(self.list, str(token), if (force) |f| webidl.Opt(bool).passed(f) else webidl.Opt(bool).notPassed());
    }

    fn replace(self: *ClassList, token: []const u8, new_token: []const u8) !bool {
        return Tokens.call_replace(self.list, str(token), str(new_token));
    }

    fn contains(self: *ClassList, token: []const u8) !bool {
        return Tokens.call_contains(self.list, str(token));
    }

    fn length(self: *ClassList) !usize {
        return try Tokens.get_length(self.list);
    }

    fn expectItem(self: *ClassList, index: u32, expected: ?[]const u8) !void {
        var item = try Tokens.call_item(self.list, index);
        defer if (item) |*token| token.deinit(self.nodes.allocator);
        if (expected) |token| {
            try std.testing.expect(item != null);
            try std.testing.expectEqualStrings(token, item.?.asSlice());
        } else try std.testing.expect(item == null);
    }

    fn expectValue(self: *ClassList, expected: []const u8) !void {
        var value = try Tokens.get_value(self.list);
        defer value.deinit(self.nodes.allocator);
        try std.testing.expectEqualStrings(expected, value.asSlice());
    }

    /// The element's class attribute, as script reads it.
    fn expectAttribute(self: *ClassList, expected: ?[]const u8) !void {
        var value = try interfaces.Element.call_getAttribute(self.element, str("class"));
        defer if (value) |*v| v.deinit(self.nodes.allocator);
        if (expected) |text| {
            try std.testing.expect(value != null);
            try std.testing.expectEqualStrings(text, value.?.asSlice());
        } else try std.testing.expect(value == null);
    }
};

test "DOMTokenList - initialization with empty attribute" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Should start with empty token set
    try std.testing.expectEqual(@as(usize, 0), try list.length());
}

test "DOMTokenList - initialization with existing attribute" {
    var list: ClassList = undefined;
    // Set class attribute before creating token list
    try list.open("foo bar baz");
    defer list.close();

    // Should parse existing value
    try std.testing.expectEqual(@as(usize, 3), try list.length());
    try std.testing.expect(try list.contains("foo"));
    try std.testing.expect(try list.contains("bar"));
    try std.testing.expect(try list.contains("baz"));
}

test "DOMTokenList - add single token" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add a token
    try list.add(&.{"test-class"});

    // Verify it was added
    try std.testing.expectEqual(@as(usize, 1), try list.length());
    try std.testing.expect(try list.contains("test-class"));

    // Verify attribute was updated
    try list.expectAttribute("test-class");
}

test "DOMTokenList - add multiple tokens" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add multiple tokens
    try list.add(&.{ "foo", "bar", "baz" });

    // Verify all were added
    try std.testing.expectEqual(@as(usize, 3), try list.length());
    try std.testing.expect(try list.contains("foo"));
    try std.testing.expect(try list.contains("bar"));
    try std.testing.expect(try list.contains("baz"));
    try list.expectAttribute("foo bar baz");
}

test "DOMTokenList - add duplicate token (should not duplicate)" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add same token twice
    try list.add(&.{"test"});
    try list.add(&.{"test"});

    // Should only have one instance
    try std.testing.expectEqual(@as(usize, 1), try list.length());
    try list.expectAttribute("test");
}

test "DOMTokenList - add empty string throws SyntaxError" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Adding empty string should throw
    try std.testing.expectError(error.SyntaxError, list.add(&.{""}));
    try list.expectAttribute(null);
}

test "DOMTokenList - add token with whitespace throws InvalidCharacterError" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Adding token with space should throw
    try std.testing.expectError(error.InvalidCharacterError, list.add(&.{"has space"}));
    try list.expectAttribute(null);
}

test "DOMTokenList - remove token" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add then remove
    try list.add(&.{ "foo", "bar", "baz" });
    try list.remove(&.{"bar"});

    // Verify removal
    try std.testing.expectEqual(@as(usize, 2), try list.length());
    try std.testing.expect(try list.contains("foo"));
    try std.testing.expect(!try list.contains("bar"));
    try std.testing.expect(try list.contains("baz"));
    try list.expectAttribute("foo baz");
}

test "DOMTokenList - toggle token (add when not present)" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Toggle (should add)
    const result = try list.toggle("active", null);

    // Should return true (now present) and contain the token
    try std.testing.expect(result);
    try std.testing.expect(try list.contains("active"));
}

test "DOMTokenList - toggle token (remove when present)" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add first
    try list.add(&.{"active"});

    // Toggle (should remove)
    const result = try list.toggle("active", null);

    // Should return false (no longer present)
    try std.testing.expect(!result);
    try std.testing.expect(!try list.contains("active"));
}

test "DOMTokenList - toggle with force=true always adds" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Toggle with force=true (should add)
    const result1 = try list.toggle("active", true);
    try std.testing.expect(result1);

    // Toggle again with force=true (should keep)
    const result2 = try list.toggle("active", true);
    try std.testing.expect(result2);
    try std.testing.expect(try list.contains("active"));
}

test "DOMTokenList - toggle with force=false always removes" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add first
    try list.add(&.{"active"});

    // Toggle with force=false (should remove)
    const result = try list.toggle("active", false);
    try std.testing.expect(!result);
    try std.testing.expect(!try list.contains("active"));
}

test "DOMTokenList - replace token" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add tokens
    try list.add(&.{ "foo", "bar", "baz" });

    // Replace bar with qux
    const result = try list.replace("bar", "qux");

    // Should return true and have replacement
    try std.testing.expect(result);
    try std.testing.expectEqual(@as(usize, 3), try list.length());
    try std.testing.expect(try list.contains("foo"));
    try std.testing.expect(!try list.contains("bar"));
    try std.testing.expect(try list.contains("qux"));
    try std.testing.expect(try list.contains("baz"));
    // In place (DOM 7.1 replace() step 5, "replace token with newToken").
    try list.expectAttribute("foo qux baz");
}

test "DOMTokenList - replace non-existent token returns false" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Try to replace token that doesn't exist
    const result = try list.replace("missing", "new");

    // Should return false
    try std.testing.expect(!result);
}

test "DOMTokenList - item returns token at index" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    // Add tokens
    try list.add(&.{ "first", "second", "third" });

    // Check items by index
    try list.expectItem(0, "first");
    try list.expectItem(2, "third");
    try list.expectItem(3, null);
}

test "DOMTokenList - contains returns correct boolean" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    try list.add(&.{ "foo", "bar" });

    try std.testing.expect(try list.contains("foo"));
    try std.testing.expect(try list.contains("bar"));
    try std.testing.expect(!try list.contains("baz"));
}

test "DOMTokenList - value getter returns serialized string" {
    var list: ClassList = undefined;
    try list.open(null);
    defer list.close();

    try list.add(&.{ "foo", "bar", "baz" });

    // Tokens are space-separated
    try list.expectValue("foo bar baz");
}
