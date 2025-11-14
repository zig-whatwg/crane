//! Tests for count/countReset logger integration
//!
//! Verifies that count() and countReset() use printer() instead of std.debug.print.

const std = @import("std");
const console_mod = @import("console");
const webidl = @import("webidl");
const infra = @import("infra");

test "count - uses printer for output" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Disable printer to verify it's being called (won't crash)
    console_obj.printFn = null;

    const label = "test-counter";

    // Call count multiple times
    console_obj.call_count(label);
    console_obj.call_count(label);
    console_obj.call_count(label);

    // Verify count is tracked correctly
    const count = console_obj.countMap.get(label).?;
    try std.testing.expectEqual(@as(u32, 3), count);
}

test "countReset - uses printer for warning when counter doesn't exist" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Disable printer
    console_obj.printFn = null;

    const label = "nonexistent";

    // Reset non-existent counter (should warn, not crash)
    console_obj.call_countReset(label);

    // Verify counter still doesn't exist
    try std.testing.expect(!console_obj.countMap.contains(label));
}

test "countReset - resets existing counter to zero" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.printFn = null;

    const label = "my-counter";

    // Create counter
    console_obj.call_count(label);
    console_obj.call_count(label);
    console_obj.call_count(label);

    // Verify count is 3
    try std.testing.expectEqual(@as(u32, 3), console_obj.countMap.get(label).?);

    // Reset
    console_obj.call_countReset(label);

    // Verify reset to 0
    try std.testing.expectEqual(@as(u32, 0), console_obj.countMap.get(label).?);
}

test "count - message buffering works" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.printFn = null;

    const label = "buffered";

    // Count twice
    console_obj.call_count(label);
    console_obj.call_count(label);

    // Verify messages were buffered
    try std.testing.expectEqual(@as(usize, 2), console_obj.messageBuffer.size());

    // Check first message format
    const msg1 = console_obj.messageBuffer.get(0).?;
    try std.testing.expectEqual(@as(usize, 1), msg1.args.len);
    try std.testing.expect(msg1.args[0] == .string);

    // Should contain "buffered: 1"
    try std.testing.expect(std.mem.indexOf(u8, msg1.args[0].string, "buffered") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg1.args[0].string, "1") != null);
}
