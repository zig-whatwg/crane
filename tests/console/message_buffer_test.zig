//! Message Buffering Tests
//!
//! Tests for console message buffering (circular buffer, max 1000 entries).
//! This follows the browser pattern where messages are stored for history
//! and lazy formatting.
//!
//! See BROWSER_PATTERNS.md Phase 2 for details.

const std = @import("std");
const console_mod = @import("console");
const infra = @import("infra");

const console_mod.console = console.console;
const JSValue = console.JSValue;

test "message buffer - basic message storage" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Initially empty
    try std.testing.expectEqual(@as(usize, 0), console_obj.messageBuffer.size());

    // Log a message
    const mock_args: []const JSValue = &.{};
    console_obj.call_log(mock_args);

    // Should have 1 message in buffer
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());
}

test "message buffer - multiple messages" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Log multiple messages
    console_obj.call_log(mock_args);
    console_obj.call_debug(mock_args);
    console_obj.call_info(mock_args);
    console_obj.call_warn(mock_args);
    console_obj.call_error(mock_args);

    // Should have 5 messages
    try std.testing.expectEqual(@as(usize, 5), console_obj.messageBuffer.size());
}

test "message buffer - circular overflow at 1000" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Fill buffer to capacity (1000 messages)
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        console_obj.call_log(mock_args);
    }

    try std.testing.expectEqual(@as(usize, 1000), console_obj.messageBuffer.size());
    try std.testing.expect(console_obj.messageBuffer.isFull());

    // Add one more - should still be 1000 (oldest discarded)
    console_obj.call_log(mock_args);
    try std.testing.expectEqual(@as(usize, 1000), console_obj.messageBuffer.size());
}

test "message buffer - message content" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Log different levels
    console_obj.call_log(mock_args);
    console_obj.call_warn(mock_args);
    console_obj.call_error(mock_args);

    // Check message log levels
    const msg0 = console_obj.messageBuffer.get(0);
    try std.testing.expect(msg0 != null);
    try std.testing.expectEqual(console.LogLevel.log, msg0.?.logLevel);

    const msg1 = console_obj.messageBuffer.get(1);
    try std.testing.expect(msg1 != null);
    try std.testing.expectEqual(console.LogLevel.warn, msg1.?.logLevel);

    const msg2 = console_obj.messageBuffer.get(2);
    try std.testing.expect(msg2 != null);
    try std.testing.expectEqual(console.LogLevel.error_level, msg2.?.logLevel);
}

test "message buffer - grouping indentation in messages" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Log without groups
    console_obj.call_log(mock_args);

    // Start group and log
    try console_obj.call_group(&.{});
    console_obj.call_log(mock_args);

    // Nested group
    try console_obj.call_group(&.{});
    console_obj.call_log(mock_args);

    try std.testing.expectEqual(@as(usize, 3), console_obj.messageBuffer.size());

    // Check indentation in formatted strings
    const msg0 = console_obj.messageBuffer.get(0);
    try std.testing.expect(msg0 != null);
    try std.testing.expect(!std.mem.startsWith(u8, msg0.?.formatted, "  ")); // No indent

    const msg1 = console_obj.messageBuffer.get(1);
    try std.testing.expect(msg1 != null);
    try std.testing.expect(std.mem.startsWith(u8, msg1.?.formatted, "  ")); // 1 level

    const msg2 = console_obj.messageBuffer.get(2);
    try std.testing.expect(msg2 != null);
    try std.testing.expect(std.mem.startsWith(u8, msg2.?.formatted, "    ")); // 2 levels
}

test "message buffer - disabled console doesn't buffer" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Disable console
    console_obj.enabled = false;

    // Log messages
    console_obj.call_log(mock_args);
    console_obj.call_warn(mock_args);
    console_obj.call_error(mock_args);

    // Should have 0 messages (fast disabled path)
    try std.testing.expectEqual(@as(usize, 0), console_obj.messageBuffer.size());
}

test "message buffer - clear() doesn't affect buffer" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Log messages
    console_obj.call_log(mock_args);
    console_obj.call_warn(mock_args);

    try std.testing.expectEqual(@as(usize, 2), console_obj.messageBuffer.size());

    // clear() only empties group stack, not message buffer
    console_obj.call_clear();

    // Messages should still be in buffer
    try std.testing.expectEqual(@as(usize, 2), console_obj.messageBuffer.size());
}

test "message buffer - timing messages buffered" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "timer";

    try console_obj.call_time(label); // Should not buffer (no output)
    try std.testing.expectEqual(@as(usize, 0), console_obj.messageBuffer.size());

    const mock_data: []const JSValue = &.{};
    try console_obj.call_timeLog(label, mock_data); // Should buffer
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    try console_obj.call_timeEnd(label); // Should buffer
    try std.testing.expectEqual(@as(usize, 2), console_obj.messageBuffer.size());
}

test "message buffer - counting messages buffered" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const label = "counter";

    try console_obj.call_count(label); // "counter: 1" - should buffer
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    try console_obj.call_count(label); // "counter: 2" - should buffer
    try std.testing.expectEqual(@as(usize, 2), console_obj.messageBuffer.size());

    try console_obj.call_countReset(label); // Warning - should buffer
    try std.testing.expectEqual(@as(usize, 3), console_obj.messageBuffer.size());
}

test "message buffer - memory safety (no leaks)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Log many messages
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        console_obj.call_log(mock_args);
        console_obj.call_debug(mock_args);
        console_obj.call_warn(mock_args);
    }

    try std.testing.expectEqual(@as(usize, 300), console_obj.messageBuffer.size());

    // deinit should clean up all buffered messages without leaking
}
