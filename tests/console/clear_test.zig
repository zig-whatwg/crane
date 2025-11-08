//! Tests for console.clear() implementation
//!
//! WHATWG Console Standard lines 75-79:
//! clear() empties the group stack and clears console output.

const std = @import("std");
const webidl = @import("webidl");
const testing = std.testing;

// Import Console from zoop_src
const Console = @import("../zoop_src/console.zig").Console;

test "clear - empty console (no-op)" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Clear empty console should be safe
    console.call_clear();

    // Verify buffer is still empty
    try testing.expectEqual(@as(usize, 0), console.message_buffer.size());
    try testing.expect(console.message_buffer.isEmpty());
}

test "clear - removes all messages from buffer" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Add some messages
    const msg1 = webidl.JSValue{ .string = "Message 1" };
    const msg2 = webidl.JSValue{ .string = "Message 2" };
    const msg3 = webidl.JSValue{ .string = "Message 3" };

    console.call_log(&.{msg1});
    console.call_log(&.{msg2});
    console.call_log(&.{msg3});

    // Verify messages were added
    try testing.expectEqual(@as(usize, 3), console.message_buffer.size());

    // Clear the console
    console.call_clear();

    // Verify buffer is now empty
    try testing.expectEqual(@as(usize, 0), console.message_buffer.size());
    try testing.expect(console.message_buffer.isEmpty());
}

test "clear - empties group stack" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Create nested groups
    const label1 = webidl.JSValue{ .string = "Group 1" };
    const label2 = webidl.JSValue{ .string = "Group 2" };
    const label3 = webidl.JSValue{ .string = "Group 3" };

    console.call_group(&.{label1});
    console.call_group(&.{label2});
    console.call_group(&.{label3});

    // Verify groups were created
    try testing.expectEqual(@as(usize, 3), console.group_stack.items.len);

    // Clear the console
    console.call_clear();

    // Verify group stack is now empty
    try testing.expectEqual(@as(usize, 0), console.group_stack.items.len);
}

test "clear - empties both groups and messages" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Create groups and add messages
    const label = webidl.JSValue{ .string = "Test Group" };
    console.call_group(&.{label});

    const msg1 = webidl.JSValue{ .string = "Inside group" };
    const msg2 = webidl.JSValue{ .string = "Another message" };
    console.call_log(&.{msg1});
    console.call_log(&.{msg2});

    // Verify state before clear
    try testing.expectEqual(@as(usize, 1), console.group_stack.items.len);
    try testing.expectEqual(@as(usize, 2), console.message_buffer.size());

    // Clear the console
    console.call_clear();

    // Verify both are empty
    try testing.expectEqual(@as(usize, 0), console.group_stack.items.len);
    try testing.expectEqual(@as(usize, 0), console.message_buffer.size());
}

test "clear - console works after clearing" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Add messages, then clear
    const msg1 = webidl.JSValue{ .string = "Before clear" };
    console.call_log(&.{msg1});
    console.call_clear();

    // Add messages after clear
    const msg2 = webidl.JSValue{ .string = "After clear" };
    console.call_log(&.{msg2});

    // Verify only new message is in buffer
    try testing.expectEqual(@as(usize, 1), console.message_buffer.size());

    const stored = console.message_buffer.get(0).?;
    try testing.expect(stored.args.len == 1);
    try testing.expect(stored.args[0] == .string);
    try testing.expectEqualStrings("After clear", stored.args[0].string);
}

test "clear - multiple clears are safe" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Clear multiple times
    console.call_clear();
    console.call_clear();
    console.call_clear();

    // Add message
    const msg = webidl.JSValue{ .string = "Test" };
    console.call_log(&.{msg});

    // Clear again
    console.call_clear();

    // Verify empty
    try testing.expectEqual(@as(usize, 0), console.message_buffer.size());
    try testing.expectEqual(@as(usize, 0), console.group_stack.items.len);
}

test "clear - with deeply nested groups" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Create 10 nested groups
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        var buf: [32]u8 = undefined;
        const label_str = try std.fmt.bufPrint(&buf, "Group {d}", .{i});
        const label = webidl.JSValue{ .string = label_str };
        console.call_group(&.{label});
    }

    // Verify all groups created
    try testing.expectEqual(@as(usize, 10), console.group_stack.items.len);

    // Clear should handle all groups
    console.call_clear();

    // Verify all cleared
    try testing.expectEqual(@as(usize, 0), console.group_stack.items.len);
}

test "clear - with full message buffer" {
    const allocator = testing.allocator;
    // Create console with small buffer
    var console = try Console.initWithBufferSize(allocator, 5);
    defer console.deinit();

    // Fill buffer to capacity
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        var buf: [32]u8 = undefined;
        const msg_str = try std.fmt.bufPrint(&buf, "Message {d}", .{i});
        const msg = webidl.JSValue{ .string = msg_str };
        console.call_log(&.{msg});
    }

    // Verify buffer is full
    try testing.expect(console.message_buffer.isFull());
    try testing.expectEqual(@as(usize, 5), console.message_buffer.size());

    // Clear full buffer
    console.call_clear();

    // Verify empty
    try testing.expectEqual(@as(usize, 0), console.message_buffer.size());
    try testing.expect(console.message_buffer.isEmpty());
    try testing.expect(!console.message_buffer.isFull());
}

test "clear - memory leak verification" {
    const allocator = testing.allocator;
    var console = try Console.init(allocator);
    defer console.deinit();

    // Add messages with allocated strings
    const msg1 = webidl.JSValue{ .string = "Test message 1" };
    const msg2 = webidl.JSValue{ .string = "Test message 2" };
    const msg3 = webidl.JSValue{ .string = "Test message 3" };

    console.call_log(&.{msg1});
    console.call_log(&.{msg2});
    console.call_log(&.{msg3});

    // Clear should properly free all message memory
    console.call_clear();

    // If there are leaks, std.testing.allocator will catch them
    try testing.expectEqual(@as(usize, 0), console.message_buffer.size());
}

test "clear - preserves console configuration" {
    const allocator = testing.allocator;
    var console = try Console.initWithBufferSize(allocator, 100);
    defer console.deinit();

    // Get initial buffer capacity
    const initial_capacity = console.message_buffer.max_size;
    try testing.expectEqual(@as(usize, 100), initial_capacity);

    // Add and clear
    const msg = webidl.JSValue{ .string = "Test" };
    console.call_log(&.{msg});
    console.call_clear();

    // Verify buffer capacity unchanged
    try testing.expectEqual(initial_capacity, console.message_buffer.max_size);
}
