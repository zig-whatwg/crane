//! Configurable Printer Tests
//!
//! Tests that console.print_fn can be configured to control output destination.

const std = @import("std");
const Console = @import("console").Console;
const webidl = @import("webidl");

test "default print_fn uses std.debug.print" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Verify default is std.debug.print
    try std.testing.expect(console_obj.print_fn != null);
    try std.testing.expectEqual(std.debug.print, console_obj.print_fn.?);
}

test "production mode - null print_fn disables immediate output" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Production mode: disable immediate output
    console_obj.print_fn = null;

    // Log something
    const args = &[_]webidl.JSValue{
        .{ .string = "This should only buffer, not print" },
    };
    console_obj.call_log(args);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());

    // Verify it would format correctly if we asked for it
    const msg = console_obj.message_buffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "This should only buffer") != null);
}

test "custom print_fn - capture output to buffer" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Set up custom printer that captures output
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const CustomPrinter = struct {
        var capture_buffer: *std.ArrayList(u8) = undefined;

        fn print(comptime fmt: []const u8, args: anytype) void {
            capture_buffer.writer().print(fmt, args) catch {};
        }
    };

    CustomPrinter.capture_buffer = &output;
    console_obj.print_fn = CustomPrinter.print;

    // Log something
    const args = &[_]webidl.JSValue{
        .{ .string = "Test message" },
    };
    console_obj.call_log(args);

    // Verify output was captured
    try std.testing.expect(output.items.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "Test message") != null);
}

test "switch print_fn at runtime" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Start in production mode (no output)
    console_obj.print_fn = null;

    const args = &[_]webidl.JSValue{
        .{ .string = "Silent message" },
    };
    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());

    // Switch to development mode (with output)
    console_obj.print_fn = std.debug.print;

    const args2 = &[_]webidl.JSValue{
        .{ .string = "Loud message" },
    };
    console_obj.call_log(args2);

    try std.testing.expectEqual(@as(usize, 2), console_obj.message_buffer.size());
}

test "disabled console with null print_fn - minimal overhead" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Fully disable console
    console_obj.enabled = false;
    console_obj.print_fn = null;

    // These calls should be no-ops
    const args = &[_]webidl.JSValue{
        .{ .string = "This is ignored" },
    };
    console_obj.call_log(args); // Fast disabled path

    // Message buffer should be empty (logger returned early)
    try std.testing.expectEqual(@as(usize, 0), console_obj.message_buffer.size());
}

test "print_fn with format specifiers in messages" {
    const allocator = std.testing.allocator;
    var console_obj = try Console.init(allocator);
    defer console_obj.deinit();

    // Capture output
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const CustomPrinter = struct {
        var capture_buffer: *std.ArrayList(u8) = undefined;

        fn print(comptime fmt: []const u8, args: anytype) void {
            capture_buffer.writer().print(fmt, args) catch {};
        }
    };

    CustomPrinter.capture_buffer = &output;
    console_obj.print_fn = CustomPrinter.print;

    // Log with format specifiers
    const args = &[_]webidl.JSValue{
        .{ .string = "User %s is %d years old" },
        .{ .string = "Alice" },
        .{ .number = 30.0 },
    };
    console_obj.call_log(args);

    // Verify formatted output was captured
    try std.testing.expect(std.mem.indexOf(u8, output.items, "Alice") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "30") != null);
}

test "multiple console instances with different printers" {
    const allocator = std.testing.allocator;

    var console1 = try Console.init(allocator);
    defer console1.deinit();

    var console2 = try Console.init(allocator);
    defer console2.deinit();

    // Console 1: production mode (no output)
    console1.print_fn = null;

    // Console 2: development mode (has output)
    console2.print_fn = std.debug.print;

    const args = &[_]webidl.JSValue{
        .{ .string = "Test" },
    };

    console1.call_log(args);
    console2.call_log(args);

    // Both should buffer
    try std.testing.expectEqual(@as(usize, 1), console1.message_buffer.size());
    try std.testing.expectEqual(@as(usize, 1), console2.message_buffer.size());

    // But only console2 printed to stderr (we can't test this directly,
    // but the configuration is different)
    try std.testing.expect(console1.print_fn == null);
    try std.testing.expect(console2.print_fn != null);
}
