//! Element Selector Method Tests (DOM Standard §4.10.4)
//! Tests for Element.matches() and Element.closest()

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const testing = std.testing;
const Document = dom.Document;
const Node = dom.Node;
const Element = dom.Element;

test "Element.matches: basic type selector" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }

    // Should match "div"
    try testing.expect(try div.call_matches(allocator, "div"));

    // Should not match "span"
    try testing.expect(!try div.call_matches(allocator, "span"));
}

test "Element.matches: universal selector" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("anything");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Should match "*"
    try testing.expect(try elem.call_matches(allocator, "*"));
}

test "Element.matches: invalid selector throws SyntaxError" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Invalid selector should throw SyntaxError
    const result = elem.call_matches(allocator, ">>invalid");
    try testing.expectError(error.SyntaxError, result);
}

test "Element.closest: finds self when matching" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create tree: div > span
    const div = try doc.call_createElement("div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }

    const span = try doc.call_createElement("span");
    defer {
        span.deinit();
        allocator.destroy(span);
    }

    const div_node: *Node = @ptrCast(div);
    const span_node: *Node = @ptrCast(span);
    _ = try div_node.call_appendChild(span_node);

    // span.closest("span") should return span itself
    const result = try span.call_closest(allocator, "span");
    try testing.expectEqual(span, result.?);
}

test "Element.closest: finds ancestor" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create tree: div > span > p
    const div = try doc.call_createElement("div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }

    const span = try doc.call_createElement("span");
    defer {
        span.deinit();
        allocator.destroy(span);
    }

    const p = try doc.call_createElement("p");
    defer {
        p.deinit();
        allocator.destroy(p);
    }

    const div_node: *Node = @ptrCast(div);
    const span_node: *Node = @ptrCast(span);
    const p_node: *Node = @ptrCast(p);

    _ = try div_node.call_appendChild(span_node);
    _ = try span_node.call_appendChild(p_node);

    // p.closest("div") should return div
    const result = try p.call_closest(allocator, "div");
    try testing.expectEqual(div, result.?);

    // p.closest("span") should return span
    const result2 = try p.call_closest(allocator, "span");
    try testing.expectEqual(span, result2.?);
}

test "Element.closest: returns null when no match" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create tree: div > span
    const div = try doc.call_createElement("div");
    defer {
        div.deinit();
        allocator.destroy(div);
    }

    const span = try doc.call_createElement("span");
    defer {
        span.deinit();
        allocator.destroy(span);
    }

    const div_node: *Node = @ptrCast(div);
    const span_node: *Node = @ptrCast(span);
    _ = try div_node.call_appendChild(span_node);

    // span.closest("article") should return null (no article in tree)
    const result = try span.call_closest(allocator, "article");
    try testing.expectEqual(@as(?*Element, null), result);
}

test "Element.closest: invalid selector throws SyntaxError" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Invalid selector should throw SyntaxError
    const result = elem.call_closest(allocator, ">>invalid");
    try testing.expectError(error.SyntaxError, result);
}

test "Element.closest: finds closest match when multiple ancestors match" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create tree: div(outer) > div(inner) > span
    const outer_div = try doc.call_createElement("div");
    defer {
        outer_div.deinit();
        allocator.destroy(outer_div);
    }

    const inner_div = try doc.call_createElement("div");
    defer {
        inner_div.deinit();
        allocator.destroy(inner_div);
    }

    const span = try doc.call_createElement("span");
    defer {
        span.deinit();
        allocator.destroy(span);
    }

    const outer_node: *Node = @ptrCast(outer_div);
    const inner_node: *Node = @ptrCast(inner_div);
    const span_node: *Node = @ptrCast(span);

    _ = try outer_node.call_appendChild(inner_node);
    _ = try inner_node.call_appendChild(span_node);

    // span.closest("div") should return inner_div (closest)
    const result = try span.call_closest(allocator, "div");
    try testing.expectEqual(inner_div, result.?);
}

// ============================================================================
// Element.classList tests
// ============================================================================

test "Element.classList: returns DOMTokenList" {
    const allocator = testing.allocator;

    // Type aliases
    const DOMTokenList = dom.DOMTokenList;
    const Document = dom.Document;
    const Element = dom.Element;
    const Node = dom.Node;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Set class attribute
    try elem.call_setAttribute("class", "foo bar baz");

    // Get classList
    const classList = try elem.get_classList();
    defer {
        classList.deinit();
        allocator.destroy(classList);
    }

    // Verify it's a DOMTokenList with correct tokens
    try testing.expectEqual(@as(u32, 3), classList.get_length());
    try testing.expect(classList.call_contains("foo"));
    try testing.expect(classList.call_contains("bar"));
    try testing.expect(classList.call_contains("baz"));
}

test "Element.classList: empty when no class attribute" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Get classList without setting class attribute
    const classList = try elem.get_classList();
    defer {
        classList.deinit();
        allocator.destroy(classList);
    }

    // Should be empty
    try testing.expectEqual(@as(u32, 0), classList.get_length());
}

test "Element.classList: can add tokens" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Set initial class
    try elem.call_setAttribute("class", "foo");

    const classList = try elem.get_classList();
    defer {
        classList.deinit();
        allocator.destroy(classList);
    }

    // Add token
    try classList.call_add(&[_][]const u8{"bar"});

    // Verify token was added
    try testing.expectEqual(@as(u32, 2), classList.get_length());
    try testing.expect(classList.call_contains("foo"));
    try testing.expect(classList.call_contains("bar"));
}

test "Element.classList: updates element attribute on modification" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Set initial class
    try elem.call_setAttribute("class", "foo bar");

    const classList = try elem.get_classList();
    defer {
        classList.deinit();
        allocator.destroy(classList);
    }

    // Remove a token
    try classList.call_remove(&[_][]const u8{"foo"});

    // Element's class attribute should be updated
    const class_value = elem.call_getAttribute("class").?;
    try testing.expectEqualStrings("bar", class_value);
}
