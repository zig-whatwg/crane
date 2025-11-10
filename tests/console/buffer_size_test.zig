//! Configurable Buffer Size Tests
//!
//! Tests that console buffer size can be configured at initialization time
//! for different deployment scenarios.

const std = @import("std");
const console_mod = @import("console");
const webidl = @import("webidl");

test "default buffer size is 1000" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    try std.testing.expectEqual(@as(usize, 1000), console_obj.message_buffer.max_size);
}

test "custom buffer size - small (embedded)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.initWithBufferSize(allocator, 10);
    defer console_obj.deinit();

    try std.testing.expectEqual(@as(usize, 10), console_obj.message_buffer.max_size);

    // Fill buffer
    const args = &[_]webidl.JSValue{
        .{ .string = "test" },
    };

    var i: usize = 0;
    while (i < 15) : (i += 1) {
        console_obj.call_log(args);
    }

    // Should only have 10 messages (oldest discarded)
    try std.testing.expectEqual(@as(usize, 10), console_obj.message_buffer.size());
    try std.testing.expect(console_obj.message_buffer.isFull());
}

test "custom buffer size - large (server)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.initWithBufferSize(allocator, 5000);
    defer console_obj.deinit();

    try std.testing.expectEqual(@as(usize, 5000), console_obj.message_buffer.max_size);

    // Add some messages
    const args = &[_]webidl.JSValue{
        .{ .string = "test" },
    };

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        console_obj.call_log(args);
    }

    // Should have all 100 messages (buffer not full)
    try std.testing.expectEqual(@as(usize, 100), console_obj.message_buffer.size());
    try std.testing.expect(!console_obj.message_buffer.isFull());
}

test "zero buffer size - no buffering (testing mode)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.initWithBufferSize(allocator, 0);
    defer console_obj.deinit();

    try std.testing.expectEqual(@as(usize, 0), console_obj.message_buffer.max_size);

    // Try to log
    const args = &[_]webidl.JSValue{
        .{ .string = "This won't be buffered" },
    };
    console_obj.call_log(args);

    // Buffer should remain empty (immediately full, discards messages)
    try std.testing.expectEqual(@as(usize, 0), console_obj.message_buffer.size());
}

test "buffer size 1 - only keeps most recent message" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.initWithBufferSize(allocator, 1);
    defer console_obj.deinit();

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.max_size);

    // Log multiple messages
    console_obj.call_log(&[_]webidl.JSValue{.{ .string = "First" }});
    console_obj.call_log(&[_]webidl.JSValue{.{ .string = "Second" }});
    console_obj.call_log(&[_]webidl.JSValue{.{ .string = "Third" }});

    // Should only have 1 message (the last one)
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should be the most recent message
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Third") != null);
}

test "buffer overflow behavior - FIFO (oldest discarded)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.initWithBufferSize(allocator, 3);
    defer console_obj.deinit();

    // Fill buffer
    console_obj.call_log(&[_]webidl.JSValue{.{ .string = "Message 1" }});
    console_obj.call_log(&[_]webidl.JSValue{.{ .string = "Message 2" }});
    console_obj.call_log(&[_]webidl.JSValue{.{ .string = "Message 3" }});

    try std.testing.expectEqual(@as(usize, 3), console_obj.message_buffer.size());
    try std.testing.expect(console_obj.message_buffer.isFull());

    // Add one more - should discard oldest
    console_obj.call_log(&[_]webidl.JSValue{.{ .string = "Message 4" }});

    try std.testing.expectEqual(@as(usize, 3), console_obj.message_buffer.size());

    // Should have messages 2, 3, 4 (message 1 was discarded)
    const msg0 = console_obj.message_buffer.get(0).?;
    const formatted0 = try msg0.format(allocator);
    defer allocator.free(formatted0);
    try std.testing.expect(std.mem.indexOf(u8, formatted0, "Message 2") != null);

    const msg2 = console_obj.message_buffer.get(2).?;
    const formatted2 = try msg2.format(allocator);
    defer allocator.free(formatted2);
    try std.testing.expect(std.mem.indexOf(u8, formatted2, "Message 4") != null);
}

test "multiple consoles with different buffer sizes" {
    const allocator = std.testing.allocator;

    var console_small = try console_mod.console.initWithBufferSize(allocator, 5);
    defer console_small.deinit();

    var console_large = try console_mod.console.initWithBufferSize(allocator, 100);
    defer console_large.deinit();

    try std.testing.expectEqual(@as(usize, 5), console_small.message_buffer.max_size);
    try std.testing.expectEqual(@as(usize, 100), console_large.message_buffer.max_size);

    // Both work independently
    const args = &[_]webidl.JSValue{.{ .string = "test" }};

    console_small.call_log(args);
    console_large.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_small.message_buffer.size());
    try std.testing.expectEqual(@as(usize, 1), console_large.message_buffer.size());
}

test "buffer size with disabled console - no allocation waste" {
    const allocator = std.testing.allocator;

    // Create disabled console with zero buffer
    var console_obj = try console_mod.console.initWithBufferSize(allocator, 0);
    console_obj.enabled = false;
    console_obj.print_fn = null;
    defer console_obj.deinit();

    // Log should be no-op
    const args = &[_]webidl.JSValue{.{ .string = "Ignored" }};
    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 0), console_obj.message_buffer.size());
}
