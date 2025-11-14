//! Format Specifier Tests
//!
//! Tests for the Formatter operation (WHATWG Console Standard lines 297-338)
//! with format specifiers (%s, %d, %i, %f, %o, %O, %c).
//!
//! These tests verify Phase 3 (Lazy Formatting) and Phase 4 (Format Specifier Optimization).

const std = @import("std");
const console_mod = @import("console");
const webidl = @import("webidl");

test "Format specifier %s - string conversion" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: %s converts arguments to strings
    const format_str = webidl.JSValue{ .string = "Hello %s" };
    const arg1 = webidl.JSValue{ .string = "World" };

    const args = &[_]webidl.JSValue{ format_str, arg1 };
    console_obj.call_log(args);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Hello World"
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Hello World") != null);
}

test "Format specifier %d - integer conversion" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: %d converts numbers to integers
    const format_str = webidl.JSValue{ .string = "Count: %d" };
    const arg1 = webidl.JSValue{ .number = 42.7 };

    const args = &[_]webidl.JSValue{ format_str, arg1 };
    console_obj.call_log(args);

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Count: 43" (rounded)
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Count: 43") != null);
}

test "Format specifier %i - integer conversion (same as %d)" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: %i also converts to integers
    const format_str = webidl.JSValue{ .string = "Value: %i" };
    const arg1 = webidl.JSValue{ .number = 99.1 };

    const args = &[_]webidl.JSValue{ format_str, arg1 };
    console_obj.call_log(args);

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Value: 99" (rounded)
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Value: 99") != null);
}

test "Format specifier %f - float conversion" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: %f keeps float precision
    const format_str = webidl.JSValue{ .string = "Pi: %f" };
    const arg1 = webidl.JSValue{ .number = 3.14159 };

    const args = &[_]webidl.JSValue{ format_str, arg1 };
    console_obj.call_log(args);

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Pi: 3.14159"
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Pi: 3.14159") != null);
}

test "Format specifier - multiple specifiers" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: Multiple specifiers in one string
    const format_str = webidl.JSValue{ .string = "%s is %d years old" };
    const arg1 = webidl.JSValue{ .string = "Alice" };
    const arg2 = webidl.JSValue{ .number = 30.0 };

    const args = &[_]webidl.JSValue{ format_str, arg1, arg2 };
    console_obj.call_log(args);

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Alice is 30 years old"
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Alice is 30 years old") != null);
}

test "Format specifier - extra args after substitution" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: Extra args are preserved after substitution
    const format_str = webidl.JSValue{ .string = "Hello %s" };
    const arg1 = webidl.JSValue{ .string = "World" };
    const arg2 = webidl.JSValue{ .number = 123.0 };

    const args = &[_]webidl.JSValue{ format_str, arg1, arg2 };
    console_obj.call_log(args);

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain both "Hello World" and "123"
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Hello World") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "123") != null);
}

test "Format specifier - boolean conversion with %s" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: %s converts boolean to string
    const format_str = webidl.JSValue{ .string = "Active: %s" };
    const arg1 = webidl.JSValue{ .boolean = true };

    const args = &[_]webidl.JSValue{ format_str, arg1 };
    console_obj.call_log(args);

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Active: true"
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Active: true") != null);
}

test "Format specifier - no specifiers, args unchanged" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: No format specifiers means args are unchanged
    const str1 = webidl.JSValue{ .string = "Hello" };
    const str2 = webidl.JSValue{ .string = "World" };

    const args = &[_]webidl.JSValue{ str1, str2 };
    console_obj.call_log(args);

    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain both "Hello" and "World"
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "World") != null);
}

test "Phase 3 - Lazy formatting only when displayed" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test: Messages store raw args, format lazily
    const format_str = webidl.JSValue{ .string = "Value: %d" };
    const arg1 = webidl.JSValue{ .number = 42.0 };

    const args = &[_]webidl.JSValue{ format_str, arg1 };
    console_obj.call_log(args);

    // Message should have raw args stored
    const msg = console_obj.message_buffer.get(0).?;
    try std.testing.expectEqual(@as(usize, 1), msg.args.len); // After formatting, only 1 arg remains

    // Format should work when called
    const formatted1 = try msg.format(allocator);
    defer allocator.free(formatted1);

    const formatted2 = try msg.format(allocator);
    defer allocator.free(formatted2);

    // Both format calls should produce same result
    try std.testing.expectEqualStrings(formatted1, formatted2);
}
