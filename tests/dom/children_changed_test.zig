//! Tests for DOM children changed steps callback system
//! Spec: https://dom.spec.whatwg.org/#concept-node-children-changed-ext

const std = @import("std");
const dom_types = @import("dom_types");
const mutation = @import("mutation");

const Node = dom_types.Node;
const Element = dom_types.Element;
const Text = dom_types.Text;
const CharacterData = dom_types.CharacterData;

// Test callback state
var test_callback_count: usize = 0;
var test_last_parent: ?*Node = null;

fn testCallback(parent: *Node) void {
    test_callback_count += 1;
    test_last_parent = parent;
}

fn resetTestState() void {
    test_callback_count = 0;
    test_last_parent = null;
}

test "children changed callback - append triggers callback" {
    const allocator = std.testing.allocator;

    // Register our test callback
    try mutation.registerChildrenChangedCallback(testCallback);
    resetTestState();

    // Create test nodes
    var elem = try Element.init(allocator);
    defer elem.deinit();

    var text = try Text.init(allocator);
    defer text.deinit();

    // Append text to element - should trigger callback
    try mutation.append(&text.base, &elem.base);

    try std.testing.expectEqual(@as(usize, 1), test_callback_count);
    try std.testing.expect(test_last_parent == &elem.base);
}

test "children changed callback - remove triggers callback" {
    const allocator = std.testing.allocator;

    // Register callback and reset state
    try mutation.registerChildrenChangedCallback(testCallback);
    resetTestState();

    // Create parent and child
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Text.init(allocator);
    defer child.deinit();

    // First append the child
    try mutation.append(&child.base, &parent.base);
    resetTestState(); // Reset after append

    // Now remove - should trigger callback
    try mutation.remove(&child.base, false);

    try std.testing.expectEqual(@as(usize, 1), test_callback_count);
    try std.testing.expect(test_last_parent == &parent.base);
}

test "children changed callback - CharacterData replaceData triggers callback" {
    const allocator = std.testing.allocator;

    // Register callback and reset state
    try mutation.registerChildrenChangedCallback(testCallback);
    resetTestState();

    // Create parent element and text child
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var text = try Text.init(allocator);
    defer text.deinit();

    // Set initial data
    try text.base_character_data.set_data("Hello World");

    // Append text to parent
    try mutation.append(&text.base, &parent.base);
    resetTestState(); // Reset after append

    // Replace data - should trigger children changed callback for parent
    try text.base_character_data.call_replaceData(0, 5, "Goodbye");

    try std.testing.expectEqual(@as(usize, 1), test_callback_count);
    try std.testing.expect(test_last_parent == &parent.base);
}

test "children changed callback - no parent means no callback" {
    const allocator = std.testing.allocator;

    // Register callback and reset state
    try mutation.registerChildrenChangedCallback(testCallback);
    resetTestState();

    // Create text node without parent
    var text = try Text.init(allocator);
    defer text.deinit();

    // Set data
    try text.base_character_data.set_data("Test");

    // Replace data - should NOT trigger callback (no parent)
    try text.base_character_data.call_replaceData(0, 4, "New");

    try std.testing.expectEqual(@as(usize, 0), test_callback_count);
    try std.testing.expect(test_last_parent == null);
}

test "children changed callback - multiple callbacks registered" {
    const allocator = std.testing.allocator;

    var callback1_count: usize = 0;
    var callback2_count: usize = 0;

    const callback1 = struct {
        var count: *usize = undefined;
        fn cb(parent: *Node) void {
            _ = parent;
            count.* += 1;
        }
    };
    callback1.count = &callback1_count;

    const callback2 = struct {
        var count: *usize = undefined;
        fn cb(parent: *Node) void {
            _ = parent;
            count.* += 1;
        }
    };
    callback2.count = &callback2_count;

    // Register both callbacks
    try mutation.registerChildrenChangedCallback(callback1.cb);
    try mutation.registerChildrenChangedCallback(callback2.cb);

    // Create and mutate nodes
    var parent = try Element.init(allocator);
    defer parent.deinit();

    var child = try Text.init(allocator);
    defer child.deinit();

    // Append - should trigger both callbacks
    try mutation.append(&child.base, &parent.base);

    try std.testing.expect(callback1_count >= 1);
    try std.testing.expect(callback2_count >= 1);
}
