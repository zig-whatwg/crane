//! Element Selector Method Tests (DOM Standard §4.10.4)
//! Tests for Element.matches() and Element.closest()

const std = @import("std");
const testing = std.testing;
const Document = @import("document").Document;
const Element = @import("element").Element;
const Node = @import("node").Node;

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
