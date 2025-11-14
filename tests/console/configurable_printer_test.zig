//! Configurable Printer Tests
//!
//! Tests that console.printFn can be configured to control output destination.

const std = @import("std");
const infra = @import("infra");
const console_mod = @import("console");
const webidl = @import("webidl");

test "default printFn uses std.debug.print" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Verify default is std.debug.print
    try std.testing.expect(console_obj.printFn != null);
    try std.testing.expectEqual(std.debug.print, console_obj.printFn.?);
}

test "production mode - null printFn disables immediate output" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Production mode: disable immediate output
    console_obj.printFn = null;

    // Log something
    const args = &[_]webidl.JSValue{
        .{ .string = "This should only buffer, not print" },
    };
    console_obj.call_log(args);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    // Verify it would format correctly if we asked for it
    const msg = console_obj.messageBuffer.get(0).?;
    const formatted = try msg.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "This should only buffer") != null);
}

test "custom printFn - capture output to buffer" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Set up custom printer that captures output
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

    // Log something
    const args = &[_]webidl.JSValue{
        .{ .string = "Test message" },
    };
    console_obj.call_log(args);

    // Verify output was captured
    try std.testing.expect(output.items().len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output.items(), "Test message") != null);
}

test "switch printFn at runtime" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Start in production mode (no output)
    console_obj.printFn = null;

    const args = &[_]webidl.JSValue{
        .{ .string = "Silent message" },
    };
    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.messageBuffer.size());

    // Switch to development mode (with output)
    console_obj.printFn = std.debug.print;

    const args2 = &[_]webidl.JSValue{
        .{ .string = "Loud message" },
    };
    console_obj.call_log(args2);

    try std.testing.expectEqual(@as(usize, 2), console_obj.messageBuffer.size());
}

test "disabled console with null printFn - minimal overhead" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Fully disable console
    console_obj.enabled = false;
    console_obj.printFn = null;

    // These calls should be no-ops
    const args = &[_]webidl.JSValue{
        .{ .string = "This is ignored" },
    };
    console_obj.call_log(args); // Fast disabled path

    // Message buffer should be empty (logger returned early)
    try std.testing.expectEqual(@as(usize, 0), console_obj.messageBuffer.size());
}

test "printFn with format specifiers in messages" {
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

    // Log with format specifiers
    const args = &[_]webidl.JSValue{
        .{ .string = "User %s is %d years old" },
        .{ .string = "Alice" },
        .{ .number = 30.0 },
    };
    console_obj.call_log(args);

    // Verify formatted output was captured
    try std.testing.expect(std.mem.indexOf(u8, output.items(), "Alice") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items(), "30") != null);
}

test "multiple console instances with different printers" {
    const allocator = std.testing.allocator;

    var console1 = try console_mod.console.console.init(allocator);
    defer console1.deinit();

    var console2 = try console_mod.console.console.init(allocator);
    defer console2.deinit();

    // Console 1: production mode (no output)
    console1.printFn = null;

    // Console 2: development mode (has output)
    console2.printFn = std.debug.print;

    const args = &[_]webidl.JSValue{
        .{ .string = "Test" },
    };

    console1.call_log(args);
    console2.call_log(args);

    // Both should buffer
    try std.testing.expectEqual(@as(usize, 1), console1.messageBuffer.size());
    try std.testing.expectEqual(@as(usize, 1), console2.messageBuffer.size());

    // But only console2 printed to stderr (we can't test this directly,
    // but the configuration is different)
    try std.testing.expect(console1.printFn == null);
    try std.testing.expect(console2.printFn != null);
}
