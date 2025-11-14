//! Tests for NodeBase polymorphism pattern
//!
//! This validates the flat memory layout approach where:
//! - All node types have NodeBase as first field
//! - Safe downcasting via @ptrCast with runtime type checks
//! - Zero runtime overhead

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Element = dom.Element;
const Node = dom.Node;
const Text = dom.Text;
const CharacterData = dom.CharacterData;

const testing = std.testing;
const NodeBase = dom.NodeBase;
const Allocator = std.mem.Allocator;

// Mock Element with NodeBase as first field
const MockElement = struct {
    base: NodeBase, // CRITICAL: Must be first field for safe @ptrCast

    // Element-specific fields
    tag_name: []const u8,
    namespace_uri: ?[]const u8,

    pub fn init(allocator: Allocator, tag_name: []const u8) MockElement {
        return .{
            .base = NodeBase{
                .allocator = allocator,
                .node_type = NodeBase.ELEMENT_NODE,
                .node_name = tag_name,
                .parent_node = null,
                .child_nodes = infra.List(*NodeBase).init(allocator),
                .owner_document = null,
                .registered_observers = infra.List(dom.RegisteredObserver).init(allocator),
            },
            .tag_name = tag_name,
            .namespace_uri = null,
        };
    }

    pub fn deinit(self: *MockElement) void {
        self.child_nodes.deinit();
        self.registered_observers.deinit();
    }

    pub fn asNode(self: *MockElement) *NodeBase {
        return &self.base;
    }
};

// Mock CharacterData with NodeBase as first field
const MockCharacterData = struct {
    base: NodeBase, // CRITICAL: Must be first field

    // CharacterData-specific fields
    data: []u8,

    pub fn init(allocator: Allocator, data: []const u8) !MockCharacterData {
        return .{
            .base = NodeBase{
                .allocator = allocator,
                .node_type = NodeBase.TEXT_NODE,
                .node_name = "#text",
                .parent_node = null,
                .child_nodes = infra.List(*NodeBase).init(allocator),
                .owner_document = null,
                .registered_observers = infra.List(dom.RegisteredObserver).init(allocator),
            },
            .data = try allocator.dupe(u8, data),
        };
    }

    pub fn deinit(self: *MockCharacterData) void {
        self.allocator.free(self.data);
        self.child_nodes.deinit();
        self.registered_observers.deinit();
    }

    pub fn asNode(self: *MockCharacterData) *NodeBase {
        return &self.base;
    }
};

test "NodeBase - upcast from Element to NodeBase" {
    const allocator = testing.allocator;

    var element = MockElement.init(allocator, "div");
    defer element.deinit();

    // Upcast to NodeBase
    const node: *NodeBase = element.asNode();

    // Verify fields are accessible through NodeBase
    try testing.expectEqual(NodeBase.ELEMENT_NODE, node.node_type);
    try testing.expectEqualStrings("div", node.node_name);
}

test "NodeBase - downcast from NodeBase to Element" {
    const allocator = testing.allocator;

    var element = MockElement.init(allocator, "div");
    defer element.deinit();

    // Upcast to NodeBase
    const node: *NodeBase = element.asNode();

    // Downcast back to Element using helper
    const downcasted = NodeBase.asElement(node);
    try testing.expect(downcasted != null);

    // Verify it's the same element
    const elem = downcasted.?;
    try testing.expectEqualStrings("div", elem.tag_name);
}

test "NodeBase - failed downcast to wrong type" {
    const allocator = testing.allocator;

    var element = MockElement.init(allocator, "div");
    defer element.deinit();

    // Upcast to NodeBase
    const node: *NodeBase = element.asNode();

    // Try to downcast to CharacterData (should fail - wrong type)
    const char_data = NodeBase.asCharacterData(node);
    try testing.expect(char_data == null);
}

test "NodeBase - downcast to CharacterData" {
    const allocator = testing.allocator;

    var char_data = try MockCharacterData.init(allocator, "Hello");
    defer char_data.deinit();

    // Upcast to NodeBase
    const node: *NodeBase = char_data.asNode();

    // Downcast back using helper
    const downcasted = NodeBase.asCharacterData(node);
    try testing.expect(downcasted != null);

    // Verify data is accessible
    const cd = downcasted.?;
    try testing.expectEqualStrings("Hello", cd.data);
}

test "NodeBase - tree navigation with mixed types" {
    const allocator = testing.allocator;

    var parent = MockElement.init(allocator, "div");
    defer parent.deinit();

    var child1 = MockElement.init(allocator, "span");
    defer child1.deinit();

    var child2 = try MockCharacterData.init(allocator, "Text content");
    defer child2.deinit();

    // Build tree using NodeBase pointers
    const parent_node = parent.asNode();
    const child1_node = child1.asNode();
    const child2_node = child2.asNode();

    try parent_node.child_nodes.append(child1_node);
    try parent_node.child_nodes.append(child2_node);

    child1_node.parent_node = parent_node;
    child2_node.parent_node = parent_node;

    // Verify tree structure
    try testing.expectEqual(@as(usize, 2), parent_node.child_nodes.size());

    // Access first child (Element)
    const first_child = parent_node.child_nodes.get(0).?;
    try testing.expectEqual(NodeBase.ELEMENT_NODE, first_child.node_type);

    if (NodeBase.asElement(first_child)) |elem| {
        try testing.expectEqualStrings("span", elem.tag_name);
    } else {
        try testing.expect(false); // Should not fail
    }

    // Access second child (CharacterData)
    const second_child = parent_node.child_nodes.get(1).?;
    try testing.expectEqual(NodeBase.TEXT_NODE, second_child.node_type);

    if (NodeBase.asCharacterData(second_child)) |cd| {
        try testing.expectEqualStrings("Text content", cd.data);
    } else {
        try testing.expect(false); // Should not fail
    }
}

test "NodeBase - contains check across type hierarchy" {
    const allocator = testing.allocator;

    var parent = MockElement.init(allocator, "div");
    defer parent.deinit();

    var child = try MockCharacterData.init(allocator, "Text");
    defer child.deinit();

    const parent_node = parent.asNode();
    const child_node = child.asNode();

    try parent_node.child_nodes.append(child_node);
    child_node.parent_node = parent_node;

    // Parent contains child (across type boundary)
    try testing.expect(parent_node.contains(child_node));

    // Child doesn't contain parent
    try testing.expect(!child_node.contains(parent_node));

    // Node contains itself
    try testing.expect(parent_node.contains(parent_node));
}

test "NodeBase - memory layout validation" {
    // This test validates that NodeBase is at offset 0 in derived types
    // which is critical for safe @ptrCast

    const allocator = testing.allocator;

    var element = MockElement.init(allocator, "div");
    defer element.deinit();

    // Get addresses
    const element_addr = @intFromPtr(&element);
    const base_addr = @intFromPtr(&element.base);

    // They must be identical for safe casting
    try testing.expectEqual(element_addr, base_addr);
}

test "NodeBase - real CharacterData integration" {
    // Validates that the real generated CharacterData works with NodeBase downcasting
    // This ensures removing the stub didn't break anything

    const allocator = testing.allocator;

    // Create a real CharacterData node
    var char_data = try CharacterData.init(allocator);
    defer char_data.deinit();

    // Set initial data
    char_data.data = try allocator.dupe(u8, "Hello, world!");

    // Update node_type to TEXT_NODE for this test
    char_data.node_type = NodeBase.TEXT_NODE;
    char_data.node_name = "#text";

    // Get NodeBase pointer (cast CharacterData to NodeBase)
    const node: *NodeBase = @ptrCast(&char_data);

    // Verify node type
    try testing.expectEqual(NodeBase.TEXT_NODE, node.node_type);

    // Downcast using asCharacterData (this is what we're testing!)
    const downcasted = NodeBase.asCharacterData(node);
    try testing.expect(downcasted != null);

    // Verify we can access CharacterData fields
    const cd = downcasted.?;
    try testing.expectEqualStrings("Hello, world!", cd.data);
    try testing.expectEqual(@as(u32, 13), cd.get_length());
}
