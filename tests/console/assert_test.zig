//! Assert Tests
//!
//! Tests for console.assert() with proper "Assertion failed" message building.
//! WHATWG Console Standard lines 52-72.

const std = @import("std");
const infra = @import("infra");
const console_mod = @import("console");
const webidl = @import("webidl");

test "assert with true condition - no output" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // True condition - should not log anything
    const args = &[_]webidl.JSValue{
        .{ .string = "This should not appear" },
    };
    console_obj.call_assert(true, args);

    // No message should be buffered
    try std.testing.expectEqual(@as(usize, 0), console_obj.messageBuffer.size());
}

test "assert with false condition - logs 'Assertion failed'" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // False condition - should log
    const args: [0]webidl.JSValue = .{};
    console_obj.call_assert(false, &args);

    // Should have one message
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    const msg = console_obj.messageBuffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Assertion failed"
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Assertion failed") != null);
}

test "assert with false condition and message" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // False condition with message
    const args = &[_]webidl.JSValue{
        .{ .string = "Something went wrong" },
    };
    console_obj.call_assert(false, args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    const msg = console_obj.messageBuffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain both "Assertion failed" and the message
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Assertion failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Something went wrong") != null);
}

test "assert with false condition and format specifiers" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // False condition with format specifiers
    const args = &[_]webidl.JSValue{
        .{ .string = "Value: %d" },
        .{ .number = 42.0 },
    };
    console_obj.call_assert(false, args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    const msg = console_obj.messageBuffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Assertion failed" and formatted value
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Assertion failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "42") != null);
}

test "assert with false condition and multiple args" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // False condition with multiple args
    const args = &[_]webidl.JSValue{
        .{ .string = "Error:" },
        .{ .string = "Code" },
        .{ .number = 500.0 },
    };
    console_obj.call_assert(false, args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    const msg = console_obj.messageBuffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    // Should contain "Assertion failed" and all args
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Assertion failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Error:") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Code") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "500") != null);
}

test "assert with boolean values" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Test with explicit boolean false
    console_obj.call_assert(false, &[_]webidl.JSValue{
        .{ .string = "Explicitly false" },
    });

    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    // Test with explicit boolean true
    console_obj.call_assert(true, &[_]webidl.JSValue{
        .{ .string = "This won't log" },
    });

    // Still only 1 message (true condition didn't log)
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());
}

test "assert message uses correct log level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.call_assert(false, &[_]webidl.JSValue{
        .{ .string = "Test" },
    });

    const msg = console_obj.messageBuffer.get(0).?;

    // Should use assert_level
    try std.testing.expectEqual(@as(@TypeOf(msg.logLevel), .assert_level), msg.logLevel);
}

test "assert allocation failure gracefully degrades" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // This should still work even if we can't test allocation failure directly
    // The code handles it gracefully by logging data without prefix
    const args = &[_]webidl.JSValue{
        .{ .string = "Message without prefix if allocation fails" },
    };
    console_obj.call_assert(false, args);

    // Should still log something
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());
}

test "assert with custom printer - output captured" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Capture output
    var output = infra.List(u8).init(allocator);
    defer output.deinit();

    const CustomPrinter = struct {
        var capture_buffer: *infra.List(u8) = undefined;

        fn print(comptime fmt: []const u8, args: anytype) void {
            capture_buffer.writer().print(fmt, args) catch {};
        }
    };

    CustomPrinter.capture_buffer = &output;
    console_obj.printFn = CustomPrinter.print;

    // Trigger assertion
    console_obj.call_assert(false, &[_]webidl.JSValue{
        .{ .string = "Custom printer test" },
    });

    // Output should contain assertion message
    try std.testing.expect(output.items().len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output.items(), "Assertion failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items(), "Custom printer test") != null);
}

test "multiple assertions - all logged" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Multiple failed assertions
    console_obj.call_assert(false, &[_]webidl.JSValue{.{ .string = "First" }});
    console_obj.call_assert(false, &[_]webidl.JSValue{.{ .string = "Second" }});
    console_obj.call_assert(false, &[_]webidl.JSValue{.{ .string = "Third" }});

    // Should have 3 messages
    try std.testing.expectEqual(@as(usize, 3), console_obj.messageBuffer.size());

    // Each should contain "Assertion failed"
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const msg = console_obj.messageBuffer.get(i).?;
        const formatted = try msg.format(allocator);
        defer allocator.free(formatted);

        try std.testing.expect(std.mem.indexOf(u8, formatted, "Assertion failed") != null);
    }
}
