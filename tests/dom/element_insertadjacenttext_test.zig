const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Element = dom.Element;
const Node = dom.Node;
const Text = dom.Text;

test "Element.insertAdjacentText - beforebegin inserts before element" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create parent and child elements
    const parent = try doc.call_createElement("div");
    const child = try doc.call_createElement("span");
    _ = try parent.call_appendChild(@ptrCast(child));

    // Insert text before child
    try child.call_insertAdjacentText("beforebegin", "Hello ");

    // Parent should now have 2 children: text node and span
    try std.testing.expectEqual(@as(usize, 2), parent.child_nodes.size());

    // First child should be the text node
    const first = parent.child_nodes.get(0).?;
    try std.testing.expectEqual(dom.Node.TEXT_NODE, first.node_type);

    // Check text content
    const text = first.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("Hello ", text.get_data());

    // Second child should be the span
    const second = parent.child_nodes.get(1).?;
    try std.testing.expectEqual((&child), second);
}

test "Element.insertAdjacentText - afterbegin inserts as first child" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");
    const child = try doc.call_createElement("span");
    _ = try element.call_appendChild(@ptrCast(child));

    // Insert text at beginning
    try element.call_insertAdjacentText("afterbegin", "Start");

    // Element should have 2 children: text node and span
    try std.testing.expectEqual(@as(usize, 2), element.child_nodes.size());

    // First child should be the text node
    const first = element.child_nodes.get(0).?;
    try std.testing.expectEqual(dom.Node.TEXT_NODE, first.node_type);

    const text = first.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("Start", text.get_data());
}

test "Element.insertAdjacentText - beforeend inserts as last child" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");
    const child = try doc.call_createElement("span");
    _ = try element.call_appendChild(@ptrCast(child));

    // Insert text at end
    try element.call_insertAdjacentText("beforeend", "End");

    // Element should have 2 children: span and text node
    try std.testing.expectEqual(@as(usize, 2), element.child_nodes.size());

    // Last child should be the text node
    const last = element.child_nodes.get(1).?;
    try std.testing.expectEqual(dom.Node.TEXT_NODE, last.node_type);

    const text = last.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("End", text.get_data());
}

test "Element.insertAdjacentText - afterend inserts after element" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const parent = try doc.call_createElement("div");
    const child = try doc.call_createElement("span");
    _ = try parent.call_appendChild(@ptrCast(child));

    // Insert text after child
    try child.call_insertAdjacentText("afterend", " World");

    // Parent should now have 2 children: span and text node
    try std.testing.expectEqual(@as(usize, 2), parent.child_nodes.size());

    // Second child should be the text node
    const second = parent.child_nodes.get(1).?;
    try std.testing.expectEqual(dom.Node.TEXT_NODE, second.node_type);

    const text = second.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings(" World", text.get_data());
}

test "Element.insertAdjacentText - empty string creates empty text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Insert empty text
    try element.call_insertAdjacentText("afterbegin", "");

    // Element should have 1 child: empty text node
    try std.testing.expectEqual(@as(usize, 1), element.child_nodes.size());

    const first = element.child_nodes.get(0).?;
    try std.testing.expectEqual(dom.Node.TEXT_NODE, first.node_type);

    const text = first.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("", text.get_data());
}

test "Element.insertAdjacentText - multiple insertions accumulate" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Insert multiple text nodes
    try element.call_insertAdjacentText("afterbegin", "First");
    try element.call_insertAdjacentText("beforeend", "Last");
    try element.call_insertAdjacentText("afterbegin", "Before First");

    // Element should have 3 text nodes
    try std.testing.expectEqual(@as(usize, 3), element.child_nodes.size());

    // Check order: "Before First", "First", "Last"
    const first = element.child_nodes.get(0).?.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("Before First", first.get_data());

    const second = element.child_nodes.get(1).?.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("First", second.get_data());

    const third = element.child_nodes.get(2).?.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("Last", third.get_data());
}

test "Element.insertAdjacentText - special characters preserved" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Insert text with special characters
    try element.call_insertAdjacentText("afterbegin", "<>&\"'");

    const first = element.child_nodes.get(0).?;
    const text = first.as(dom.Text) orelse unreachable;

    // Special characters should be preserved as-is (not escaped)
    try std.testing.expectEqualStrings("<>&\"'", text.get_data());
}

test "Element.insertAdjacentText - unicode characters preserved" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const element = try doc.call_createElement("div");

    // Insert unicode text
    try element.call_insertAdjacentText("afterbegin", "Hello 世界 🌍");

    const first = element.child_nodes.get(0).?;
    const text = first.as(dom.Text) orelse unreachable;

    try std.testing.expectEqualStrings("Hello 世界 🌍", text.get_data());
}
