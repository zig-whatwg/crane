//! Integration Tests
//!
//! Tests for complete Console workflows combining multiple features.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");

const webidl = @import("webidl");
const JSValue = webidl.JSValue;

test "integration - complete console session" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Start with some logging
    console_obj.call_log(mock_args);
    console_obj.call_debug(mock_args);

    // Use timing
    const timer_label = "session";
    console_obj.call_time(timer_label);

    // Use counting
    const count_label = "operations";
    console_obj.call_count(count_label);
    console_obj.call_count(count_label);
    console_obj.call_count(count_label);

    // Use grouping
    console_obj.call_group(&.{});
    console_obj.call_info(mock_args);
    console_obj.call_warn(mock_args);
    console_obj.call_groupEnd();

    // End timing
    console_obj.call_timeEnd(timer_label);

    // Reset counter
    console_obj.call_countReset(count_label);

    // Test passes if no crashes or memory leaks
}

test "integration - nested groups with all operations" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Outer group
    console_obj.call_group(&.{});
    console_obj.call_log(mock_args); // Indent level 1

    // Start timer in group
    const timer1 = "timer1";
    console_obj.call_time(timer1);

    // Inner group
    console_obj.call_groupCollapsed(&.{});
    console_obj.call_debug(mock_args); // Indent level 2

    // Count in inner group
    const counter1 = "inner";
    console_obj.call_count(counter1);

    // Innermost group
    console_obj.call_group(&.{});
    console_obj.call_error(mock_args); // Indent level 3
    console_obj.call_groupEnd();

    // Back to level 2
    console_obj.call_timeLog(timer1, mock_args);
    console_obj.call_groupEnd();

    // Back to level 1
    console_obj.call_warn(mock_args);
    console_obj.call_timeEnd(timer1);
    console_obj.call_groupEnd();

    // Back to level 0
    console_obj.call_info(mock_args);
}

test "integration - concurrent timers and counters" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create multiple timers and counters
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const label = try std.fmt.allocPrint(allocator, "item{d}", .{i});
        defer allocator.free(label);

        console_obj.call_time(label);
        console_obj.call_count(label);
        console_obj.call_count(label);
        console_obj.call_timeEnd(label);
    }

    // Verify all timers ended (removed)
    try std.testing.expect(console_obj.timerTable.isEmpty());

    // Verify all counters exist
    try std.testing.expectEqual(@as(usize, 10), console_obj.countMap.size());
}

test "integration - disabled console performance" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.enabled = false;

    const mock_args: []const JSValue = &.{};
    const label = "test";

    // All operations should be near-instant when disabled
    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        console_obj.call_log(mock_args);
        console_obj.call_debug(mock_args);
        console_obj.call_time(label);
        console_obj.call_count(label);
        console_obj.call_group(&.{});
    }

    // Despite 10k operations, state should be unchanged (disabled)
    // Note: time/count will still modify state (spec compliant)
    // But logging should be skipped
}

test "integration - state isolation between instances" {
    const allocator = std.testing.allocator;

    var console1 = try console_mod.console.console.init(allocator);
    defer console1.deinit();

    var console2 = try console_mod.console.console.init(allocator);
    defer console2.deinit();

    const label = "test";

    // Modify console1
    try console1.call_time(label);
    try console1.call_count(label);
    try console1.call_group(&.{});

    // console2 should be unaffected
    try std.testing.expect(console2.timerTable.isEmpty());
    try std.testing.expect(console2.countMap.isEmpty());
    try std.testing.expect(console2.groupStack.isEmpty());

    // console1 should have state
    try std.testing.expect(!console1.timerTable.isEmpty());
    try std.testing.expect(!console1.countMap.isEmpty());
    try std.testing.expect(!console1.groupStack.isEmpty());
}

test "integration - clear resets groups but not timers/counts" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "test";

    // Create state
    console_obj.call_time(label);
    console_obj.call_count(label);
    console_obj.call_group(&.{});
    console_obj.call_group(&.{});

    // Verify all have state
    try std.testing.expect(!console_obj.timerTable.isEmpty());
    try std.testing.expect(!console_obj.countMap.isEmpty());
    try std.testing.expect(!console_obj.groupStack.isEmpty());

    // Clear only empties group stack
    console_obj.call_clear();

    // Groups cleared
    try std.testing.expect(console_obj.groupStack.isEmpty());

    // Timers and counters preserved
    try std.testing.expect(!console_obj.timerTable.isEmpty());
    try std.testing.expect(!console_obj.countMap.isEmpty());
}

test "integration - realistic debugging session" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Start debugging session
    const session_timer = "debug-session";
    console_obj.call_time(session_timer);

    console_obj.call_log(mock_args); // Starting debug

    // Debug function 1
    console_obj.call_group(&.{});
    const func1_timer = "function1";
    console_obj.call_time(func1_timer);

    console_obj.call_debug(mock_args);
    const counter1 = "iterations";
    console_obj.call_count(counter1);
    console_obj.call_count(counter1);

    console_obj.call_timeEnd(func1_timer);
    console_obj.call_groupEnd();

    // Debug function 2
    console_obj.call_group(&.{});
    const func2_timer = "function2";
    console_obj.call_time(func2_timer);

    console_obj.call_warn(mock_args); // Something suspicious
    console_obj.call_count(counter1);

    console_obj.call_timeEnd(func2_timer);
    console_obj.call_groupEnd();

    // End session
    console_obj.call_timeEnd(session_timer);
    console_obj.call_info(mock_args); // Session complete

    // Verify final state
    try std.testing.expect(console_obj.timerTable.isEmpty()); // All timers ended
    try std.testing.expectEqual(@as(usize, 1), console_obj.countMap.size()); // One counter
    try std.testing.expect(console_obj.groupStack.isEmpty()); // All groups closed
}

test "integration - error handling workflow" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Assert passes - no output
    console_obj.call_assert(true, mock_args);

    // Try-catch simulation
    console_obj.call_group(&.{});
    console_obj.call_debug(mock_args); // Attempting operation

    // Error occurs
    console_obj.call_error(mock_args);
    console_obj.call_trace(mock_args); // Get stack trace

    // Assert fails - logs error
    console_obj.call_assert(false, mock_args);

    console_obj.call_groupEnd();

    // Recovery
    console_obj.call_info(mock_args); // Error handled
}

test "integration - memory stress test" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Stress test with many operations
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        // Logging
        console_obj.call_log(mock_args);
        console_obj.call_debug(mock_args);
        console_obj.call_error(mock_args);

        // Timing
        const timer_buf = try std.fmt.allocPrint(allocator, "timer{d}", .{i});
        defer allocator.free(timer_buf);
        const timer = try infra.string.utf8ToUtf16(allocator, timer_buf);
        defer allocator.free(timer);
        console_obj.call_time(timer);
        console_obj.call_timeEnd(timer);

        // Counting
        const count_buf = try std.fmt.allocPrint(allocator, "count{d}", .{i});
        defer allocator.free(count_buf);
        const counter = try infra.string.utf8ToUtf16(allocator, count_buf);
        defer allocator.free(counter);
        console_obj.call_count(counter);

        // Grouping
        console_obj.call_group(&.{});
        console_obj.call_info(mock_args);
        console_obj.call_groupEnd();
    }

    // Verify state
    try std.testing.expect(console_obj.timerTable.isEmpty());
    try std.testing.expectEqual(@as(usize, 100), console_obj.countMap.size());
    try std.testing.expect(console_obj.groupStack.isEmpty());

    // Test passes if no memory leaks
}
