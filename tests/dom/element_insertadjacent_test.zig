//! Tests for Element insertAdjacent methods
//! DOM §4.10.7

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Element = dom.Element;
const Node = dom.Node;
const Text = dom.Text;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;

/// Helper to create a simple tree for testing
fn createTestTree(allocator: std.mem.Allocator) !struct {
    parent: *Element,
    child1: *Element,
    child2: *Element,
} {
    const parent = try allocator.create(Element);
    parent.* = try Element.init(allocator, "div");

    const child1 = try allocator.create(Element);
    child1.* = try Element.init(allocator, "span");

    const child2 = try allocator.create(Element);
    child2.* = try Element.init(allocator, "span");

    // Build tree: parent -> [child1, child2]
    _ = try @as(*Node, @ptrCast(parent)).call_appendChild(@ptrCast(child1));
    _ = try @as(*Node, @ptrCast(parent)).call_appendChild(@ptrCast(child2));

    return .{
        .parent = parent,
        .child1 = child1,
        .child2 = child2,
    };
}

fn destroyTestTree(tree: anytype) void {
    tree.child2.deinit();
    tree.child2.allocator.destroy(tree.child2);
    tree.child1.deinit();
    tree.child1.allocator.destroy(tree.child1);
    tree.parent.deinit();
    tree.parent.allocator.destroy(tree.parent);
}

test "Element - insertAdjacentElement beforebegin" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Create new element to insert
    const new_elem = try allocator.create(Element);
    defer allocator.destroy(new_elem);
    new_elem.* = try Element.init(allocator, "p");
    defer new_elem.deinit();

    // Insert before child1
    const result = try tree.child1.call_insertAdjacentElement("beforebegin", new_elem);

    // Should return the inserted element
    try expect(result == new_elem);

    // Parent should now have 3 children: [new_elem, child1, child2]
    const parent_node = @as(*Node, @ptrCast(tree.parent));
    try expectEqual(@as(usize, 3), parent_node.child_nodes.toSlice().len);
    try expect(parent_node.child_nodes.toSlice()[0] == @as(*Node, @ptrCast(new_elem)));
    try expect(parent_node.child_nodes.toSlice()[1] == @as(*Node, @ptrCast(tree.child1)));
    try expect(parent_node.child_nodes.toSlice()[2] == @as(*Node, @ptrCast(tree.child2)));
}

test "Element - insertAdjacentElement afterbegin" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Create new element to insert
    const new_elem = try allocator.create(Element);
    defer allocator.destroy(new_elem);
    new_elem.* = try Element.init(allocator, "p");
    defer new_elem.deinit();

    // Insert at beginning of parent
    const result = try tree.parent.call_insertAdjacentElement("afterbegin", new_elem);

    // Should return the inserted element
    try expect(result == new_elem);

    // Parent should now have 3 children: [new_elem, child1, child2]
    const parent_node = @as(*Node, @ptrCast(tree.parent));
    try expectEqual(@as(usize, 3), parent_node.child_nodes.toSlice().len);
    try expect(parent_node.child_nodes.toSlice()[0] == @as(*Node, @ptrCast(new_elem)));
    try expect(parent_node.child_nodes.toSlice()[1] == @as(*Node, @ptrCast(tree.child1)));
    try expect(parent_node.child_nodes.toSlice()[2] == @as(*Node, @ptrCast(tree.child2)));
}

test "Element - insertAdjacentElement beforeend" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Create new element to insert
    const new_elem = try allocator.create(Element);
    defer allocator.destroy(new_elem);
    new_elem.* = try Element.init(allocator, "p");
    defer new_elem.deinit();

    // Insert at end of parent
    const result = try tree.parent.call_insertAdjacentElement("beforeend", new_elem);

    // Should return the inserted element
    try expect(result == new_elem);

    // Parent should now have 3 children: [child1, child2, new_elem]
    const parent_node = @as(*Node, @ptrCast(tree.parent));
    try expectEqual(@as(usize, 3), parent_node.child_nodes.toSlice().len);
    try expect(parent_node.child_nodes.toSlice()[0] == @as(*Node, @ptrCast(tree.child1)));
    try expect(parent_node.child_nodes.toSlice()[1] == @as(*Node, @ptrCast(tree.child2)));
    try expect(parent_node.child_nodes.toSlice()[2] == @as(*Node, @ptrCast(new_elem)));
}

test "Element - insertAdjacentElement afterend" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Create new element to insert
    const new_elem = try allocator.create(Element);
    defer allocator.destroy(new_elem);
    new_elem.* = try Element.init(allocator, "p");
    defer new_elem.deinit();

    // Insert after child1
    const result = try tree.child1.call_insertAdjacentElement("afterend", new_elem);

    // Should return the inserted element
    try expect(result == new_elem);

    // Parent should now have 3 children: [child1, new_elem, child2]
    const parent_node = @as(*Node, @ptrCast(tree.parent));
    try expectEqual(@as(usize, 3), parent_node.child_nodes.toSlice().len);
    try expect(parent_node.child_nodes.toSlice()[0] == @as(*Node, @ptrCast(tree.child1)));
    try expect(parent_node.child_nodes.toSlice()[1] == @as(*Node, @ptrCast(new_elem)));
    try expect(parent_node.child_nodes.toSlice()[2] == @as(*Node, @ptrCast(tree.child2)));
}

test "Element - insertAdjacentElement beforebegin on root returns null" {
    const allocator = std.testing.allocator;

    const root = try allocator.create(Element);
    defer allocator.destroy(root);
    root.* = try Element.init(allocator, "div");
    defer root.deinit();

    const new_elem = try allocator.create(Element);
    defer allocator.destroy(new_elem);
    new_elem.* = try Element.init(allocator, "p");
    defer new_elem.deinit();

    // beforebegin on element with no parent should return null
    const result = try root.call_insertAdjacentElement("beforebegin", new_elem);
    try expect(result == null);
}

test "Element - insertAdjacentElement afterend on root returns null" {
    const allocator = std.testing.allocator;

    const root = try allocator.create(Element);
    defer allocator.destroy(root);
    root.* = try Element.init(allocator, "div");
    defer root.deinit();

    const new_elem = try allocator.create(Element);
    defer allocator.destroy(new_elem);
    new_elem.* = try Element.init(allocator, "p");
    defer new_elem.deinit();

    // afterend on element with no parent should return null
    const result = try root.call_insertAdjacentElement("afterend", new_elem);
    try expect(result == null);
}

test "Element - insertAdjacentElement invalid position throws SyntaxError" {
    const allocator = std.testing.allocator;

    const elem = try allocator.create(Element);
    defer allocator.destroy(elem);
    elem.* = try Element.init(allocator, "div");
    defer elem.deinit();

    const new_elem = try allocator.create(Element);
    defer allocator.destroy(new_elem);
    new_elem.* = try Element.init(allocator, "p");
    defer new_elem.deinit();

    // Invalid position should throw SyntaxError
    try expectError(error.SyntaxError, elem.call_insertAdjacentElement("invalid", new_elem));
    try expectError(error.SyntaxError, elem.call_insertAdjacentElement("before", new_elem));
    try expectError(error.SyntaxError, elem.call_insertAdjacentElement("after", new_elem));
    try expectError(error.SyntaxError, elem.call_insertAdjacentElement("", new_elem));
}

test "Element - insertAdjacentElement case insensitive" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Create elements with different casings
    const new1 = try allocator.create(Element);
    defer allocator.destroy(new1);
    new1.* = try Element.init(allocator, "p");
    defer new1.deinit();

    const new2 = try allocator.create(Element);
    defer allocator.destroy(new2);
    new2.* = try Element.init(allocator, "p");
    defer new2.deinit();

    const new3 = try allocator.create(Element);
    defer allocator.destroy(new3);
    new3.* = try Element.init(allocator, "p");
    defer new3.deinit();

    const new4 = try allocator.create(Element);
    defer allocator.destroy(new4);
    new4.* = try Element.init(allocator, "p");
    defer new4.deinit();

    // Should accept case-insensitive positions
    _ = try tree.parent.call_insertAdjacentElement("BEFOREBEGIN", new1); // Won't insert (no parent)
    _ = try tree.parent.call_insertAdjacentElement("AfterBegin", new2);
    _ = try tree.parent.call_insertAdjacentElement("BeforeEnd", new3);
    _ = try tree.parent.call_insertAdjacentElement("AFTEREND", new4); // Won't insert (no parent)

    // Should have inserted 2 elements (afterbegin and beforeend)
    const parent_node = @as(*Node, @ptrCast(tree.parent));
    try expectEqual(@as(usize, 4), parent_node.child_nodes.toSlice().len);
}

test "Element - insertAdjacentText creates Text node" {
    const allocator = std.testing.allocator;
    const tree = try createTestTree(allocator);
    defer destroyTestTree(tree);

    // Insert text at various positions
    try tree.parent.call_insertAdjacentText("afterbegin", "Hello");
    try tree.parent.call_insertAdjacentText("beforeend", "World");

    // Parent should now have 4 children: [text, child1, child2, text]
    const parent_node = @as(*Node, @ptrCast(tree.parent));
    try expectEqual(@as(usize, 4), parent_node.child_nodes.toSlice().len);

    // First and last should be Text nodes
    try expectEqual(Node.TEXT_NODE, parent_node.child_nodes.toSlice()[0].node_type);
    try expectEqual(Node.TEXT_NODE, parent_node.child_nodes.toSlice()[3].node_type);

    // Middle should be the original children
    try expect(parent_node.child_nodes.toSlice()[1] == @as(*Node, @ptrCast(tree.child1)));
    try expect(parent_node.child_nodes.toSlice()[2] == @as(*Node, @ptrCast(tree.child2)));
}

test "Element - insertAdjacentText returns nothing" {
    const allocator = std.testing.allocator;

    const elem = try allocator.create(Element);
    defer allocator.destroy(elem);
    elem.* = try Element.init(allocator, "div");
    defer elem.deinit();

    // Method returns void (nothing), not an error
    try elem.call_insertAdjacentText("beforeend", "test");

    // Should have inserted one text node
    const node = @as(*Node, @ptrCast(elem));
    try expectEqual(@as(usize, 1), node.child_nodes.toSlice().len);
}
