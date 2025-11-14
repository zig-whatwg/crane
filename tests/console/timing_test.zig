//! Timing Function Tests
//!
//! Tests for Console timing functions: time(), timeLog(), timeEnd().
//! WHATWG Console Standard lines 216-272.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");


test "call_time - starts new timer" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "test-timer";

    // Initially no timer exists
    try std.testing.expect(!console_obj.timerTable.contains(label));

    // Start timer
    try console_obj.call_time(label);

    // Timer now exists
    try std.testing.expect(console_obj.timerTable.contains(label));
    const start_time = console_obj.timerTable.get(label).?;
    try std.testing.expect(start_time.toMilliseconds() > 0);
}

test "call_time - duplicate timer returns without error" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "duplicate-timer";

    // Start timer first time
    try console_obj.call_time(label);
    const first_start = console_obj.timerTable.get(label).?;

    // Wait a tiny bit
    std.time.sleep(1_000_000); // 1ms

    // Start timer second time (should return without changing timer)
    try console_obj.call_time(label);
    const second_start = console_obj.timerTable.get(label).?;

    // Timer should be unchanged (same start time)
    try std.testing.expectEqual(
        first_start.toMilliseconds(),
        second_start.toMilliseconds(),
    );
}

test "call_timeEnd - stops timer and removes from table" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "end-timer";

    // Start timer
    try console_obj.call_time(label);
    try std.testing.expect(console_obj.timerTable.contains(label));

    // Wait a bit
    std.time.sleep(5_000_000); // 5ms

    // End timer
    try console_obj.call_timeEnd(label);

    // Timer should be removed from table
    try std.testing.expect(!console_obj.timerTable.contains(label));
}

test "call_timeEnd - missing timer returns without error" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "nonexistent-timer";

    // End timer that was never started (should not error)
    try console_obj.call_timeEnd(label);

    // Timer table should still be empty
    try std.testing.expect(console_obj.timerTable.isEmpty());
}

test "call_timeLog - logs elapsed time without removing timer" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "log-timer";

    // Start timer
    try console_obj.call_time(label);
    try std.testing.expect(console_obj.timerTable.contains(label));

    // Wait a bit
    std.time.sleep(3_000_000); // 3ms

    // Log timer (should not remove it)
    try console_obj.call_timeLog(label, &.{});

    // Timer should still exist
    try std.testing.expect(console_obj.timerTable.contains(label));
}

test "call_timeLog - missing timer returns without error" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "nonexistent-log-timer";

    // Log timer that was never started (should not error)
    try console_obj.call_timeLog(label, &.{});

    // Timer table should still be empty
    try std.testing.expect(console_obj.timerTable.isEmpty());
}

test "timing - complete lifecycle (time → timeLog → timeEnd)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "lifecycle-timer";

    // 1. Start timer
    try console_obj.call_time(label);
    try std.testing.expect(console_obj.timerTable.contains(label));

    // 2. Wait and log intermediate time
    std.time.sleep(2_000_000); // 2ms
    try console_obj.call_timeLog(label, &.{});
    try std.testing.expect(console_obj.timerTable.contains(label));

    // 3. Wait more and log again
    std.time.sleep(2_000_000); // 2ms
    try console_obj.call_timeLog(label, &.{});
    try std.testing.expect(console_obj.timerTable.contains(label));

    // 4. End timer
    std.time.sleep(2_000_000); // 2ms
    try console_obj.call_timeEnd(label);
    try std.testing.expect(!console_obj.timerTable.contains(label));
}

test "timing - multiple concurrent timers" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const timer1 = "timer1";
    const timer2 = "timer2";
    const timer3 = "timer3";

    // Start multiple timers
    try console_obj.call_time(timer1);
    std.time.sleep(1_000_000); // 1ms
    try console_obj.call_time(timer2);
    std.time.sleep(1_000_000); // 1ms
    try console_obj.call_time(timer3);

    // All timers should exist
    try std.testing.expectEqual(@as(usize, 3), console_obj.timerTable.size());

    // End timer2
    try console_obj.call_timeEnd(timer2);

    // timer1 and timer3 should still exist
    try std.testing.expect(console_obj.timerTable.contains(timer1));
    try std.testing.expect(!console_obj.timerTable.contains(timer2));
    try std.testing.expect(console_obj.timerTable.contains(timer3));
    try std.testing.expectEqual(@as(usize, 2), console_obj.timerTable.size());

    // Clean up remaining timers
    try console_obj.call_timeEnd(timer1);
    try console_obj.call_timeEnd(timer3);
    try std.testing.expect(console_obj.timerTable.isEmpty());
}

test "timing - elapsed time increases" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "elapsed-timer";

    // Start timer
    try console_obj.call_time(label);
    const start_time = console_obj.timerTable.get(label).?;

    // Wait
    std.time.sleep(10_000_000); // 10ms

    // Check elapsed time
    const now = infra.Moment.now();
    const elapsed = now.since(start_time);
    const elapsed_ms = elapsed.toMilliseconds();

    // Should be at least 10ms (might be more due to scheduling)
    try std.testing.expect(elapsed_ms >= 10.0);

    // Clean up
    try console_obj.call_timeEnd(label);
}

test "timing - timer labels are independent" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label_a = "timerA";
    const label_b = "timerB";

    // Start timerA
    try console_obj.call_time(label_a);
    const time_a = console_obj.timerTable.get(label_a).?;

    // Wait
    std.time.sleep(5_000_000); // 5ms

    // Start timerB
    try console_obj.call_time(label_b);
    const time_b = console_obj.timerTable.get(label_b).?;

    // timerA should have started earlier than timerB
    try std.testing.expect(time_a.isBefore(time_b));

    // Clean up
    try console_obj.call_timeEnd(label_a);
    try console_obj.call_timeEnd(label_b);
}

test "timing - default label can be used" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const default_label = "default";

    // Use "default" as label (WebIDL default parameter)
    try console_obj.call_time(default_label);
    try std.testing.expect(console_obj.timerTable.contains(default_label));

    try console_obj.call_timeLog(default_label, &.{});
    try std.testing.expect(console_obj.timerTable.contains(default_label));

    try console_obj.call_timeEnd(default_label);
    try std.testing.expect(!console_obj.timerTable.contains(default_label));
}

test "timing - memory safety with many timers" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Start many timers
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const label_buf = try std.fmt.allocPrint(allocator, "timer{d}", .{i});
        defer allocator.free(label_buf);
        const label = try infra.string.utf8ToUtf16(allocator, label_buf);
        defer allocator.free(label);

        try console_obj.call_time(label);
    }

    try std.testing.expectEqual(@as(usize, 50), console_obj.timerTable.size());

    // End all timers
    i = 0;
    while (i < 50) : (i += 1) {
        const label_buf = try std.fmt.allocPrint(allocator, "timer{d}", .{i});
        defer allocator.free(label_buf);
        const label = try infra.string.utf8ToUtf16(allocator, label_buf);
        defer allocator.free(label);

        try console_obj.call_timeEnd(label);
    }

    try std.testing.expect(console_obj.timerTable.isEmpty());
    // Test passes if no memory leaks
}
