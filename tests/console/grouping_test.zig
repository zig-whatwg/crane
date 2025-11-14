//! Grouping Function Tests
//!
//! Tests for Console grouping functions: group(), groupCollapsed(), groupEnd(), clear().
//! WHATWG Console Standard lines 75-79, 176-214.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");

const Group = console_mod.Group;

test "call_group - pushes group to stack" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Initially empty stack
    try std.testing.expect(console_obj.groupStack.isEmpty());

    // Create group
    console_obj.call_group(&.{});

    // Stack should have one group
    try std.testing.expect(!console_obj.groupStack.isEmpty());
    const group = console_obj.groupStack.peek().?;
    try std.testing.expect(!group.collapsed); // group() creates expanded groups
}

test "call_groupCollapsed - pushes collapsed group to stack" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Initially empty stack
    try std.testing.expect(console_obj.groupStack.isEmpty());

    // Create collapsed group
    console_obj.call_groupCollapsed(&.{});

    // Stack should have one collapsed group
    try std.testing.expect(!console_obj.groupStack.isEmpty());
    const group = console_obj.groupStack.peek().?;
    try std.testing.expect(group.collapsed); // groupCollapsed() creates collapsed groups
}

test "call_groupEnd - pops group from stack" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create a group
    console_obj.call_group(&.{});
    try std.testing.expect(!console_obj.groupStack.isEmpty());

    // End the group
    console_obj.call_groupEnd();

    // Stack should be empty now
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "call_groupEnd - on empty stack does nothing" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Stack is empty
    try std.testing.expect(console_obj.groupStack.isEmpty());

    // End group on empty stack (should not error)
    console_obj.call_groupEnd();

    // Stack should still be empty
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "grouping - nested groups work (LIFO)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create nested groups
    console_obj.call_group(&.{}); // Level 1
    console_obj.call_group(&.{}); // Level 2
    console_obj.call_group(&.{}); // Level 3

    // Stack should have 3 groups
    var depth: usize = 0;
    var temp_stack = console_obj.groupStack;
    while (temp_stack.pop()) |_| {
        depth += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), depth);

    // End groups in LIFO order
    console_obj.call_groupEnd(); // Removes level 3
    console_obj.call_groupEnd(); // Removes level 2
    console_obj.call_groupEnd(); // Removes level 1

    // Stack should be empty
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "grouping - mixed group and groupCollapsed" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create mixed groups
    console_obj.call_group(&.{}); // Expanded
    console_obj.call_groupCollapsed(&.{}); // Collapsed
    console_obj.call_group(&.{}); // Expanded

    // Pop and verify types
    const group3 = console_obj.groupStack.pop().?;
    try std.testing.expect(!group3.collapsed); // Expanded

    const group2 = console_obj.groupStack.pop().?;
    try std.testing.expect(group2.collapsed); // Collapsed

    const group1 = console_obj.groupStack.pop().?;
    try std.testing.expect(!group1.collapsed); // Expanded
}

test "call_clear - empties group stack" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create several groups
    console_obj.call_group(&.{});
    console_obj.call_group(&.{});
    console_obj.call_groupCollapsed(&.{});
    console_obj.call_group(&.{});

    // Stack should have 4 groups
    try std.testing.expect(!console_obj.groupStack.isEmpty());

    // Clear the console
    console_obj.call_clear();

    // Stack should be empty
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "call_clear - on empty stack does nothing" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Stack is empty
    try std.testing.expect(console_obj.groupStack.isEmpty());

    // Clear (should not error)
    console_obj.call_clear();

    // Stack should still be empty
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "grouping - deep nesting" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create deeply nested groups (10 levels)
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        console_obj.call_group(&.{});
    }

    // Verify depth
    var depth: usize = 0;
    while (console_obj.groupStack.pop()) |_| {
        depth += 1;
    }
    try std.testing.expectEqual(@as(usize, 10), depth);
}

test "grouping - partial unwinding" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create 5 groups
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        console_obj.call_group(&.{});
    }

    // End 3 groups
    i = 0;
    while (i < 3) : (i += 1) {
        console_obj.call_groupEnd();
    }

    // Should have 2 groups remaining
    var depth: usize = 0;
    while (console_obj.groupStack.pop()) |_| {
        depth += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), depth);
}

test "grouping - group with data (label)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Mock JSValue (opaque type, can't create real instances in tests)
    // For now, test with empty data array
    console_obj.call_group(&.{});

    // Verify group exists
    try std.testing.expect(!console_obj.groupStack.isEmpty());
    const group = console_obj.groupStack.peek().?;
    try std.testing.expect(!group.collapsed);
}

test "grouping - groupEnd more times than group" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create 2 groups
    console_obj.call_group(&.{});
    console_obj.call_group(&.{});

    // End 5 times (more than we created)
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        console_obj.call_groupEnd(); // Should not error
    }

    // Stack should be empty (excess ends are no-ops)
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "grouping - memory safety with many groups" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create and end many groups
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        console_obj.call_group(&.{});
        console_obj.call_groupCollapsed(&.{});
    }

    // Stack should have 200 groups
    var depth: usize = 0;
    while (console_obj.groupStack.pop()) |_| {
        depth += 1;
    }
    try std.testing.expectEqual(@as(usize, 200), depth);

    // Test passes if no memory leaks
}

test "grouping - interleaved group operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Interleave group, groupCollapsed, groupEnd
    console_obj.call_group(&.{}); // 1
    console_obj.call_groupCollapsed(&.{}); // 2
    console_obj.call_groupEnd(); // Remove 2
    console_obj.call_group(&.{}); // 2
    console_obj.call_group(&.{}); // 3
    console_obj.call_groupEnd(); // Remove 3
    console_obj.call_groupEnd(); // Remove 2
    console_obj.call_groupCollapsed(&.{}); // 2

    // Should have 2 groups: original level 1 and new level 2
    var depth: usize = 0;
    while (console_obj.groupStack.pop()) |_| {
        depth += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), depth);
}

test "grouping - clear after partial groups" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create groups, end some, then clear
    console_obj.call_group(&.{});
    console_obj.call_group(&.{});
    console_obj.call_group(&.{});
    console_obj.call_groupEnd();
    console_obj.call_groupCollapsed(&.{});

    // Should have 3 groups now (2 original + 1 collapsed)
    console_obj.call_clear();

    // Should be empty
    try std.testing.expect(console_obj.groupStack.isEmpty());
}
