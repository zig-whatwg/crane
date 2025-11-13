//! Tests for Node.normalize() - DOM Standard
//! Spec: https://dom.spec.whatwg.org/#dom-node-normalize
//!
//! The normalize() method removes empty exclusive Text nodes and concatenates
//! the data of remaining contiguous exclusive Text nodes into the first of their nodes.

const std = @import("std");
const dom = @import("dom");
const Element = dom.Element;
const Text = dom.Text;
const Node = dom.Node;
const Document = dom.Document;
const CharacterData = dom.CharacterData;

test "Node.normalize - empty element does nothing" {
    const allocator = std.testing.allocator;

    // Create an empty element
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    const node: *Node = @ptrCast(&elem);

    // Normalize should do nothing (no text nodes)
    try node.call_normalize();

    // Verify no children
    try std.testing.expectEqual(@as(usize, 0), node.child_nodes.len);
}

test "Node.normalize - single text node unchanged" {
    const allocator = std.testing.allocator;

    // Create element with single text node
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    var text = try Text.init(allocator);
    const text_cd: *CharacterData = @ptrCast(&text);
    text_cd.data = try allocator.dupe(u8, "Hello");
    defer allocator.free(text_cd.data);

    const elem_node: *Node = @ptrCast(&elem);
    const text_node: *Node = @ptrCast(&text);

    try elem_node.child_nodes.append(text_node);
    text_node.parent_node = elem_node;

    // Normalize should not change anything
    try elem_node.call_normalize();

    // Verify still one child
    try std.testing.expectEqual(@as(usize, 1), elem_node.child_nodes.len);

    // Verify data unchanged
    const result_node = elem_node.child_nodes.get(0).?;
    const result_cd: *CharacterData = @ptrCast(result_node);
    try std.testing.expectEqualStrings("Hello", result_cd.data);
}

test "Node.normalize - removes empty text node" {
    const allocator = std.testing.allocator;

    // Create element with empty text node
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    var text = try Text.init(allocator);
    const text_cd: *CharacterData = @ptrCast(&text);
    text_cd.data = try allocator.dupe(u8, "");

    const elem_node: *Node = @ptrCast(&elem);
    const text_node: *Node = @ptrCast(&text);

    try elem_node.child_nodes.append(text_node);
    text_node.parent_node = elem_node;
    text_node.node_type = Node.TEXT_NODE;

    // Normalize should remove empty text node
    try elem_node.call_normalize();

    // Verify no children
    try std.testing.expectEqual(@as(usize, 0), elem_node.child_nodes.len);

    // Note: text_node memory is still valid (not freed), just removed from tree
    allocator.free(text_cd.data);
}

test "Node.normalize - merges two adjacent text nodes" {
    const allocator = std.testing.allocator;

    // Create element with two adjacent text nodes
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    var text1 = try Text.init(allocator);
    const text1_cd: *CharacterData = @ptrCast(&text1);
    text1_cd.data = try allocator.dupe(u8, "Hello");

    var text2 = try Text.init(allocator);
    const text2_cd: *CharacterData = @ptrCast(&text2);
    text2_cd.data = try allocator.dupe(u8, " World");

    const elem_node: *Node = @ptrCast(&elem);
    const text1_node: *Node = @ptrCast(&text1);
    const text2_node: *Node = @ptrCast(&text2);

    text1_node.node_type = Node.TEXT_NODE;
    text2_node.node_type = Node.TEXT_NODE;

    try elem_node.child_nodes.append(text1_node);
    text1_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text2_node);
    text2_node.parent_node = elem_node;

    // Normalize should merge into first node
    try elem_node.call_normalize();

    // Verify only one child remains
    try std.testing.expectEqual(@as(usize, 1), elem_node.child_nodes.len);

    // Verify merged data
    const result_node = elem_node.child_nodes.get(0).?;
    const result_cd: *CharacterData = @ptrCast(result_node);
    try std.testing.expectEqualStrings("Hello World", result_cd.data);

    // Clean up
    allocator.free(text1_cd.data);
    allocator.free(text2_cd.data);
}

test "Node.normalize - merges three adjacent text nodes" {
    const allocator = std.testing.allocator;

    // Create element with three adjacent text nodes
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    var text1 = try Text.init(allocator);
    const text1_cd: *CharacterData = @ptrCast(&text1);
    text1_cd.data = try allocator.dupe(u8, "One");

    var text2 = try Text.init(allocator);
    const text2_cd: *CharacterData = @ptrCast(&text2);
    text2_cd.data = try allocator.dupe(u8, "Two");

    var text3 = try Text.init(allocator);
    const text3_cd: *CharacterData = @ptrCast(&text3);
    text3_cd.data = try allocator.dupe(u8, "Three");

    const elem_node: *Node = @ptrCast(&elem);
    const text1_node: *Node = @ptrCast(&text1);
    const text2_node: *Node = @ptrCast(&text2);
    const text3_node: *Node = @ptrCast(&text3);

    text1_node.node_type = Node.TEXT_NODE;
    text2_node.node_type = Node.TEXT_NODE;
    text3_node.node_type = Node.TEXT_NODE;

    try elem_node.child_nodes.append(text1_node);
    text1_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text2_node);
    text2_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text3_node);
    text3_node.parent_node = elem_node;

    // Normalize should merge all three into first node
    try elem_node.call_normalize();

    // Verify only one child remains
    try std.testing.expectEqual(@as(usize, 1), elem_node.child_nodes.len);

    // Verify merged data
    const result_node = elem_node.child_nodes.get(0).?;
    const result_cd: *CharacterData = @ptrCast(result_node);
    try std.testing.expectEqualStrings("OneTwoThree", result_cd.data);

    // Clean up
    allocator.free(text1_cd.data);
    allocator.free(text2_cd.data);
    allocator.free(text3_cd.data);
}

test "Node.normalize - text nodes separated by element" {
    const allocator = std.testing.allocator;

    // Create: <div>Text1<span></span>Text2</div>
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    var text1 = try Text.init(allocator);
    const text1_cd: *CharacterData = @ptrCast(&text1);
    text1_cd.data = try allocator.dupe(u8, "Before");

    var span = try Element.init(allocator, "span");
    defer span.deinit();

    var text2 = try Text.init(allocator);
    const text2_cd: *CharacterData = @ptrCast(&text2);
    text2_cd.data = try allocator.dupe(u8, "After");

    const elem_node: *Node = @ptrCast(&elem);
    const text1_node: *Node = @ptrCast(&text1);
    const span_node: *Node = @ptrCast(&span);
    const text2_node: *Node = @ptrCast(&text2);

    text1_node.node_type = Node.TEXT_NODE;
    span_node.node_type = Node.ELEMENT_NODE;
    text2_node.node_type = Node.TEXT_NODE;

    try elem_node.child_nodes.append(text1_node);
    text1_node.parent_node = elem_node;

    try elem_node.child_nodes.append(span_node);
    span_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text2_node);
    text2_node.parent_node = elem_node;

    // Normalize should NOT merge (separated by element)
    try elem_node.call_normalize();

    // Verify three children remain
    try std.testing.expectEqual(@as(usize, 3), elem_node.child_nodes.len);

    // Verify each text node unchanged
    const result1_cd: *CharacterData = @ptrCast(elem_node.child_nodes.get(0).?);
    try std.testing.expectEqualStrings("Before", result1_cd.data);

    const result2_cd: *CharacterData = @ptrCast(elem_node.child_nodes.get(2).?);
    try std.testing.expectEqualStrings("After", result2_cd.data);

    // Clean up
    allocator.free(text1_cd.data);
    allocator.free(text2_cd.data);
}

test "Node.normalize - mixed empty and non-empty text nodes" {
    const allocator = std.testing.allocator;

    // Create element with: "Hello", "", "", "World"
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    var text1 = try Text.init(allocator);
    const text1_cd: *CharacterData = @ptrCast(&text1);
    text1_cd.data = try allocator.dupe(u8, "Hello");

    var text2 = try Text.init(allocator);
    const text2_cd: *CharacterData = @ptrCast(&text2);
    text2_cd.data = try allocator.dupe(u8, "");

    var text3 = try Text.init(allocator);
    const text3_cd: *CharacterData = @ptrCast(&text3);
    text3_cd.data = try allocator.dupe(u8, "");

    var text4 = try Text.init(allocator);
    const text4_cd: *CharacterData = @ptrCast(&text4);
    text4_cd.data = try allocator.dupe(u8, "World");

    const elem_node: *Node = @ptrCast(&elem);
    const text1_node: *Node = @ptrCast(&text1);
    const text2_node: *Node = @ptrCast(&text2);
    const text3_node: *Node = @ptrCast(&text3);
    const text4_node: *Node = @ptrCast(&text4);

    text1_node.node_type = Node.TEXT_NODE;
    text2_node.node_type = Node.TEXT_NODE;
    text3_node.node_type = Node.TEXT_NODE;
    text4_node.node_type = Node.TEXT_NODE;

    try elem_node.child_nodes.append(text1_node);
    text1_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text2_node);
    text2_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text3_node);
    text3_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text4_node);
    text4_node.parent_node = elem_node;

    // Normalize should merge and remove empties
    try elem_node.call_normalize();

    // Verify result: Should have merged into first non-empty
    // But wait - the algorithm processes each text node in order
    // So "Hello" gets processed, finds "", "", "World" as contiguous
    // Result: "HelloWorld" in one node
    try std.testing.expectEqual(@as(usize, 1), elem_node.child_nodes.len);

    const result_cd: *CharacterData = @ptrCast(elem_node.child_nodes.get(0).?);
    try std.testing.expectEqualStrings("HelloWorld", result_cd.data);

    // Clean up
    allocator.free(text1_cd.data);
    allocator.free(text2_cd.data);
    allocator.free(text3_cd.data);
    allocator.free(text4_cd.data);
}

test "Node.normalize - nested text nodes in descendants" {
    const allocator = std.testing.allocator;

    // Create: <div><p>Text1Text2</p></div>
    var div = try Element.init(allocator, "div");
    defer div.deinit();

    var p = try Element.init(allocator, "p");
    defer p.deinit();

    var text1 = try Text.init(allocator);
    const text1_cd: *CharacterData = @ptrCast(&text1);
    text1_cd.data = try allocator.dupe(u8, "First");

    var text2 = try Text.init(allocator);
    const text2_cd: *CharacterData = @ptrCast(&text2);
    text2_cd.data = try allocator.dupe(u8, "Second");

    const div_node: *Node = @ptrCast(&div);
    const p_node: *Node = @ptrCast(&p);
    const text1_node: *Node = @ptrCast(&text1);
    const text2_node: *Node = @ptrCast(&text2);

    text1_node.node_type = Node.TEXT_NODE;
    text2_node.node_type = Node.TEXT_NODE;
    p_node.node_type = Node.ELEMENT_NODE;

    // Build tree: div > p > (text1, text2)
    try p_node.child_nodes.append(text1_node);
    text1_node.parent_node = p_node;

    try p_node.child_nodes.append(text2_node);
    text2_node.parent_node = p_node;

    try div_node.child_nodes.append(p_node);
    p_node.parent_node = div_node;

    // Normalize on div should normalize descendants
    try div_node.call_normalize();

    // Verify: p should have one text node child
    try std.testing.expectEqual(@as(usize, 1), p_node.child_nodes.len);

    const result_cd: *CharacterData = @ptrCast(p_node.child_nodes.get(0).?);
    try std.testing.expectEqualStrings("FirstSecond", result_cd.data);

    // Clean up
    allocator.free(text1_cd.data);
    allocator.free(text2_cd.data);
}

test "Node.normalize - no memory leaks with allocator" {
    // This test uses std.testing.allocator which will fail if there are leaks
    const allocator = std.testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    var text1 = try Text.init(allocator);
    const text1_cd: *CharacterData = @ptrCast(&text1);
    text1_cd.data = try allocator.dupe(u8, "Leak");
    defer allocator.free(text1_cd.data);

    var text2 = try Text.init(allocator);
    const text2_cd: *CharacterData = @ptrCast(&text2);
    text2_cd.data = try allocator.dupe(u8, "Test");
    defer allocator.free(text2_cd.data);

    const elem_node: *Node = @ptrCast(&elem);
    const text1_node: *Node = @ptrCast(&text1);
    const text2_node: *Node = @ptrCast(&text2);

    text1_node.node_type = Node.TEXT_NODE;
    text2_node.node_type = Node.TEXT_NODE;

    try elem_node.child_nodes.append(text1_node);
    text1_node.parent_node = elem_node;

    try elem_node.child_nodes.append(text2_node);
    text2_node.parent_node = elem_node;

    try elem_node.call_normalize();

    // If we reach here without leak detection errors, test passes
    try std.testing.expect(true);
}
