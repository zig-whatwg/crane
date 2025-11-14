//! Counting Function Tests
//!
//! Tests for Console counting functions: count(), countReset().
//! WHATWG Console Standard lines 145-174.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");


test "call_count - first call sets count to 1" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "test-counter";

    // Initially no count exists
    try std.testing.expect(!console_obj.countMap.contains(label));

    // First count
    try console_obj.call_count(label);

    // Count should be 1
    try std.testing.expectEqual(@as(?u32, 1), console_obj.countMap.get(label));
}

test "call_count - increments existing count" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "increment-counter";

    // Count multiple times
    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 1), console_obj.countMap.get(label));

    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 2), console_obj.countMap.get(label));

    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 3), console_obj.countMap.get(label));

    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 4), console_obj.countMap.get(label));

    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 5), console_obj.countMap.get(label));
}

test "call_countReset - resets existing counter to 0" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "reset-counter";

    // Count up to 10
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try console_obj.call_count(label);
    }
    try std.testing.expectEqual(@as(?u32, 10), console_obj.countMap.get(label));

    // Reset counter
    try console_obj.call_countReset(label);

    // Counter should be 0
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(label));
}

test "call_countReset - missing counter shows warning (no error)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "nonexistent-counter";

    // Reset counter that doesn't exist (should not error)
    try console_obj.call_countReset(label);

    // Counter should still not exist
    try std.testing.expect(!console_obj.countMap.contains(label));
}

test "counting - reset then count starts from 1" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "reset-then-count";

    // Count to 5
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        try console_obj.call_count(label);
    }
    try std.testing.expectEqual(@as(?u32, 5), console_obj.countMap.get(label));

    // Reset to 0
    try console_obj.call_countReset(label);
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(label));

    // Count again - should go to 1
    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 1), console_obj.countMap.get(label));
}

test "counting - multiple independent counters" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const counter1 = "counter1";
    const counter2 = "counter2";
    const counter3 = "counter3";

    // Count counter1 3 times
    try console_obj.call_count(counter1);
    try console_obj.call_count(counter1);
    try console_obj.call_count(counter1);

    // Count counter2 5 times
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        try console_obj.call_count(counter2);
    }

    // Count counter3 once
    try console_obj.call_count(counter3);

    // Verify all counters are independent
    try std.testing.expectEqual(@as(?u32, 3), console_obj.countMap.get(counter1));
    try std.testing.expectEqual(@as(?u32, 5), console_obj.countMap.get(counter2));
    try std.testing.expectEqual(@as(?u32, 1), console_obj.countMap.get(counter3));
}

test "counting - reset one counter doesn't affect others" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const counter1 = "counter1";
    const counter2 = "counter2";

    // Count both counters
    try console_obj.call_count(counter1);
    try console_obj.call_count(counter1);
    try console_obj.call_count(counter2);
    try console_obj.call_count(counter2);
    try console_obj.call_count(counter2);

    try std.testing.expectEqual(@as(?u32, 2), console_obj.countMap.get(counter1));
    try std.testing.expectEqual(@as(?u32, 3), console_obj.countMap.get(counter2));

    // Reset counter1
    try console_obj.call_countReset(counter1);

    // counter1 should be 0, counter2 unchanged
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(counter1));
    try std.testing.expectEqual(@as(?u32, 3), console_obj.countMap.get(counter2));
}

test "counting - default label works" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const default_label = "default";

    // Use "default" as label (WebIDL default parameter)
    try console_obj.call_count(default_label);
    try console_obj.call_count(default_label);
    try std.testing.expectEqual(@as(?u32, 2), console_obj.countMap.get(default_label));

    try console_obj.call_countReset(default_label);
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(default_label));
}

test "counting - counter can go very high" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "high-counter";

    // Count many times
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        try console_obj.call_count(label);
    }

    try std.testing.expectEqual(@as(?u32, 1000), console_obj.countMap.get(label));
}

test "counting - multiple resets work" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "multi-reset";

    // Count, reset, count, reset, count
    try console_obj.call_count(label);
    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 2), console_obj.countMap.get(label));

    try console_obj.call_countReset(label);
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(label));

    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 1), console_obj.countMap.get(label));

    try console_obj.call_countReset(label);
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(label));

    try console_obj.call_count(label);
    try console_obj.call_count(label);
    try console_obj.call_count(label);
    try std.testing.expectEqual(@as(?u32, 3), console_obj.countMap.get(label));
}

test "counting - memory safety with many counters" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Create many counters
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const label_buf = try std.fmt.allocPrint(allocator, "counter{d}", .{i});
        defer allocator.free(label_buf);
        const label = try infra.string.utf8ToUtf16(allocator, label_buf);
        defer allocator.free(label);

        // Count each counter i times
        var j: usize = 0;
        while (j <= i) : (j += 1) {
            try console_obj.call_count(label);
        }
    }

    try std.testing.expectEqual(@as(usize, 100), console_obj.countMap.size());

    // Reset half of them
    i = 0;
    while (i < 50) : (i += 1) {
        const label_buf = try std.fmt.allocPrint(allocator, "counter{d}", .{i});
        defer allocator.free(label_buf);
        const label = try infra.string.utf8ToUtf16(allocator, label_buf);
        defer allocator.free(label);

        try console_obj.call_countReset(label);
    }

    // All counters still exist (reset sets to 0, doesn't remove)
    try std.testing.expectEqual(@as(usize, 100), console_obj.countMap.size());

    // Test passes if no memory leaks
}

test "counting - Unicode labels work" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const unicode_label = "カウンター";

    try console_obj.call_count(unicode_label);
    try console_obj.call_count(unicode_label);
    try std.testing.expectEqual(@as(?u32, 2), console_obj.countMap.get(unicode_label));

    try console_obj.call_countReset(unicode_label);
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(unicode_label));
}

test "counting - empty string label works" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const empty_label = "";

    try console_obj.call_count(empty_label);
    try std.testing.expectEqual(@as(?u32, 1), console_obj.countMap.get(empty_label));

    try console_obj.call_countReset(empty_label);
    try std.testing.expectEqual(@as(?u32, 0), console_obj.countMap.get(empty_label));
}
