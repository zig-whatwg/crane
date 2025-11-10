//! String Interning Tests
//!
//! Tests for console label string interning optimization.
//! Common labels like "default" are used 90% of the time for timers/counters.
//! By interning these strings, we reduce allocations and enable pointer equality.
//!
//! See BROWSER_PATTERNS.md Phase 5 for details.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");

const console_type = console.console;

test "string interning - default label pre-interned" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // "default" should already be in the pool
    try std.testing.expect(console_obj.label_pool.contains("default"));
}

test "string interning - intern same label multiple times" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // Intern the same label twice
    const label1 = try console_obj.internLabel("my-timer");
    const label2 = try console_obj.internLabel("my-timer");

    // Should return the same pointer (from pool)
    try std.testing.expectEqual(label1.ptr, label2.ptr);
}

test "string interning - different labels have different pointers" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    const label1 = try console_obj.internLabel("timer1");
    const label2 = try console_obj.internLabel("timer2");

    // Different labels should have different pointers
    try std.testing.expect(label1.ptr != label2.ptr);
}

test "string interning - count uses interned labels" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    const label = try infra.string.utf8ToUtf16(allocator, "counter");
    defer allocator.free(label);

    // Call count multiple times - should intern "counter" label
    try console_obj.call_count(label);
    try console_obj.call_count(label);
    try console_obj.call_count(label);

    // Label should be in the pool
    try std.testing.expect(console_obj.label_pool.contains("counter"));
}

test "string interning - time uses interned labels" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    const label = try infra.string.utf8ToUtf16(allocator, "my-timer");
    defer allocator.free(label);

    try console_obj.call_time(label);

    const data: []const console.JSValue = &.{};
    try console_obj.call_timeLog(label, data);

    // Label should be in the pool (from timeLog conversion)
    try std.testing.expect(console_obj.label_pool.contains("my-timer"));
}

test "string interning - default label is zero-cost" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // Get "default" multiple times - should always return same pointer
    const default1 = try console_obj.internLabel("default");
    const default2 = try console_obj.internLabel("default");
    const default3 = try console_obj.internLabel("default");

    try std.testing.expectEqual(default1.ptr, default2.ptr);
    try std.testing.expectEqual(default2.ptr, default3.ptr);
}

test "string interning - pool grows with unique labels" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // Initially has "default"
    try std.testing.expectEqual(@as(usize, 1), console_obj.label_pool.count());

    _ = try console_obj.internLabel("timer1");
    try std.testing.expectEqual(@as(usize, 2), console_obj.label_pool.count());

    _ = try console_obj.internLabel("timer2");
    try std.testing.expectEqual(@as(usize, 3), console_obj.label_pool.count());

    // Re-interning doesn't increase count
    _ = try console_obj.internLabel("timer1");
    try std.testing.expectEqual(@as(usize, 3), console_obj.label_pool.count());
}

test "string interning - memory safety (no leaks)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // Intern many labels
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const label = try std.fmt.allocPrint(allocator, "label-{d}", .{i});
        defer allocator.free(label);

        _ = try console_obj.internLabel(label);
    }

    // deinit should clean up all interned strings without leaking
}

test "string interning - realistic usage pattern" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // Simulate realistic usage: mostly "default", some custom labels
    const default_label = try infra.string.utf8ToUtf16(allocator, "default");
    defer allocator.free(default_label);

    const custom_label = try infra.string.utf8ToUtf16(allocator, "custom");
    defer allocator.free(custom_label);

    // 90% default, 10% custom (realistic browser pattern)
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        if (i % 10 == 0) {
            try console_obj.call_count(custom_label);
        } else {
            try console_obj.call_count(default_label);
        }
    }

    // Only 2 labels should be interned (default + custom)
    try std.testing.expectEqual(@as(usize, 2), console_obj.label_pool.count());
}
