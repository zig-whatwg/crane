//! Runtime Integration Tests
//!
//! Tests console functionality with MockRuntime to verify runtime integration.

const std = @import("std");
const console_mod = @import("console");
const webidl = @import("webidl");
const mock_runtime = @import("mock_runtime.zig");

const Allocator = std.mem.Allocator;

test "Console with runtime - basic initialization" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    try std.testing.expect(console_obj.runtime != null);
}

test "Console with runtime - format specifier %s (string)" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test: "Hello %s" with "World"
    const args = &[_]webidl.JSValue{
        .{ .string = "Hello %s" },
        .{ .string = "World" },
    };

    console_obj.call_log(args);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - format specifier %d (integer)" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test: "Number: %d" with 42
    const args = &[_]webidl.JSValue{
        .{ .string = "Number: %d" },
        .{ .number = 42.7 }, // Should be converted to 42
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - format specifier %f (float)" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test: "Pi: %f" with 3.14159
    const args = &[_]webidl.JSValue{
        .{ .string = "Pi: %f" },
        .{ .number = 3.14159 },
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - multiple format specifiers" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test: "%s: %d items, total: %f" with multiple args
    const args = &[_]webidl.JSValue{
        .{ .string = "%s: %d items, total: %f" },
        .{ .string = "Order" },
        .{ .number = 5.0 },
        .{ .number = 123.45 },
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - format specifier with remaining args" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test: "Name: %s" with extra args that should be printed separately
    const args = &[_]webidl.JSValue{
        .{ .string = "Name: %s" },
        .{ .string = "Alice" },
        .{ .number = 30 }, // Extra arg
        .{ .boolean = true }, // Extra arg
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - type conversion boolean to string" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test boolean conversion
    const args = &[_]webidl.JSValue{
        .{ .string = "Status: %s" },
        .{ .boolean = true },
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - type conversion null to string" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test null conversion
    const args = &[_]webidl.JSValue{
        .{ .string = "Value: %s" },
        .null,
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - no format specifiers" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Test: No format specifiers, should pass through unchanged
    const args = &[_]webidl.JSValue{
        .{ .string = "Hello World" },
        .{ .number = 42 },
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console without runtime - fallback formatting" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // No runtime set - should use fallback conversions
    try std.testing.expect(console_obj.runtime == null);

    const args = &[_]webidl.JSValue{
        .{ .string = "Value: %d" },
        .{ .number = 42 },
    };

    console_obj.call_log(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console with runtime - console.trace() with stack capture" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Call trace (should capture stack)
    const args = &[_]webidl.JSValue{
        .{ .string = "Debug point" },
    };

    console_obj.call_trace(args);

    // Verify trace message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "Console without runtime - console.trace() fallback" {
    const allocator = std.testing.allocator;

    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // No runtime - should fall back to simple trace
    try std.testing.expect(console_obj.runtime == null);

    const args = &[_]webidl.JSValue{
        .{ .string = "Debug point" },
    };

    console_obj.call_trace(args);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}
