//! Tests for DOMTokenList
//! Spec: https://dom.spec.whatwg.org/#interface-domtokenlist (§6.1)
//!
//! The list is the real one - `element.classList` of a real element, through
//! the generated DOMTokenList interface (lane wb1: the tests drove
//! src/dom/dom_token_list.zig before, an old DOMTokenList over
//! ElementWithBase that nothing in production used). Each test keeps its
//! assertions; three say more than they could: `item` compares the token,
//! `value` compares the whole serialization, and the tests that change the
//! list read the class attribute back from the element.
//!
//! Lane lk1 moved the file here from tests/dom: a classList object is its
//! wrapper's to end, and tests/dom's realm has no engine, so there nothing
//! ended it (17 leaks under std.testing.allocator; lane wb1 ran the tests
//! over an arena). Here each test has a page of a real Browser
//! (native_read_page.zig) on std.testing.allocator, and the list is ended as
//! production ends it: by its wrapper, at the latest when the page ends.

const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const native_read_page = @import("native_read_page.zig");

const str = native_read_page.str;
const Tokens = interfaces.DOMTokenList;

/// A div of a page and its classList.
const ClassList = struct {
    element: *runtime.Instance,
    list: *runtime.Instance,
    /// The allocator the interfaces' string results are the caller's to
    /// free with: the element's realm's.
    allocator: std.mem.Allocator,

    /// `class`: the class attribute set BEFORE the list is made.
    fn open(page: native_read_page.Page, class: ?[]const u8) !ClassList {
        const element = try page.element("div");
        if (class) |value| try interfaces.Element.call_setAttribute(element, str("class"), .{ .domstring = str(value) });
        return .{ .element = element, .list = try interfaces.Element.get_classList(element), .allocator = element.ctx.allocator };
    }

    fn strings(buffer: *[4]runtime.DOMString, tokens: []const []const u8) []const runtime.DOMString {
        for (tokens, 0..) |token, i| buffer[i] = str(token);
        return buffer[0..tokens.len];
    }

    fn add(self: *const ClassList, tokens: []const []const u8) !void {
        var buffer: [4]runtime.DOMString = undefined;
        try Tokens.call_add(self.list, strings(&buffer, tokens));
    }

    fn remove(self: *const ClassList, tokens: []const []const u8) !void {
        var buffer: [4]runtime.DOMString = undefined;
        try Tokens.call_remove(self.list, strings(&buffer, tokens));
    }

    fn toggle(self: *const ClassList, token: []const u8, force: ?bool) !bool {
        return Tokens.call_toggle(self.list, str(token), .{ .was_passed = force != null, .value = force orelse false });
    }

    fn replace(self: *const ClassList, token: []const u8, new_token: []const u8) !bool {
        return Tokens.call_replace(self.list, str(token), str(new_token));
    }

    fn contains(self: *const ClassList, token: []const u8) !bool {
        return Tokens.call_contains(self.list, str(token));
    }

    fn length(self: *const ClassList) !usize {
        return try Tokens.get_length(self.list);
    }

    fn expectItem(self: *const ClassList, index: u32, expected: ?[]const u8) !void {
        var item = try Tokens.call_item(self.list, index);
        defer if (item) |*token| token.deinit(self.allocator);
        if (expected) |token| {
            try std.testing.expect(item != null);
            try std.testing.expectEqualStrings(token, item.?.asSlice());
        } else try std.testing.expect(item == null);
    }

    fn expectValue(self: *const ClassList, expected: []const u8) !void {
        var value = try Tokens.get_value(self.list);
        defer value.deinit(self.allocator);
        try std.testing.expectEqualStrings(expected, value.asSlice());
    }

    /// The element's class attribute, as script reads it.
    fn expectAttribute(self: *const ClassList, expected: ?[]const u8) !void {
        var value = try interfaces.Element.call_getAttribute(self.element, str("class"));
        defer if (value) |*v| v.deinit(self.allocator);
        if (expected) |text| {
            try std.testing.expect(value != null);
            try std.testing.expectEqualStrings(text, value.?.asSlice());
        } else try std.testing.expect(value == null);
    }
};

/// Run `body` with a div's classList on a page of its own. `class`: the
/// class attribute set before the list is made.
fn withClassList(comptime class: ?[]const u8, comptime body: fn (*const ClassList) anyerror!void) !void {
    try native_read_page.onPage(struct {
        fn run(page: native_read_page.Page) !void {
            const list = try ClassList.open(page, class);
            try body(&list);
        }
    }.run);
}

test "DOMTokenList - initialization with empty attribute" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Should start with empty token set
            try std.testing.expectEqual(@as(usize, 0), try list.length());
        }
    }.body);
}

test "DOMTokenList - initialization with existing attribute" {
    try withClassList("foo bar baz", struct {
        fn body(list: *const ClassList) !void {
            // The class attribute was set before the token list was made:
            // the list parses the existing value.
            try std.testing.expectEqual(@as(usize, 3), try list.length());
            try std.testing.expect(try list.contains("foo"));
            try std.testing.expect(try list.contains("bar"));
            try std.testing.expect(try list.contains("baz"));
        }
    }.body);
}

test "DOMTokenList - add single token" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Add a token
            try list.add(&.{"test-class"});

            // Verify it was added
            try std.testing.expectEqual(@as(usize, 1), try list.length());
            try std.testing.expect(try list.contains("test-class"));

            // Verify attribute was updated
            try list.expectAttribute("test-class");
        }
    }.body);
}

test "DOMTokenList - add multiple tokens" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Add multiple tokens
            try list.add(&.{ "foo", "bar", "baz" });

            // Verify all were added
            try std.testing.expectEqual(@as(usize, 3), try list.length());
            try std.testing.expect(try list.contains("foo"));
            try std.testing.expect(try list.contains("bar"));
            try std.testing.expect(try list.contains("baz"));
            try list.expectAttribute("foo bar baz");
        }
    }.body);
}

test "DOMTokenList - add duplicate token (should not duplicate)" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Add same token twice
            try list.add(&.{"test"});
            try list.add(&.{"test"});

            // Should only have one instance
            try std.testing.expectEqual(@as(usize, 1), try list.length());
            try list.expectAttribute("test");
        }
    }.body);
}

test "DOMTokenList - add empty string throws SyntaxError" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Adding empty string should throw
            try std.testing.expectError(error.SyntaxError, list.add(&.{""}));
            try list.expectAttribute(null);
        }
    }.body);
}

test "DOMTokenList - add token with whitespace throws InvalidCharacterError" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Adding token with space should throw
            try std.testing.expectError(error.InvalidCharacterError, list.add(&.{"has space"}));
            try list.expectAttribute(null);
        }
    }.body);
}

test "DOMTokenList - remove token" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
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
    }.body);
}

test "DOMTokenList - toggle token (add when not present)" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Toggle (should add)
            const result = try list.toggle("active", null);

            // Should return true (now present) and contain the token
            try std.testing.expect(result);
            try std.testing.expect(try list.contains("active"));
        }
    }.body);
}

test "DOMTokenList - toggle token (remove when present)" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Add first
            try list.add(&.{"active"});

            // Toggle (should remove)
            const result = try list.toggle("active", null);

            // Should return false (no longer present)
            try std.testing.expect(!result);
            try std.testing.expect(!try list.contains("active"));
        }
    }.body);
}

test "DOMTokenList - toggle with force=true always adds" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Toggle with force=true (should add)
            const result1 = try list.toggle("active", true);
            try std.testing.expect(result1);

            // Toggle again with force=true (should keep)
            const result2 = try list.toggle("active", true);
            try std.testing.expect(result2);
            try std.testing.expect(try list.contains("active"));
        }
    }.body);
}

test "DOMTokenList - toggle with force=false always removes" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Add first
            try list.add(&.{"active"});

            // Toggle with force=false (should remove)
            const result = try list.toggle("active", false);
            try std.testing.expect(!result);
            try std.testing.expect(!try list.contains("active"));
        }
    }.body);
}

test "DOMTokenList - replace token" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
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
    }.body);
}

test "DOMTokenList - replace non-existent token returns false" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Try to replace token that doesn't exist
            const result = try list.replace("missing", "new");

            // Should return false
            try std.testing.expect(!result);
        }
    }.body);
}

test "DOMTokenList - item returns token at index" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            // Add tokens
            try list.add(&.{ "first", "second", "third" });

            // Check items by index
            try list.expectItem(0, "first");
            try list.expectItem(2, "third");
            try list.expectItem(3, null);
        }
    }.body);
}

test "DOMTokenList - contains returns correct boolean" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            try list.add(&.{ "foo", "bar" });

            try std.testing.expect(try list.contains("foo"));
            try std.testing.expect(try list.contains("bar"));
            try std.testing.expect(!try list.contains("baz"));
        }
    }.body);
}

test "DOMTokenList - value getter returns serialized string" {
    try withClassList(null, struct {
        fn body(list: *const ClassList) !void {
            try list.add(&.{ "foo", "bar", "baz" });

            // Tokens are space-separated
            try list.expectValue("foo bar baz");
        }
    }.body);
}
