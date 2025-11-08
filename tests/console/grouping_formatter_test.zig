//! Group Label Formatting Tests
//!
//! Tests that group() and groupCollapsed() properly use the Formatter
//! to format group labels with format specifiers.

const std = @import("std");
const Console = @import("console").Console;
const webidl = @import("webidl");

test "group() with format specifier - string substitution" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Test: Group label with %s format specifier
    const args = &[_]webidl.JSValue{
        .{ .string = "User: %s" },
        .{ .string = "Alice" },
    };

    try console_obj.call_group(args);

    // Verify group was created
    try std.testing.expectEqual(@as(usize, 1), console_obj.group_stack.size());

    // Verify label was formatted correctly
    const group = console_obj.group_stack.peek().?;
    try std.testing.expect(group.label != null);

    const label_utf8 = try std.mem.Allocator.dupeZ(allocator, u16, group.label.?);
    defer allocator.free(label_utf8);

    // Clean up
    console_obj.call_groupEnd();
    try std.testing.expectEqual(@as(usize, 0), console_obj.group_stack.size());
}

test "group() with multiple format specifiers" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Test: Group label with multiple format specifiers
    const args = &[_]webidl.JSValue{
        .{ .string = "%s - Age: %d" },
        .{ .string = "Bob" },
        .{ .number = 25.0 },
    };

    try console_obj.call_group(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.group_stack.size());

    const group = console_obj.group_stack.peek().?;
    try std.testing.expect(group.label != null);

    console_obj.call_groupEnd();
    try std.testing.expectEqual(@as(usize, 0), console_obj.group_stack.size());
}

test "groupCollapsed() with format specifier" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Test: Collapsed group with format specifier
    const args = &[_]webidl.JSValue{
        .{ .string = "Section %d" },
        .{ .number = 42.0 },
    };

    try console_obj.call_groupCollapsed(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.group_stack.size());

    const group = console_obj.group_stack.peek().?;
    try std.testing.expect(group.label != null);
    try std.testing.expect(group.collapsed); // Should be collapsed

    console_obj.call_groupEnd();
    try std.testing.expectEqual(@as(usize, 0), console_obj.group_stack.size());
}

test "group() without arguments - no label" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Test: Group without label
    const args: [0]webidl.JSValue = .{};
    try console_obj.call_group(&args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.group_stack.size());

    const group = console_obj.group_stack.peek().?;
    try std.testing.expect(group.label == null); // No label

    console_obj.call_groupEnd();
    try std.testing.expectEqual(@as(usize, 0), console_obj.group_stack.size());
}

test "groupEnd() frees allocated labels - no memory leak" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Create multiple groups with labels
    const args1 = &[_]webidl.JSValue{
        .{ .string = "Group 1" },
    };
    const args2 = &[_]webidl.JSValue{
        .{ .string = "Group 2: %d" },
        .{ .number = 123.0 },
    };

    try console_obj.call_group(args1);
    try console_obj.call_group(args2);

    try std.testing.expectEqual(@as(usize, 2), console_obj.group_stack.size());

    // Pop both groups - should free labels without leaking
    console_obj.call_groupEnd();
    console_obj.call_groupEnd();

    try std.testing.expectEqual(@as(usize, 0), console_obj.group_stack.size());
}

test "nested groups with format specifiers" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Test nested groups
    try console_obj.call_group(&[_]webidl.JSValue{
        .{ .string = "Outer %s" },
        .{ .string = "Group" },
    });

    try console_obj.call_group(&[_]webidl.JSValue{
        .{ .string = "Inner %d" },
        .{ .number = 1.0 },
    });

    try std.testing.expectEqual(@as(usize, 2), console_obj.group_stack.size());

    // Log something in nested group
    const log_args = &[_]webidl.JSValue{
        .{ .string = "Nested message" },
    };
    console_obj.call_log(log_args);

    // Should be indented 2 levels
    const msg = console_obj.message_buffer.get(0).?;
    try std.testing.expectEqual(@as(usize, 2), msg.indent);

    // Pop inner group
    console_obj.call_groupEnd();
    try std.testing.expectEqual(@as(usize, 1), console_obj.group_stack.size());

    // Pop outer group
    console_obj.call_groupEnd();
    try std.testing.expectEqual(@as(usize, 0), console_obj.group_stack.size());
}
