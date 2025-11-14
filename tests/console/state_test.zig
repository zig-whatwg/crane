//! State Management Tests
//!
//! Tests for Console state (count_map, timer_table, group_stack) initialization,
//! manipulation, and cleanup.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");

const Group = console_mod.Group;

test "Console - init creates empty state" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Verify all state is initialized empty
    try std.testing.expect(console_obj.count_map.isEmpty());
    try std.testing.expect(console_obj.timer_table.isEmpty());
    try std.testing.expect(console_obj.group_stack.isEmpty());
}

test "Console - deinit cleans up all resources" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);

    // Add some state
    const label = try infra.string.utf8ToUtf16(allocator, "test");
    defer allocator.free(label);

    try console_obj.count_map.set(label, 5);
    try console_obj.timer_table.set(label, infra.Moment.now());
    try console_obj.group_stack.push(Group.init(null));

    // Deinit should clean everything up
    console_obj.deinit();
    // Test passes if no leaks detected by testing allocator
}

test "Console - count_map operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = try infra.string.utf8ToUtf16(allocator, "counter1");
    defer allocator.free(label1);
    const label2 = try infra.string.utf8ToUtf16(allocator, "counter2");
    defer allocator.free(label2);

    // Initially empty
    try std.testing.expect(!console_obj.count_map.contains(label1));
    try std.testing.expectEqual(@as(?u32, null), console_obj.count_map.get(label1));

    // Set values
    try console_obj.count_map.set(label1, 1);
    try console_obj.count_map.set(label2, 5);

    // Verify values
    try std.testing.expect(console_obj.count_map.contains(label1));
    try std.testing.expectEqual(@as(?u32, 1), console_obj.count_map.get(label1));
    try std.testing.expectEqual(@as(?u32, 5), console_obj.count_map.get(label2));

    // Update value
    try console_obj.count_map.set(label1, 10);
    try std.testing.expectEqual(@as(?u32, 10), console_obj.count_map.get(label1));

    // Remove value
    _ = console_obj.count_map.remove(label1);
    try std.testing.expect(!console_obj.count_map.contains(label1));
}

test "Console - timer_table operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = try infra.string.utf8ToUtf16(allocator, "timer1");
    defer allocator.free(label1);
    const label2 = try infra.string.utf8ToUtf16(allocator, "timer2");
    defer allocator.free(label2);

    // Initially empty
    try std.testing.expect(!console_obj.timer_table.contains(label1));
    try std.testing.expectEqual(@as(?infra.Moment, null), console_obj.timer_table.get(label1));

    // Set timers
    const time1 = infra.Moment.now();
    const time2 = infra.Moment.fromMilliseconds(1000.0);
    try console_obj.timer_table.set(label1, time1);
    try console_obj.timer_table.set(label2, time2);

    // Verify timers exist
    try std.testing.expect(console_obj.timer_table.contains(label1));
    try std.testing.expect(console_obj.timer_table.contains(label2));

    const retrieved_time1 = console_obj.timer_table.get(label1).?;
    try std.testing.expectEqual(time1.toMilliseconds(), retrieved_time1.toMilliseconds());

    // Remove timer
    _ = console_obj.timer_table.remove(label1);
    try std.testing.expect(!console_obj.timer_table.contains(label1));
    try std.testing.expect(console_obj.timer_table.contains(label2)); // Other timer unaffected
}

test "Console - group_stack operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = try infra.string.utf8ToUtf16(allocator, "Group 1");
    defer allocator.free(label1);
    const label2 = try infra.string.utf8ToUtf16(allocator, "Group 2");
    defer allocator.free(label2);

    // Initially empty
    try std.testing.expect(console_obj.group_stack.isEmpty());
    try std.testing.expectEqual(@as(?Group, null), console_obj.group_stack.peek());

    // Push groups
    const group1 = Group.init(label1);
    const group2 = Group.initCollapsed(label2);
    try console_obj.group_stack.push(group1);
    try console_obj.group_stack.push(group2);

    // Verify stack
    try std.testing.expect(!console_obj.group_stack.isEmpty());
    const top = console_obj.group_stack.peek().?;
    try std.testing.expect(top.collapsed); // group2 is collapsed
    try std.testing.expect(top.label != null);

    // Pop groups (LIFO order)
    const popped2 = console_obj.group_stack.pop().?;
    try std.testing.expect(popped2.collapsed);

    const popped1 = console_obj.group_stack.pop().?;
    try std.testing.expect(!popped1.collapsed);

    // Stack now empty
    try std.testing.expect(console_obj.group_stack.isEmpty());
    try std.testing.expectEqual(@as(?Group, null), console_obj.group_stack.pop());
}

test "Console - multiple independent instances" {
    const allocator = std.testing.allocator;

    var console1 = try console_mod.console.console.init(allocator);
    defer console1.deinit();

    var console2 = try console_mod.console.console.init(allocator);
    defer console2.deinit();

    const label = try infra.string.utf8ToUtf16(allocator, "test");
    defer allocator.free(label);

    // Modify console1 state
    try console1.count_map.set(label, 10);
    try console1.timer_table.set(label, infra.Moment.now());
    try console1.group_stack.push(Group.init(null));

    // console2 state should be unaffected (separate instances)
    try std.testing.expect(console2.count_map.isEmpty());
    try std.testing.expect(console2.timer_table.isEmpty());
    try std.testing.expect(console2.group_stack.isEmpty());

    // Verify console1 state
    try std.testing.expect(console1.count_map.contains(label));
    try std.testing.expect(console1.timer_table.contains(label));
    try std.testing.expect(!console1.group_stack.isEmpty());
}

test "Console - concurrent timer operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label1 = try infra.string.utf8ToUtf16(allocator, "timer1");
    defer allocator.free(label1);
    const label2 = try infra.string.utf8ToUtf16(allocator, "timer2");
    defer allocator.free(label2);
    const label3 = try infra.string.utf8ToUtf16(allocator, "timer3");
    defer allocator.free(label3);

    // Start multiple timers
    const time1 = infra.Moment.now();
    const time2 = infra.Moment.fromMilliseconds(1000.0);
    const time3 = infra.Moment.fromMilliseconds(2000.0);

    try console_obj.timer_table.set(label1, time1);
    try console_obj.timer_table.set(label2, time2);
    try console_obj.timer_table.set(label3, time3);

    // All timers exist
    try std.testing.expectEqual(@as(usize, 3), console_obj.timer_table.size());

    // Remove one timer
    _ = console_obj.timer_table.remove(label2);

    // Other timers unaffected
    try std.testing.expect(console_obj.timer_table.contains(label1));
    try std.testing.expect(!console_obj.timer_table.contains(label2));
    try std.testing.expect(console_obj.timer_table.contains(label3));
    try std.testing.expectEqual(@as(usize, 2), console_obj.timer_table.size());
}

test "Console - nested group stack" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create nested groups
    const label1 = try infra.string.utf8ToUtf16(allocator, "Outer");
    defer allocator.free(label1);
    const label2 = try infra.string.utf8ToUtf16(allocator, "Middle");
    defer allocator.free(label2);
    const label3 = try infra.string.utf8ToUtf16(allocator, "Inner");
    defer allocator.free(label3);

    try console_obj.group_stack.push(Group.init(label1));
    try console_obj.group_stack.push(Group.init(label2));
    try console_obj.group_stack.push(Group.init(label3));

    // Verify nesting depth
    var depth: usize = 0;
    while (console_obj.group_stack.pop()) |_| {
        depth += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), depth);
    try std.testing.expect(console_obj.group_stack.isEmpty());
}

test "Console - memory safety with many operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Perform many state operations
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const label_buf = try std.fmt.allocPrint(allocator, "label{d}", .{i});
        defer allocator.free(label_buf);
        const label = try infra.string.utf8ToUtf16(allocator, label_buf);
        defer allocator.free(label);

        try console_obj.count_map.set(label, @intCast(i));
        try console_obj.timer_table.set(label, infra.Moment.fromMilliseconds(@floatFromInt(i)));
        try console_obj.group_stack.push(Group.init(null));
    }

    // Verify state
    try std.testing.expectEqual(@as(usize, 100), console_obj.count_map.size());
    try std.testing.expectEqual(@as(usize, 100), console_obj.timer_table.size());
    try std.testing.expect(!console_obj.group_stack.isEmpty());

    // deinit() should clean up all resources without leaks
}
