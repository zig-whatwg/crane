//! Tests for DOM mutation callback systems
//! Spec: Extension points for specifications to hook into DOM mutations

const std = @import("std");
const mutation = @import("../../src/dom/mutation.zig");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Node = Node;
const Element = Element;
const Text = Text;
const Document = Document;

// Test state for insertion steps
var insertion_count: usize = 0;
var last_inserted: ?*Node = null;

fn testInsertionCallback(node: *Node) void {
    insertion_count += 1;
    last_inserted = node;
}

fn resetInsertionState() void {
    insertion_count = 0;
    last_inserted = null;
}

// Test state for removing steps
var removing_count: usize = 0;
var last_removed: ?*Node = null;
var last_old_parent: ?*Node = null;

fn testRemovingCallback(node: *Node, old_parent: ?*Node) void {
    removing_count += 1;
    last_removed = node;
    last_old_parent = old_parent;
}

fn resetRemovingState() void {
    removing_count = 0;
    last_removed = null;
    last_old_parent = null;
}

// Test state for post-connection steps
var post_connection_count: usize = 0;
var last_connected: ?*Node = null;

fn testPostConnectionCallback(node: *Node) void {
    post_connection_count += 1;
    last_connected = node;
}

fn resetPostConnectionState() void {
    post_connection_count = 0;
    last_connected = null;
}

test "insertion steps callback is called when node is inserted" {
    const allocator = std.testing.allocator;
    resetInsertionState();

    // Register callback
    try mutation.registerInsertionStepsCallback(testInsertionCallback);

    // Create parent and child
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Text.init(allocator);
    defer child.deinit();

    // Insert child into parent
    try mutation.append(&child.base, &parent.base);

    // Verify callback was called
    try std.testing.expect(insertion_count >= 1);
    try std.testing.expect(last_inserted == &child.base);
}

test "removing steps callback is called when node is removed" {
    const allocator = std.testing.allocator;
    resetRemovingState();

    // Register callback
    try mutation.registerRemovingStepsCallback(testRemovingCallback);

    // Create parent and child
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Text.init(allocator);
    defer child.deinit();

    // Insert then remove
    try mutation.append(&child.base, &parent.base);
    resetRemovingState(); // Reset after insertion

    try mutation.remove(&child.base, false);

    // Verify callback was called
    try std.testing.expect(removing_count >= 1);
    try std.testing.expect(last_removed == &child.base);
    try std.testing.expect(last_old_parent == &parent.base);
}

test "post-connection steps callback is called after insertion" {
    const allocator = std.testing.allocator;
    resetPostConnectionState();

    // Register callback
    try mutation.registerPostConnectionStepsCallback(testPostConnectionCallback);

    // Create parent and child
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Text.init(allocator);
    defer child.deinit();

    // Insert child
    try mutation.append(&child.base, &parent.base);

    // Verify callback was called
    try std.testing.expect(post_connection_count >= 1);
    try std.testing.expect(last_connected == &child.base);
}

test "insertion steps called for node with descendants" {
    const allocator = std.testing.allocator;
    resetInsertionState();

    var count_tracker: usize = 0;
    const CountCallback = struct {
        var counter: *usize = undefined;
        fn cb(node: *Node) void {
            _ = node;
            counter.* += 1;
        }
    };
    CountCallback.counter = &count_tracker;

    // Register callback
    try mutation.registerInsertionStepsCallback(CountCallback.cb);

    // Create parent and child with grandchild
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Element.init(allocator);
    defer child.deinit();

    var grandchild = try Text.init(allocator);
    defer grandchild.deinit();

    // Build tree: parent <- child <- grandchild
    try mutation.append(&grandchild.base, &child.base);
    const before_count = count_tracker;

    try mutation.append(&child.base, &parent.base);

    // Verify callback was called for both child and grandchild
    // Should be at least 2 (child + grandchild)
    try std.testing.expect(count_tracker > before_count);
}

test "removing steps called for node with descendants" {
    const allocator = std.testing.allocator;

    var count_tracker: usize = 0;
    const CountCallback = struct {
        var counter: *usize = undefined;
        fn cb(node: *Node, old_parent: ?*Node) void {
            _ = node;
            _ = old_parent;
            counter.* += 1;
        }
    };
    CountCallback.counter = &count_tracker;

    // Register callback
    try mutation.registerRemovingStepsCallback(CountCallback.cb);

    // Create parent and child with grandchild
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Element.init(allocator);
    defer child.deinit();

    var grandchild = try Text.init(allocator);
    defer grandchild.deinit();

    // Build tree
    try mutation.append(&grandchild.base, &child.base);
    try mutation.append(&child.base, &parent.base);

    count_tracker = 0; // Reset after insertions

    // Remove child (which has grandchild)
    try mutation.remove(&child.base, false);

    // Verify callback was called for both child and grandchild
    try std.testing.expect(count_tracker >= 2);
}

test "multiple callback types work independently" {
    const allocator = std.testing.allocator;

    resetInsertionState();
    resetRemovingState();
    resetPostConnectionState();

    // Register all callbacks
    try mutation.registerInsertionStepsCallback(testInsertionCallback);
    try mutation.registerRemovingStepsCallback(testRemovingCallback);
    try mutation.registerPostConnectionStepsCallback(testPostConnectionCallback);

    // Create nodes
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Text.init(allocator);
    defer child.deinit();

    // Insert - should trigger insertion and post-connection
    try mutation.append(&child.base, &parent.base);

    try std.testing.expect(insertion_count >= 1);
    try std.testing.expect(post_connection_count >= 1);
    try std.testing.expectEqual(@as(usize, 0), removing_count);

    resetInsertionState();
    resetPostConnectionState();

    // Remove - should trigger removing
    try mutation.remove(&child.base, false);

    try std.testing.expect(removing_count >= 1);
    try std.testing.expectEqual(@as(usize, 0), insertion_count);
    try std.testing.expectEqual(@as(usize, 0), post_connection_count);
}
