//! State Management Tests
//!
//! Tests for Console state (count_map, timer_table, group_stack) initialization,
//! manipulation, and cleanup.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");

const Group = console_mod.Group;

/// Helper to convert UTF-8 string literals to UTF-16 DOMString for testing
fn utf8ToUtf16(allocator: std.mem.Allocator, utf8: []const u8) !infra.String {
    return try infra.string.utf8ToUtf16(allocator, utf8);
}

test "Console - init creates empty state" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Verify all state is initialized empty
    try std.testing.expect(console_obj.countMap.isEmpty());
    try std.testing.expect(console_obj.timerTable.isEmpty());
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "Console - deinit cleans up all resources" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);

    // Add some state
    const label = "test";

    try console_obj.countMap.set(label, 5);
    try console_obj.timerTable.set(label, infra.Moment.now());
    try console_obj.groupStack.push(Group.init(null));

    // Deinit should clean everything up
    console_obj.deinit();
    // Test passes if no leaks detected by testing allocator
}

test "Console - count_map operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = "counter1";
    const label2 = "counter2";

    // Initially empty
    try std.testing.expect(!console_obj.countMap.contains(label1));
    try std.testing.expectEqual(@as(?u32, null), console_obj.countMap.get(label1));

    // Set values
    try console_obj.countMap.set(label1, 1);
    try console_obj.countMap.set(label2, 5);

    // Verify values
    try std.testing.expect(console_obj.countMap.contains(label1));
    try std.testing.expectEqual(@as(?u32, 1), console_obj.countMap.get(label1));
    try std.testing.expectEqual(@as(?u32, 5), console_obj.countMap.get(label2));

    // Update value
    try console_obj.countMap.set(label1, 10);
    try std.testing.expectEqual(@as(?u32, 10), console_obj.countMap.get(label1));

    // Remove value
    _ = console_obj.countMap.remove(label1);
    try std.testing.expect(!console_obj.countMap.contains(label1));
}

test "Console - timer_table operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = "timer1";
    const label2 = "timer2";

    // Initially empty
    try std.testing.expect(!console_obj.timerTable.contains(label1));
    try std.testing.expectEqual(@as(?infra.Moment, null), console_obj.timerTable.get(label1));

    // Set timers
    const time1 = infra.Moment.now();
    const time2 = infra.Moment.fromMilliseconds(1000.0);
    try console_obj.timerTable.set(label1, time1);
    try console_obj.timerTable.set(label2, time2);

    // Verify timers exist
    try std.testing.expect(console_obj.timerTable.contains(label1));
    try std.testing.expect(console_obj.timerTable.contains(label2));

    const retrieved_time1 = console_obj.timerTable.get(label1).?;
    try std.testing.expectEqual(time1.toMilliseconds(), retrieved_time1.toMilliseconds());

    // Remove timer
    _ = console_obj.timerTable.remove(label1);
    try std.testing.expect(!console_obj.timerTable.contains(label1));
    try std.testing.expect(console_obj.timerTable.contains(label2)); // Other timer unaffected
}

test "Console - group_stack operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = "Group 1";
    const label2 = "Group 2";

    // Initially empty
    try std.testing.expect(console_obj.groupStack.isEmpty());
    try std.testing.expectEqual(@as(?Group, null), console_obj.groupStack.peek());

    // Push groups
    const group1 = Group.init(label1);
    const group2 = Group.initCollapsed(label2);
    try console_obj.groupStack.push(group1);
    try console_obj.groupStack.push(group2);

    // Verify stack
    try std.testing.expect(!console_obj.groupStack.isEmpty());
    const top = console_obj.groupStack.peek().?;
    try std.testing.expect(top.collapsed); // group2 is collapsed
    try std.testing.expect(top.label != null);

    // Pop groups (LIFO order)
    const popped2 = console_obj.groupStack.pop().?;
    try std.testing.expect(popped2.collapsed);

    const popped1 = console_obj.groupStack.pop().?;
    try std.testing.expect(!popped1.collapsed);

    // Stack now empty
    try std.testing.expect(console_obj.groupStack.isEmpty());
    try std.testing.expectEqual(@as(?Group, null), console_obj.groupStack.pop());
}

test "Console - multiple independent instances" {
    const allocator = std.testing.allocator;

    var console1 = try console_mod.console.console.init(allocator);
    defer console1.deinit();

    var console2 = try console_mod.console.console.init(allocator);
    defer console2.deinit();

    const label = "test";

    // Modify console1 state
    try console1.countMap.set(label, 10);
    try console1.timerTable.set(label, infra.Moment.now());
    try console1.groupStack.push(Group.init(null));

    // console2 state should be unaffected (separate instances)
    try std.testing.expect(console2.countMap.isEmpty());
    try std.testing.expect(console2.timerTable.isEmpty());
    try std.testing.expect(console2.groupStack.isEmpty());

    // Verify console1 state
    try std.testing.expect(console1.countMap.contains(label));
    try std.testing.expect(console1.timerTable.contains(label));
    try std.testing.expect(!console1.groupStack.isEmpty());
}

test "Console - concurrent timer operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = "timer1";
    const label2 = "timer2";
    const label3 = "timer3";

    // Start multiple timers
    const time1 = infra.Moment.now();
    const time2 = infra.Moment.fromMilliseconds(1000.0);
    const time3 = infra.Moment.fromMilliseconds(2000.0);

    try console_obj.timerTable.set(label1, time1);
    try console_obj.timerTable.set(label2, time2);
    try console_obj.timerTable.set(label3, time3);

    // All timers exist
    try std.testing.expectEqual(@as(usize, 3), console_obj.timerTable.size());

    // Remove one timer
    _ = console_obj.timerTable.remove(label2);

    // Other timers unaffected
    try std.testing.expect(console_obj.timerTable.contains(label1));
    try std.testing.expect(!console_obj.timerTable.contains(label2));
    try std.testing.expect(console_obj.timerTable.contains(label3));
    try std.testing.expectEqual(@as(usize, 2), console_obj.timerTable.size());
}

test "Console - nested group stack" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create nested groups
    const label1 = "Outer";
    const label2 = "Middle";
    const label3 = "Inner";

    try console_obj.groupStack.push(Group.init(label1));
    try console_obj.groupStack.push(Group.init(label2));
    try console_obj.groupStack.push(Group.init(label3));

    // Verify nesting depth
    var depth: usize = 0;
    while (console_obj.groupStack.pop()) |_| {
        depth += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), depth);
    try std.testing.expect(console_obj.groupStack.isEmpty());
}

test "Console - memory safety with many operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Perform many state operations
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const label = try std.fmt.allocPrint(allocator, "label{d}", .{i});
        defer allocator.free(label);

        try console_obj.countMap.set(label, @intCast(i));
        try console_obj.timerTable.set(label, infra.Moment.fromMilliseconds(@floatFromInt(i)));
        try console_obj.groupStack.push(Group.init(null));
    }

    // Verify state
    try std.testing.expectEqual(@as(usize, 100), console_obj.countMap.size());
    try std.testing.expectEqual(@as(usize, 100), console_obj.timerTable.size());
    try std.testing.expect(!console_obj.groupStack.isEmpty());

    // deinit() should clean up all resources without leaks
}
