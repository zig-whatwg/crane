const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");



// Type aliases
const Node = dom.Node;

// Test data structure to track if cloning steps were called
const CloningTestContext = struct {
    called: bool = false,
    node_ptr: ?*Node = null,
    copy_ptr: ?*Node = null,
    subtree_value: bool = false,
};

var test_context: CloningTestContext = .{};

fn testCloningSteps(node: *Node, copy: *Node, subtree: bool) !void {
    test_context.called = true;
    test_context.node_ptr = node;
    test_context.copy_ptr = copy;
    test_context.subtree_value = subtree;
}

test "Node.cloneNode - cloning steps hook is called" {
    const allocator = std.testing.allocator;

    // Reset test context
    test_context = .{};

    var node = try Node.init(allocator, Node.ELEMENT_NODE, "div");
    defer node.deinit();

    // Set cloning steps hook
    node.cloning_steps_hook = testCloningSteps;

    // Clone the node
    const cloned = try node.call_cloneNode(false);
    defer cloned.deinit();

    // Verify cloning steps were called
    try std.testing.expect(test_context.called);
    try std.testing.expect(test_context.node_ptr == &node);
    try std.testing.expect(test_context.copy_ptr == cloned);
    try std.testing.expect(test_context.subtree_value == false);
}

test "Node.cloneNode - cloning steps hook called with subtree=true" {
    const allocator = std.testing.allocator;

    // Reset test context
    test_context = .{};

    var node = try Node.init(allocator, Node.ELEMENT_NODE, "div");
    defer node.deinit();

    // Set cloning steps hook
    node.cloning_steps_hook = testCloningSteps;

    // Clone the node with subtree=true
    const cloned = try node.call_cloneNode(true);
    defer cloned.deinit();

    // Verify cloning steps were called with subtree=true
    try std.testing.expect(test_context.called);
    try std.testing.expect(test_context.subtree_value == true);
}

test "Node.cloneNode - no hook means no error" {
    const allocator = std.testing.allocator;

    var node = try Node.init(allocator, Node.ELEMENT_NODE, "div");
    defer node.deinit();

    // No cloning steps hook set (default null)
    try std.testing.expect(node.cloning_steps_hook == null);

    // Clone should still work
    const cloned = try node.call_cloneNode(false);
    defer cloned.deinit();

    try std.testing.expect(cloned.node_type == Node.ELEMENT_NODE);
}

fn errorCloningSteps(_: *Node, _: *Node, _: bool) !void {
    return error.CloningFailed;
}

test "Node.cloneNode - cloning steps errors propagate" {
    const allocator = std.testing.allocator;

    var node = try Node.init(allocator, Node.ELEMENT_NODE, "div");
    defer node.deinit();

    // Set cloning steps hook that returns an error
    node.cloning_steps_hook = errorCloningSteps;

    // Clone should propagate the error
    const result = node.call_cloneNode(false);
    try std.testing.expectError(error.CloningFailed, result);
}
